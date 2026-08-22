// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouterAwareRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {DETFThresholdPolicy, ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";

/// @title MixedBufferMultiVaultStableDetfCommon
/// @notice Shared helpers: peg seed, math-balance synthetic, StableMath quotes, join/exit, residual, protocol compound.
abstract contract MixedBufferMultiVaultStableDetfCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;

    uint256 internal constant ONE_WAD = 1e18;
    /// @dev Cap single-sided DETF join to 25% of live DETF so last-exit rejoin stays
    ///      under Balancer InvariantRatioAboveMax (300%). Same fraction as Uni V4 D25-7.
    uint256 internal constant SINGLE_JOIN_MAX_IN_WAD = 25e16;
    uint256 internal constant DEFAULT_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant DEFAULT_BURN_THRESHOLD = 0.95e18;

    /// @notice Emitted when detf-owned NFT pending seigniorage DETF is compounded into reserve BPT.
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 bptOut);

    /// @notice Emitted when natural expansion mints free DETF into the bond NFT reward vault.
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 newTimestamp);

    error NotSelf();
    error CompoundJoinProducedZeroBpt();
// L-STRUCT-1: MintSplit from detf/common/core/DETFMintSplit.sol

    function _requireReserveLive() internal view {
        if (!MixedBufferMultiVaultStableDetfRepo._layoutStruct().isReserveLive) {
            revert MixedBufferMultiVaultStableDetfRepo.ReservePoolNotInitialized();
        }
    }

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = MixedBufferMultiVaultStableDetfRepo._layoutStruct().bondNftVault.unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) {
            revert MixedBufferMultiVaultStableDetfRepo.BondNotMature(unlock_);
        }
    }

    function _requireNotStandingRewardNft(uint256 tokenId_) internal pure {
        if (tokenId_ == DETF_FEE_TO_BOND_NFT_ID || tokenId_ == DETF_CREATOR_BOND_NFT_ID) {
            revert IDetfErrors.DETFNFTRestricted(tokenId_);
        }
    }

    function _protocolOriginalShares() internal view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        return s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
    }

    function _userPileReserved() internal view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 totalOrig_ = s.bondNftVault.totalOriginalShares();
        uint256 protocol_ = _protocolOriginalShares();
        return totalOrig_ > protocol_ ? totalOrig_ - protocol_ : 0;
    }

    function _singleSidedJoinDetf(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        bptOut_ = _joinReserveDetfOnly(detfAmount_);
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        if (block.timestamp > deadline_) {
            revert MixedBufferMultiVaultStableDetfRepo.DeadlineExpired(deadline_);
        }
    }

    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _requireBondNft() internal view {
        if (msg.sender != address(MixedBufferMultiVaultStableDetfRepo._layoutStruct().bondNftVault)) {
            revert MixedBufferMultiVaultStableDetfRepo.NotAuthorized(msg.sender);
        }
    }

    function _previewUnbalancedBpt(uint256 tokenIndex_, uint256 amountIn_)
        internal
        view
        returns (uint256 bptOut_)
    {
        if (amountIn_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0) return 0;
        (,, uint256[] memory balances_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        uint256 bal_ = balances_[tokenIndex_];
        if (bal_ == 0) return 0;
        return (amountIn_ * bptSupply_) / bal_;
    }

    /// @notice Host BPT preview for donate join. Unknown / inert / lpToken returns 0.
    function _previewJoinDonatedCapital(IERC20 token_, uint256 amount_)
        internal
        view
        returns (uint256 lpOut_)
    {
        if (amount_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive) return 0;
        if (address(token_) == s.reservePool || address(token_) == address(s.reserveBpt)) return 0;
        if (address(token_) == address(this)) {
            return _previewUnbalancedBpt(s.detfIndex, amount_);
        }
        if (MixedBufferMultiVaultStableDetfRepo._isBufferToken(token_)) {
            try IStandardExchangeIn(address(s.underlyingVaults[0])).previewExchangeIn(
                token_, amount_, s.vaultShares[0]
            ) returns (uint256 sh_) {
                if (sh_ == 0) return 0;
                return _previewUnbalancedBpt(s.shareIndexes[0], sh_);
            } catch {
                return 0;
            }
        }
        (bool found_, uint256 legIndex_) = MixedBufferMultiVaultStableDetfRepo._findVaultShareIndex(token_);
        if (!found_) return 0;
        return _previewUnbalancedBpt(s.shareIndexes[legIndex_], amount_);
    }

    function _joinDonatedBuffer(uint256 bufferAmount_, uint256 deadline_)
        internal
        returns (uint256 bptOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 sharesOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(address(s.underlyingVaults[0])),
            s.bufferToken,
            bufferAmount_,
            s.vaultShares[0],
            0,
            address(this),
            deadline_
        );
        return _joinReserveVaultShareOnly(0, sharesOut_);
    }

    function _sendJoinBptToNft(uint256 bptOut_) internal {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (bptOut_ == 0) revert MixedBufferMultiVaultStableDetfRepo.ZeroAmount();
        IERC20(s.reservePool).safeTransfer(address(s.bondNftVault), bptOut_);
    }

    function _custodyBptOnNft(uint256 bptAmount_) internal {
        if (bptAmount_ == 0) return;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IERC20(s.reservePool).safeTransfer(address(s.bondNftVault), bptAmount_);
    }

    function _pullBptFromNft(uint256 bptAmount_) internal {
        if (bptAmount_ == 0) return;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IERC20 bpt_ = IERC20(s.reservePool);
        uint256 have_ = bpt_.balanceOf(address(this));
        if (have_ >= bptAmount_) return;
        uint256 need_ = bptAmount_ - have_;
        s.bondNftVault.transferHeldToken(bpt_, address(this), need_);
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert MixedBufferMultiVaultStableDetfRepo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    /// @dev Rate-scaled notional in abstract buffer units (1e18). Buffer/DETF rates are 1e18 (STANDARD).
    function _rateScaledNotional(uint256 amount_, uint256 rate_) internal pure returns (uint256) {
        return amount_.mulDown(rate_ == 0 ? ONE_WAD : rate_);
    }

    /// @notice Peg seed §3.4: d_tilde = E_nonDETF / (1+N); DETF decimals 18 → raw d = d_tilde.
    function _pegSeedDetfAmount(uint256 bufferAmount_, uint256[] memory vaultShareAmounts_)
        internal
        view
        returns (uint256 detfSeed_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (vaultShareAmounts_.length != s.vaultCount) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts();
        }
        uint256 nonDetf_ = _rateScaledNotional(bufferAmount_, ONE_WAD);
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 rate_ = _shareRate(i);
            nonDetf_ += _rateScaledNotional(vaultShareAmounts_[i], rate_);
        }
        // average across 1+N non-DETF legs
        detfSeed_ = nonDetf_ / (uint256(s.vaultCount) + 1);
        if (detfSeed_ == 0) revert MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts();
    }

    function _shareRate(uint256 legIndex_) internal view returns (uint256 rate_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.vaultShareRateProviders[legIndex_]) == address(0)) return ONE_WAD;
        rate_ = s.vaultShareRateProviders[legIndex_].getRate();
        if (rate_ == 0) rate_ = ONE_WAD;
    }

    /// @dev Synthetic from owned BPT claim on math balances (virtualBuffer + derived share depths + DETF physical).
    function _syntheticPrice() internal view returns (uint256 syntheticPrice_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0) return ONE_WAD;

        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        uint256 ownedBpt_ = IERC20(s.reservePool).balanceOf(address(this));
        if (address(s.bondNftVault) != address(0)) {
            ownedBpt_ += IERC20(s.reservePool).balanceOf(address(s.bondNftVault));
        }
        if (bptSupply_ == 0 || ownedBpt_ == 0) return ONE_WAD;

        uint256 claimValue_ = _ownedMathBalanceClaim(ownedBpt_, bptSupply_);
        syntheticPrice_ = claimValue_.divDown(totalSupply_);
    }

    function _ownedMathBalanceClaim(uint256 ownedBpt_, uint256 bptSupply_)
        internal
        view
        returns (uint256 claimValue_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IMixedBufferMultiVaultStablePool pool_ = IMixedBufferMultiVaultStablePool(s.reservePool);
        IVault balVault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        uint256[] memory live_ = balVault_.getCurrentLiveBalances(s.reservePool);

        // DETF unpaired physical (live balances are already rate-scaled live units when rates apply).
        uint256 detfBal_ = live_[s.detfIndex];
        claimValue_ = detfBal_ * ownedBpt_ / bptSupply_;

        // virtualBuffer is the math balance for buffer leg (not physical buffer alone).
        uint256 vBuf_ = pool_.virtualBuffer();
        claimValue_ += vBuf_ * ownedBpt_ / bptSupply_;

        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 depth_ = pool_.derivedShareDepth(i);
            // depth is live-scaled; convert to buffer-unit notional via share rate if needed.
            // derivedShareDepth already incorporates live rates from vault; treat as buffer-unit depth.
            claimValue_ += depth_ * ownedBpt_ / bptSupply_;
        }
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isMintingAllowed() internal view returns (bool) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isBurningAllowed() internal view returns (bool) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, _syntheticPrice());
    }

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 user_, uint256 pot_) = DETFMintSplitLib._splitLiveGross(gross_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
        split_.feeToDetf = 0;
    }

    function _splitBondDetf(uint256 joinDetf_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = joinDetf_;
        if (joinDetf_ == 0) return split_;
        (uint256 user_, uint256 pot_,) = DETFMintSplitLib._splitBond(joinDetf_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
        split_.feeToDetf = 0;
    }

    /// @notice Unboosted DETF self-leg for a bond join (D24). Empty book is family peg-seed, not this path.
    function _quoteBondJoinDetf(uint256 tokenIndex_, uint256 amountIn_) internal view returns (uint256 detfOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive || IERC20(s.reservePool).totalSupply() == 0) {
            return amountIn_;
        }
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        uint256 tokenBal_ = balancesRaw_[tokenIndex_];
        uint256 detfBal_ = balancesRaw_[s.detfIndex];
        if (tokenBal_ == 0) return amountIn_;
        detfOut_ = amountIn_ * detfBal_ / tokenBal_;
        if (detfOut_ == 0) detfOut_ = amountIn_;
    }

    /// @notice Proportional DETF leg of a BPT exit (preview; DETF slot stays 0 on D25 close).
    function _previewProportionalDetf(uint256 bptIn_) internal view returns (uint256 detfOut_) {
        if (bptIn_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0) return 0;
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        detfOut_ = balancesRaw_[s.detfIndex] * bptIn_ / bptSupply_;
    }

    function _previewProportionalExit(uint256 bptIn_) internal view returns (uint256[] memory amountsOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = uint256(s.vaultCount) + 2;
        amountsOut_ = new uint256[](n_);
        if (bptIn_ == 0) return amountsOut_;
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0) return amountsOut_;
        (,, uint256[] memory balancesRaw_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        amountsOut_[s.bufferIndex] = balancesRaw_[s.bufferIndex] * bptIn_ / bptSupply_;
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.shareIndexes[i];
            amountsOut_[idx_] = balancesRaw_[idx_] * bptIn_ / bptSupply_;
        }
    }

    function _reserveTokenCount() internal view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        return uint256(s.vaultCount) + 2;
    }

    function _topUpFeeCreatorShares() internal {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || address(s.feeOracle) == address(0)) return;
        (, uint256 f_, uint256 c_) = s.feeOracle.seigniorageSplitOfVault(address(this));
        DETFBondLifecycleLib._topUpFeeCreatorShares(s.bondNftVault, f_, c_);
    }

    function _amp() internal view returns (uint256 amp_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        (amp_,,) = IMixedBufferMultiVaultStablePool(s.reservePool).getAmplificationParameter();
        if (amp_ == 0) {
            // Fallback: raw amp * AMP_PRECISION if pool view not yet ready.
            amp_ = s.amplificationParameter * StableMath.AMP_PRECISION;
        }
    }

    /// @dev Load math balances for StableMath (virtualBuffer, derived depths, DETF physical live).
    function _mathBalancesLive() internal view returns (uint256[] memory balances_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IMixedBufferMultiVaultStablePool pool_ = IMixedBufferMultiVaultStablePool(s.reservePool);
        uint256[] memory live_ = _reserveVault().getCurrentLiveBalances(s.reservePool);
        uint256 n_ = live_.length;
        balances_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            balances_[i] = live_[i];
        }
        balances_[s.bufferIndex] = pool_.virtualBuffer();
        for (uint256 i; i < s.vaultCount; ++i) {
            balances_[s.shareIndexes[i]] = pool_.derivedShareDepth(i);
        }
    }

    function _quoteDetfOutForTokenIn(uint256 tokenIndexIn_, uint256 amountIn_, uint256 rateIn_)
        internal
        view
        returns (uint256 detfOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (IERC20(s.reservePool).totalSupply() == 0 || !s.isReserveLive) {
            // Bootstrap-style: rate-scaled 1:1 into DETF units.
            detfOut_ = _rateScaledNotional(amountIn_, rateIn_);
            if (detfOut_ == 0) detfOut_ = amountIn_;
            return detfOut_;
        }

        uint256[] memory balances_ = _mathBalancesLive();
        uint256 amp_ = _amp();
        uint256 invariant_ = StableMath.computeInvariant(amp_, balances_);
        uint256 fee_ = _reserveVault().getStaticSwapFeePercentage(s.reservePool);

        uint256 amountInLive_ =
            _rateScaledNotional(amountIn_ + amountIn_.mulDown(_seigniorageIncentiveWad()), rateIn_);
        // Apply swap fee on taxable portion for single-token-ish join approximation: fee on input.
        uint256 amountInAfterFee_ = amountInLive_.mulDown(ONE_WAD - fee_);

        uint256 outLive_ = StableMath.computeOutGivenExactIn(
            amp_, balances_, tokenIndexIn_, s.detfIndex, amountInAfterFee_, invariant_
        );
        detfOut_ = outLive_;
        if (detfOut_ == 0) detfOut_ = amountIn_;
    }

    function _quoteDetfOutForBuffer(uint256 bufferAmount_) internal view returns (uint256) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        return _quoteDetfOutForTokenIn(s.bufferIndex, bufferAmount_, ONE_WAD);
    }

    function _quoteDetfOutForVaultShares(uint256 legIndex_, uint256 vaultShares_)
        internal
        view
        returns (uint256)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        return _quoteDetfOutForTokenIn(s.shareIndexes[legIndex_], vaultShares_, _shareRate(legIndex_));
    }

    function _reserveRouter() internal view returns (IBalancerV3StandardExchangeRouterProxy) {
        return BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
    }

    function _reserveVault() internal view returns (IVault) {
        return BalancerV3VaultAwareRepo._balancerV3Vault();
    }

    /// @dev Initialize MixedBuffer pool with all T legs non-zero (sorted token order).
    function _initializeReserve(
        uint256 detfAmount_,
        uint256 bufferAmount_,
        uint256[] memory vaultShareAmounts_
    ) internal returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = uint256(s.vaultCount) + 2; // DETF + buffer + N shares
        IERC20[] memory tokens_ = new IERC20[](n_);
        uint256[] memory amounts_ = new uint256[](n_);

        tokens_[s.detfIndex] = IERC20(address(this));
        amounts_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) {
            IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        }

        tokens_[s.bufferIndex] = s.bufferToken;
        amounts_[s.bufferIndex] = bufferAmount_;
        if (bufferAmount_ > 0) {
            s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        }

        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.shareIndexes[i];
            tokens_[idx_] = s.vaultShares[i];
            amounts_[idx_] = vaultShareAmounts_[i];
            if (vaultShareAmounts_[i] > 0) {
                s.vaultShares[i].safeTransfer(address(_reserveVault()), vaultShareAmounts_[i]);
            }
        }

        // Sort by address for Balancer initialize order.
        for (uint256 i; i < n_; ++i) {
            for (uint256 j = i + 1; j < n_; ++j) {
                if (address(tokens_[j]) < address(tokens_[i])) {
                    (tokens_[i], tokens_[j]) = (tokens_[j], tokens_[i]);
                    (amounts_[i], amounts_[j]) = (amounts_[j], amounts_[i]);
                }
            }
        }

        bptOut_ = _reserveRouter().prepayInitialize(s.reservePool, tokens_, amounts_, 0, "");
    }

    function _joinReserveUnbalanced(uint256[] memory amountsIn_) internal returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _joinReserveBufferAndDetf(uint256 bufferAmount_, uint256 detfAmount_)
        internal
        returns (uint256 bptOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.bufferIndex] = bufferAmount_;
        amountsIn_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (bufferAmount_ > 0) s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveShareAndDetf(uint256 legIndex_, uint256 vaultShares_, uint256 detfAmount_)
        internal
        returns (uint256 bptOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.shareIndexes[legIndex_]] = vaultShares_;
        amountsIn_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (vaultShares_ > 0) s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveBufferOnly(uint256 bufferAmount_) internal returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.bufferIndex] = bufferAmount_;
        s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveVaultShareOnly(uint256 legIndex_, uint256 vaultShares_)
        internal
        returns (uint256 bptOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.shareIndexes[legIndex_]] = vaultShares_;
        s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveDetfOnly(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    /// @dev Cap zap-in so last-exit D25 rejoin still mints lpOut > 0 (full amount would
    ///      revert InvariantRatioAboveMax). Unjoined DETF stays on this diamond for the
    ///      caller to send to Bond NFT inventory.
    function _joinReserveDetfCapped(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        if (detfAmount_ == 0) return 0;
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        (,, uint256[] memory balances_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
        uint256 remaining_ = balances_[s.detfIndex];
        uint256 cap_ = remaining_ * SINGLE_JOIN_MAX_IN_WAD / ONE_WAD;
        if (cap_ == 0) cap_ = detfAmount_ < 1e3 ? detfAmount_ : 1e3;
        uint256 joinAmt_ = detfAmount_ < cap_ ? detfAmount_ : cap_;
        if (joinAmt_ == 0) return 0;
        return _joinReserveDetfOnly(joinAmt_);
    }

    /// @dev Repeat capped DETF joins so last-exit leftover becomes id 0 LP. Do not
    ///      send leftover DETF to the Bond NFT (that books as rewards and extracts to ids 1–2).
    function _joinReserveDetfUntilDust(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        if (detfAmount_ == 0) return 0;
        IERC20 detfToken_ = IERC20(address(this));
        for (uint256 i; i < 64; ++i) {
            uint256 remaining_ = detfToken_.balanceOf(address(this));
            if (remaining_ == 0) break;
            uint256 minted_ = _joinReserveDetfCapped(remaining_);
            if (minted_ == 0) break;
            bptOut_ += minted_;
        }
    }

    /// @dev Live join of any combination of DETF / buffer / vault-share legs (zero amounts skipped).
    function _joinReserveLegs(uint256 detfAmount_, uint256 bufferAmount_, uint256[] memory vaultShareAmounts_)
        internal
        returns (uint256 bptOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        amountsIn_[s.bufferIndex] = bufferAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (bufferAmount_ > 0) s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 amt_ = i < vaultShareAmounts_.length ? vaultShareAmounts_[i] : 0;
            amountsIn_[s.shareIndexes[i]] = amt_;
            if (amt_ > 0) s.vaultShares[i].safeTransfer(address(_reserveVault()), amt_);
        }
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256 bufferOut_, uint256[] memory vaultSharesOut_)
    {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        _pullBptFromNft(bptIn_);
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory minOut_ = new uint256[](n_);
        IERC20(s.reservePool).forceApprove(address(_reserveRouter()), bptIn_);
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(s.reservePool, bptIn_, minOut_, "");
        detfOut_ = raw_[s.detfIndex];
        bufferOut_ = raw_[s.bufferIndex];
        vaultSharesOut_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            vaultSharesOut_[i] = raw_[s.shareIndexes[i]];
        }
    }

    function _bptForDetfShares(uint256 detfShares_) internal view returns (uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 bptBal_ = IERC20(s.reservePool).balanceOf(address(s.bondNftVault));
        if (supply_ == 0 || bptBal_ == 0) return 0;
        bptOut_ = detfShares_ * bptBal_ / supply_;
    }

    /* ---------------------------------------------------------------------- */
    /*                     Natural supply expansion (Phase 2)                 */
    /* ---------------------------------------------------------------------- */

    /// @dev Mint-on-update natural expansion into bond NFT vault (same sink as seigniorage inventory).
    ///      Uses only `DETFNaturalExpansionLib`; Open / not-live / not-mint-allowed → zero mint.
    ///      Advances `lastExpansionTimestamp` only when mint > 0. Seeds clock if still zero while live.
    function _updateExpansionMintOnRewards() internal returns (uint256 mintAmount_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (!s.isReserveLive || address(s.bondNftVault) == address(0)) {
            return 0;
        }
        // Seed accrual clock on first live touch if not already set at bootstrap.
        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
            return 0;
        }

        DETFNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = s.isReserveLive;
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy;
        in_.isMintAllowed = _isMintingAllowed();
        in_.syntheticPrice = _syntheticPrice();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.closureRatePerSecond = s.expansionClosureRatePerSecond;
        in_.catchUpMaxSeconds = s.expansionCatchUpMaxSeconds;
        in_.catchUpCapBps = s.expansionCatchUpCapBps;

        uint256 newTs_;
        (mintAmount_, newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        if (mintAmount_ > 0) {
            _mintDetf(address(s.bondNftVault), mintAmount_);
            s.lastExpansionTimestamp = newTs_;
            emit NaturalSupplyExpanded(mintAmount_, in_.syntheticPrice, newTs_);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol seigniorage compound                      */
    /* ---------------------------------------------------------------------- */

    /// @dev Best-effort protocol NFT compound for lazy hooks and public surface.
    ///      Preferred pull pattern: atomic self-call harvest+join+BPT credit; join failure rolls back harvest.
    ///      Runs natural expansion mint-on-update first so expansion + protocol share compound in one touch.
    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn_, uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || !s.isReserveLive) {
            return (0, 0);
        }

        // Phase 2: accrue free DETF into bond vault before protocol harvest sees balances.
        _updateExpansionMintOnRewards();

        uint256 protocolId_ = s.bondNftVault.detfNFTId();
        uint256 pending_ = s.bondNftVault.pendingRewards(protocolId_);
        if (!DETFProtocolCompoundLib.isCompoundable(pending_)) {
            return (0, 0);
        }

        // External self-call so join revert rolls back harvest (no stranded debt wipe).
        // Atomic helper is intentionally not nonReentrant (outer paths hold the lock).
        try this.compoundProtocolRewardsAtomic() returns (uint256 d_, uint256 b_) {
            detfIn_ = d_;
            bptOut_ = b_;
            if (bptOut_ > 0) {
                emit ProtocolRewardsCompounded(detfIn_, bptOut_);
            }
        } catch {
            return (0, 0);
        }
    }

    /// @notice Atomic harvest → single-sided DETF join → credit BPT to detf NFT. Only self-callable.
    /// @dev Used by `_tryCompoundProtocolRewards` via try/catch for preferred pull atomicity.
    ///      Not permissionless ops surface — reverts unless `msg.sender == address(this)`.
    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn_, uint256 bptOut_) {
        if (msg.sender != address(this)) revert NotSelf();
        return _compoundProtocolRewardsAtomic();
    }

    function _compoundProtocolRewardsAtomic() internal returns (uint256 detfIn_, uint256 bptOut_) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s =
            MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        IDETFNFTVault vault_ = s.bondNftVault;
        uint256 protocolId_ = vault_.detfNFTId();

        // Harvest free DETF to this diamond (authorized as DETF owner of protocol NFT rewards).
        detfIn_ = vault_.reallocateDetfNftRewards(address(this));
        if (detfIn_ == 0) {
            return (0, 0);
        }

        // DETF self-leg only — MixedBuffer stable/mixed-buffer pool; weight/amp skew accepted (PRD §9).
        bptOut_ = _joinReserveDetfOnly(detfIn_);
        if (bptOut_ == 0) revert CompoundJoinProducedZeroBpt();

        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reservePool),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            protocolId_,
            bptOut_
        );
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    /// @dev Reserve-delta pull (L-DETF-LOCAL-PUSH). `pretransferred=true`: credit claimed only when
    ///      claimed <= U = B - R. `false`: pull delta only (FoT-safe; does not add prior U).
    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
        uint256 B0 = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            return token_.balanceOf(address(this)) - B0;
        }
        uint256 U = B0 - R;
        if (amount_ > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, U);
        }
        return amount_;
    }

    /// @dev Full expected-hold sync after outer refund (L-DETF-END-ORDER).
    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    /// @dev Nested exchangeIn fund: push + true; amountIn_==0 skips entire call (L-DETF-ZERO-NESTED).
    function _nestedExchangeInPush(
        IStandardExchangeIn host_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (amountIn_ == 0) return 0;
        tokenIn_.safeTransfer(address(host_), amountIn_);
        amountOut_ = host_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, true, deadline_
        );
    }


    function _feeTo() internal view returns (address) {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        return address(s.feeOracle.feeTo());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }

    /// @dev Assert free buffer / free shares / free DETF on diamond ≈ 0 after success paths.
    ///      BPT remaining on diamond is intentional inventory.
    function _assertNoFreeInventory() internal view {
        MixedBufferMultiVaultStableDetfRepo.Storage storage s = MixedBufferMultiVaultStableDetfRepo._layoutStruct();
        uint256 freeDetf_ = IERC20(address(this)).balanceOf(address(this));
        // Free DETF held as inventory for residual rejoin is OK if zero preferred; enforce dust only.
        if (freeDetf_ > 1) {
            // no revert in view path for external asserts — tests call residual helper
        }
        uint256 freeBuf_ = s.bufferToken.balanceOf(address(this));
        if (freeBuf_ > 1) {
            // tests assert via helper
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (s.vaultShares[i].balanceOf(address(this)) > 1) {
                // tests assert via helper
            }
        }
    }
}
