// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {
    ScalingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
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
    BalancerV3WeightedPoolQuote
} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/// @title SingleStandardExchangeDETFCommon
/// @notice Shared helpers: pricing, thresholds, reserve join/exit, allowlist, bond lock clamp, protocol compound.
abstract contract SingleStandardExchangeDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    using ScalingHelpers for uint256;

    uint256 internal constant ONE_WAD = 1e18;

    /// @notice Emitted when detf-owned NFT pending seigniorage DETF is compounded into reserve BPT.
    event ProtocolRewardsCompounded(uint256 detfIn, uint256 bptOut);

    /// @notice Emitted when free DETF is minted into the bond NFT vault via natural expansion.
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);

    error NotSelf();
    error CompoundJoinProducedZeroBpt();
// L-STRUCT-1: MintSplit from detf/common/core/DETFMintSplit.sol

    /* ---------------------------------------------------------------------- */
    /*                              Liveness                                  */
    /* ---------------------------------------------------------------------- */

    function _requireReserveLive() internal view {
        if (!SingleStandardExchangeDETFRepo._layoutStruct().isReserveLive) {
            revert SingleStandardExchangeDETFRepo.ReservePoolNotInitialized();
        }
    }

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = SingleStandardExchangeDETFRepo._layoutStruct().bondNftVault.unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) {
            revert SingleStandardExchangeDETFRepo.BondNotMature(unlock_);
        }
    }

    function _protocolOriginalShares() internal view returns (uint256) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        return s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
    }

    function _userPileReserved() internal view returns (uint256) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 totalOrig_ = s.bondNftVault.totalOriginalShares();
        uint256 protocol_ = _protocolOriginalShares();
        return totalOrig_ > protocol_ ? totalOrig_ - protocol_ : 0;
    }

    function _singleSidedJoinDetf(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        bptOut_ = _joinReserveDetfOnly(detfAmount_);
    }

    /// @dev Closed-form quote of proportional BPT exit → vaultShare (or SE token via nested preview).
    ///      Used by claim redemption-rate and close/redeem previews.
    function _previewBptUnwind(uint256 bptIn_, IERC20 tokenOut_) internal view returns (uint256) {
        if (bptIn_ == 0) return 0;
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0) return 0;
        IVault bal_ = _reserveVault();
        (,, uint256[] memory balancesRaw_,) = bal_.getPoolTokenInfo(s.reservePool);
        uint256 vaultSharesOut_ = balancesRaw_[s.vaultShareIndex] * bptIn_ / bptSupply_;
        if (address(tokenOut_) == address(s.standardExchangeVaultShare)) {
            return vaultSharesOut_;
        }
        if (!_isPrimaryBurnTokenOut(tokenOut_)) return 0;
        return s.standardExchangeVault.previewExchangeIn(
            s.standardExchangeVaultShare, vaultSharesOut_, tokenOut_
        );
    }

    /// @dev Primary-burn / close / redeemClaim allowlist: vaultShare + SE `vaultTokens()`.
    function _isPrimaryBurnTokenOut(IERC20 tokenOut_) internal view returns (bool) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(tokenOut_) == address(this)) return false;
        if (address(tokenOut_) == address(s.rebasingClaimToken)) return false;
        return _isAllowlistedTokenIn(tokenOut_);
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        _requireNotDisabled();
        if (amount_ == 0) revert SingleStandardExchangeDETFRepo.ZeroAmount();
        if (block.timestamp > deadline_) {
            revert SingleStandardExchangeDETFRepo.DeadlineExpired(deadline_);
        }
    }

    /// @notice Reverts if this DETF is disabled by address or package on the Vault Registry.
    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                            Allowlist                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev True if `token_` is the vault share or listed on the SE vault's basic vault surface.
    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(token_) == address(s.standardExchangeVaultShare)) return true;
        if (address(token_) == address(this)) return false;

        address[] memory tokens_ = IBasicVault(address(s.standardExchangeVault)).vaultTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(token_)) return true;
        }
        return false;
    }

    /* ---------------------------------------------------------------------- */
    /*                         Bond lock clamp                                */
    /* ---------------------------------------------------------------------- */

    /// @dev Revert if shorter than oracle min; clamp to max for bonus/unlock if longer.
    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert SingleStandardExchangeDETFRepo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _bonusMultiplier(uint256 effectiveLockDuration_) internal view returns (uint256) {
        return DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), effectiveLockDuration_);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Pricing                                   */
    /* ---------------------------------------------------------------------- */

    function _syntheticPrice() internal view returns (uint256 syntheticPrice_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0) return ONE_WAD;

        IVault balVault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        uint256 ownedBpt_ = IERC20(s.reservePool).balanceOf(address(this));
        // Include BPT held by bond NFT vault (bonded liquidity still backs the DETF economically).
        if (address(s.bondNftVault) != address(0)) {
            ownedBpt_ += IERC20(s.reservePool).balanceOf(address(s.bondNftVault));
        }
        if (bptSupply_ == 0 || ownedBpt_ == 0) return ONE_WAD;

        TokenInfo[] memory info_;
        uint256[] memory balancesRaw_;
        (, info_, balancesRaw_,) = balVault_.getPoolTokenInfo(s.reservePool);

        uint256 ownedDetf_ = balancesRaw_[s.detfIndex] * ownedBpt_ / bptSupply_;
        uint256 ownedShares_ = balancesRaw_[s.vaultShareIndex] * ownedBpt_ / bptSupply_;
        uint256 vaultRate_ = ONE_WAD;
        if (address(info_[s.vaultShareIndex].rateProvider) != address(0)) {
            vaultRate_ = info_[s.vaultShareIndex].rateProvider.getRate();
        }
        uint256 totalValue_ = ownedDetf_ + ownedShares_.mulDown(vaultRate_);
        syntheticPrice_ = totalValue_.divDown(totalSupply_);
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isMintingAllowed() internal view returns (bool) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isBurningAllowed() internal view returns (bool) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, _syntheticPrice());
    }

    /* ---------------------------------------------------------------------- */
    /*                           Mint quote                                   */
    /* ---------------------------------------------------------------------- */

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeeWad() internal view returns (uint256) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.usageFeeOfVault(address(this));
    }

    /// @dev Gross DETF from vault-share input (bootstrap-pegged when pool empty; curve when live).
    function _quoteDetfOutForVaultShares(uint256 vaultShares_) internal view returns (uint256 detfOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (IERC20(s.reservePool).totalSupply() == 0 || !s.isReserveLive) {
            return _quoteDetfBootstrap(s, vaultShares_);
        }
        return _quoteDetfLive(s, vaultShares_);
    }

    function _quoteDetfBootstrap(SingleStandardExchangeDETFRepo.Storage storage s, uint256 vaultShares_)
        private
        view
        returns (uint256 detfOut_)
    {
        uint256 rate_ = address(s.vaultRateProvider) != address(0) ? s.vaultRateProvider.getRate() : ONE_WAD;
        detfOut_ = vaultShares_.mulDown(rate_).mulDivUp(s.detfWeight, s.vaultShareWeight);
        if (detfOut_ == 0) detfOut_ = vaultShares_;
    }

    function _quoteDetfLive(SingleStandardExchangeDETFRepo.Storage storage s, uint256 vaultShares_)
        private
        view
        returns (uint256 detfOut_)
    {
        // Stack-split: load pool state then compute separately.
        (uint256 balIn_, uint256 balOut_, uint256 rateOut_, uint256 fee_) = _loadCurveInputs(s);
        uint256 amountInLive_ = (vaultShares_ + vaultShares_.mulDown(_seigniorageIncentiveWad())).mulDown(
            address(s.vaultRateProvider) != address(0) ? s.vaultRateProvider.getRate() : ONE_WAD
        );
        uint256 outLive_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            balIn_, s.vaultShareWeight, balOut_, s.detfWeight, amountInLive_, fee_
        );
        detfOut_ = outLive_.divDown(rateOut_);
        if (detfOut_ == 0) detfOut_ = vaultShares_;
    }

    function _loadCurveInputs(SingleStandardExchangeDETFRepo.Storage storage s)
        private
        view
        returns (uint256 balInLive_, uint256 balOutLive_, uint256 rateOut_, uint256 fee_)
    {
        IVault bal_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        fee_ = bal_.getStaticSwapFeePercentage(s.reservePool);
        TokenInfo[] memory tokenInfo_;
        uint256[] memory balancesRaw_;
        (, tokenInfo_, balancesRaw_,) = bal_.getPoolTokenInfo(s.reservePool);
        balInLive_ = _toLiveScaled18(balancesRaw_[s.vaultShareIndex], tokenInfo_[s.vaultShareIndex]);
        balOutLive_ = _toLiveScaled18(balancesRaw_[s.detfIndex], tokenInfo_[s.detfIndex]);
        rateOut_ = _tokenRate(tokenInfo_[s.detfIndex]);
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 afterFee_, uint256 feeTo_) = DETFUsageFeeLib._splitUsageFee(gross_, _usageFeeWad());
        split_.feeToDetf = feeTo_;
        // Half of seigniorage incentive of remaining → protocol NFT accrual path
        uint256 halfInc_ = _seigniorageIncentiveWad() / 2;
        split_.inventoryDetf = afterFee_.mulDown(halfInc_);
        split_.userDetf = afterFee_ - split_.inventoryDetf;
    }

    function _toLiveScaled18(uint256 raw_, TokenInfo memory info_) internal view returns (uint256) {
        uint256 rate_ = _tokenRate(info_);
        // Decimal scaling: assume 18-decimal tokens in this family (SE shares + DETF).
        return raw_.mulDown(rate_);
    }

    function _tokenRate(TokenInfo memory info_) internal view returns (uint256) {
        if (address(info_.rateProvider) == address(0)) return ONE_WAD;
        return info_.rateProvider.getRate();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Reserve join / exit                            */
    /* ---------------------------------------------------------------------- */

    function _reserveRouter() internal view returns (IBalancerV3StandardExchangeRouterProxy) {
        return BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
    }

    function _reserveVault() internal view returns (IVault) {
        return BalancerV3VaultAwareRepo._balancerV3Vault();
    }

    /// @dev Initialize or add liquidity with DETF + vault shares. Returns BPT minted to this.
    function _joinReserveBothLegs(uint256 detfAmount_, uint256 vaultShares_) internal returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        IVault bal_ = _reserveVault();
        address pool_ = s.reservePool;

        if (detfAmount_ > 0) {
            IERC20(address(this)).safeTransfer(address(bal_), detfAmount_);
        }
        if (vaultShares_ > 0) {
            s.standardExchangeVaultShare.safeTransfer(address(bal_), vaultShares_);
        }

        if (IERC20(pool_).totalSupply() == 0) {
            IERC20[] memory tokens_ = new IERC20[](2);
            uint256[] memory exactAmountsIn_ = new uint256[](2);
            if (address(this) < address(s.standardExchangeVaultShare)) {
                tokens_[0] = IERC20(address(this));
                tokens_[1] = s.standardExchangeVaultShare;
                exactAmountsIn_[0] = detfAmount_;
                exactAmountsIn_[1] = vaultShares_;
            } else {
                tokens_[0] = s.standardExchangeVaultShare;
                tokens_[1] = IERC20(address(this));
                exactAmountsIn_[0] = vaultShares_;
                exactAmountsIn_[1] = detfAmount_;
            }
            bptOut_ = _reserveRouter().prepayInitialize(pool_, tokens_, exactAmountsIn_, 0, "");
        } else {
            uint256 n_ = bal_.getCurrentLiveBalances(pool_).length;
            uint256[] memory amountsIn_ = new uint256[](n_);
            amountsIn_[s.detfIndex] = detfAmount_;
            amountsIn_[s.vaultShareIndex] = vaultShares_;
            bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(pool_, amountsIn_, 0, "");
        }
    }

    function _joinReserveVaultSharesOnly(uint256 vaultShares_) internal returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        IVault bal_ = _reserveVault();
        uint256 n_ = bal_.getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.vaultShareIndex] = vaultShares_;
        s.standardExchangeVaultShare.safeTransfer(address(bal_), vaultShares_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    /// @dev Single-sided DETF join into the reserve pool. Returns BPT minted to this diamond.
    function _joinReserveDetfOnly(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    /// @dev Proportional exit of `bptIn_`; returns DETF order amounts [detf, vaultShare] after reorder.
    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256 vaultSharesOut_)
    {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory minOut_ = new uint256[](n_);
        IERC20(s.reservePool).forceApprove(address(_reserveRouter()), bptIn_); // BetterSafeERC20
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(s.reservePool, bptIn_, minOut_, "");
        detfOut_ = raw_[s.detfIndex];
        vaultSharesOut_ = raw_[s.vaultShareIndex];
    }

    function _bptForDetfShares(uint256 detfShares_) internal view returns (uint256 bptOut_) {
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 bptBal_ = IERC20(s.reservePool).balanceOf(address(this));
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
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        if (!s.isReserveLive || address(s.bondNftVault) == address(0)) {
            return 0;
        }
        // Seed accrual clock on first live touch if not already set at first-bond.
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
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
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
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        IDETFNFTVault vault_ = s.bondNftVault;
        uint256 protocolId_ = vault_.detfNFTId();

        // Harvest free DETF to this diamond (authorized as DETF owner of protocol NFT rewards).
        detfIn_ = vault_.reallocateDetfNftRewards(address(this));
        if (detfIn_ == 0) {
            return (0, 0);
        }

        bptOut_ = _joinReserveDetfOnly(detfIn_);
        if (bptOut_ == 0) revert CompoundJoinProducedZeroBpt();

        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reservePool),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            protocolId_,
            bptOut_
        );
        _syncAllExpectedHoldReserves();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Transfers                                 */
    /* ---------------------------------------------------------------------- */

    /// @dev Reserve-delta pull (L-DETF-LOCAL-PUSH / L-GAPS-9/10/12).
    ///      `pretransferred=true`: credit `claimed` only when `claimed <= U = B − R`
    ///      (durable unbooked surplus via MultiAssetBasicVaultRepo). I1 when `R == B`.
    ///      `pretransferred=false`: pull delta only (FoT-safe; does not add prior `U`).
    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
        uint256 B0 = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            // FoT-safe: return pull delta only — do NOT add prior unbooked U.
            return token_.balanceOf(address(this)) - B0;
        }
        uint256 U = B0 - R;
        if (amount_ > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, U);
        }
        return amount_;
    }

    /// @dev Full expected-hold sync: for each MultiAsset vault token, `R := balanceOf`.
    ///      Call at end of every successful money route after outer refund re-forward (L-DETF-END-ORDER).
    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    /// @dev Nested SE fund: push + pretransferred=true. `amountIn_ == 0` skips the entire call.
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
        SingleStandardExchangeDETFRepo.Storage storage s = SingleStandardExchangeDETFRepo._layoutStruct();
        return address(s.feeOracle.feeTo());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }
}
