// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/// @title UniswapV4SingleStandardExchangeDETFCommon
/// @notice Shared pricing, gates, mint split, hook LP helpers, epoch expansion, compound.
abstract contract UniswapV4SingleStandardExchangeDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant ONE_WAD = 1e18;

    error NotSelf();
    error CompoundJoinProducedZeroLp();
// L-STRUCT-1: MintSplit from detf/common/core/DETFMintSplit.sol

    /* ---------------------------------------------------------------------- */
    /*                              Liveness                                  */
    /* ---------------------------------------------------------------------- */

    function _requireReserveLive() internal view {
        if (!Repo._layoutStruct().isReserveLive) revert Repo.ReserveNotLive();
    }

    function _requireReserveWired() internal view {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || address(s.rebasingClaimToken) == address(0)) {
            revert Repo.ReserveNotWired();
        }
    }

    /// @dev Deadline + amount only. Disable is inbound-only (`_requireNotDisabled`).
    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert Repo.ZeroAmount();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
    }

    /// @dev First bond cannot credit pre-live unbooked residual (A0).
    function _rejectPretransferredFirstBond(bool pretransferred_, uint256 claimed_) internal pure {
        if (pretransferred_) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed_, 0);
        }
    }

    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = Repo._layoutStruct().bondNftVault.unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) {
            revert Repo.BondNotMature(unlock_);
        }
    }

    function _requireNotStandingRewardNft(uint256 tokenId_) internal pure {
        if (tokenId_ == DETF_FEE_TO_BOND_NFT_ID || tokenId_ == DETF_CREATOR_BOND_NFT_ID) {
            revert IDetfErrors.DETFNFTRestricted(tokenId_);
        }
    }

    function _protocolOriginalShares() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        return s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
    }

    /* ---------------------------------------------------------------------- */
    /*                            Allowlist                                   */
    /* ---------------------------------------------------------------------- */

    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(token_) == address(s.standardExchangeVaultShare)) return true;
        if (address(token_) == address(s.pairToken)) return true;
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

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert Repo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _bonusMultiplier(uint256 effectiveLockDuration_) internal view returns (uint256) {
        return DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), effectiveLockDuration_);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Decimal helpers                                */
    /* ---------------------------------------------------------------------- */

    function _toWad(uint256 amount_, uint8 decimals_) internal pure returns (uint256) {
        if (decimals_ == 18) return amount_;
        if (decimals_ < 18) return amount_ * (10 ** (18 - decimals_));
        return amount_ / (10 ** (decimals_ - 18));
    }

    function _fromWadFloor(uint256 amountWad_, uint8 decimals_) internal pure returns (uint256) {
        if (decimals_ == 18) return amountWad_;
        if (decimals_ < 18) return amountWad_ / (10 ** (18 - decimals_));
        return amountWad_ * (10 ** (decimals_ - 18));
    }

    function _pairDecimals() internal view returns (uint8) {
        return IERC20Metadata(address(Repo._layoutStruct().pairToken)).decimals();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Protocol / bonded LP accounting                     */
    /* ---------------------------------------------------------------------- */

    /// @notice D13: reserve LP is held by the bond NFT vault.
    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    /// @notice Physical hook LP on the NFT vault (D13).
    function _nftLp() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        address holder_ = _bondLpHolder();
        return IERC20(s.reserveHook).balanceOf(holder_);
    }

    /// @notice LP on the NFT that is not tracked as user-bonded principal.
    function _protocolLp() internal view returns (uint256) {
        uint256 nftLp_ = _nftLp();
        uint256 user_ = Repo._layoutStruct().userBondedLp;
        return nftLp_ > user_ ? nftLp_ - user_ : 0;
    }

    /// @notice Pull NFT-custodied hook LP onto this diamond before hook withdraw (D13).
    function _pullNftLp(uint256 lpAmount_) internal {
        if (lpAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        uint256 have_ = lp_.balanceOf(address(this));
        if (have_ >= lpAmount_) return;
        uint256 need_ = lpAmount_ - have_;
        address holder_ = _bondLpHolder();
        if (holder_ == address(this)) {
            if (have_ < lpAmount_) revert Repo.EmptyProtocolLp();
            return;
        }
        if (need_ > lp_.balanceOf(holder_)) revert Repo.EmptyProtocolLp();
        IDETFNFTVault(holder_).transferHeldToken(lp_, address(this), need_);
    }

    /// @dev Back-compat name used by burn / claim unwind.
    function _pullProtocolLp(uint256 lpAmount_) internal {
        _pullNftLp(lpAmount_);
    }

    /// @notice Pull LP from bond NFT (maturity close via claimLiquidity).
    function _pullBondLp(uint256 lpAmount_) internal {
        _pullNftLp(lpAmount_);
    }

    function _ensureProtocolLpAvailable(uint256 lpAmount_) internal view {
        if (lpAmount_ > _nftLp()) revert Repo.EmptyProtocolLp();
    }

    /// @dev Pull NFT LP onto the diamond for hook withdraw.
    function _ensureProtocolLpOnDiamond(uint256 lpAmount_) internal {
        _ensureProtocolLpAvailable(lpAmount_);
        _pullNftLp(lpAmount_);
    }

    /// @notice Fully diluted pair value of owned LP (protocol claim + bond NFT + residual diamond).
    function _fdPairWad() internal view returns (uint256 fdPairWad_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        uint256 totalOwnedLp_ = lp_.balanceOf(address(this));
        address bond_ = address(s.bondNftVault);
        if (bond_ != address(0)) totalOwnedLp_ += lp_.balanceOf(bond_);
        address claim_ = address(s.rebasingClaimToken);
        if (claim_ != address(0)) totalOwnedLp_ += lp_.balanceOf(claim_);
        if (totalOwnedLp_ == 0) return 0;
        uint256 pairOut_ = IHook(s.reserveHook).previewWithdrawSingle(totalOwnedLp_, address(s.pairToken));
        fdPairWad_ = _toWad(pairOut_, _pairDecimals());
    }

    /* ---------------------------------------------------------------------- */
    /*                              Pricing                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Spot synthetic (excludes pending expansion debt).
    function _syntheticPriceSpot() internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 fd_ = _fdPairWad();
        if (fd_ == 0) return ONE_WAD;
        // S = (fdPair / supply) / creationRate * 1e18
        // = fdPair * 1e18 / supply * 1e18 / creationPairPerDetfWad
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, supply_);
        return Math.mulDiv(mid_, ONE_WAD, s.creationPairPerDetfWad);
    }

    /// @notice Debt-inclusive synthetic (gates use this).
    function _syntheticPrice() internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 effectiveSupply_ = supply_ + pending_;
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 fd_ = _fdPairWad();
        if (fd_ == 0) return ONE_WAD;
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, effectiveSupply_);
        return Math.mulDiv(mid_, ONE_WAD, s.creationPairPerDetfWad);
    }

    function _isMintingAllowed() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
    }

    function _isBurningAllowed() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, _syntheticPrice());
    }

    /* ---------------------------------------------------------------------- */
    /*                         Expansion (epoch)                              */
    /* ---------------------------------------------------------------------- */

    function _expansionInput() internal view returns (DETFEpochNaturalExpansionLib.AccrualInput memory in_) {
        Repo.Storage storage s = Repo._layoutStruct();
        in_.isLive = s.isReserveLive;
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy;
        in_.spotSyntheticPrice = _syntheticPriceSpot();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.expansionEpochLength = s.expansionEpochLength;
        in_.expansionClosureRatePerYearWad = s.expansionClosureRatePerYearWad;
        in_.expansionMaxCatchUpEpochs = s.expansionMaxCatchUpEpochs;
    }

    function _previewPendingExpansionMint() internal view returns (uint256) {
        return DETFEpochNaturalExpansionLib.previewPendingExpansionMint(_expansionInput());
    }

    /// @dev Realize expansion only on bond / claimRewards / compound. Never on primary mint/burn.
    function _realizeExpansionIfNeeded() internal returns (uint256 mintAmount_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || s.thresholdMode != ThresholdMode.Policy) return 0;
        if (address(s.bondNftVault) == address(0)) return 0;

        if (s.lastExpansionTimestamp == 0) {
            s.lastExpansionTimestamp = block.timestamp;
            return 0;
        }

        DETFEpochNaturalExpansionLib.AccrualInput memory in_ = _expansionInput();
        uint256 newTs_;
        (mintAmount_, newTs_) = DETFEpochNaturalExpansionLib.computeRealization(in_);
        if (newTs_ != s.lastExpansionTimestamp) {
            s.lastExpansionTimestamp = newTs_;
        }
        if (mintAmount_ > 0) {
            _mintDetf(address(s.bondNftVault), mintAmount_);
            emit IUniswapV4SingleStandardExchangeDETF.NaturalSupplyExpanded(
                mintAmount_, in_.spotSyntheticPrice, newTs_
            );
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Mint quote                                   */
    /* ---------------------------------------------------------------------- */

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
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

    /// @notice Unboosted DETF self-leg for a bond join (D24). Empty book uses creation rate.
    function _quoteBondJoinDetf(uint256 pairAmount_) internal view returns (uint256 detfOut_) {
        if (pairAmount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 creation_ = s.creationPairPerDetfWad;
        uint256 pairWad_ = _toWad(pairAmount_, _pairDecimals());
        if (!s.isReserveLive || !_hookIsLive()) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairAmount_ : detfOut_;
        }
        IHook hook_ = IHook(s.reserveHook);
        uint256 rawReserve_ = hook_.rawReserve();
        uint256 pairReserve_ = hook_.currency0() == address(s.pairToken)
            ? hook_.reserveCurrency0()
            : hook_.reserveCurrency1();
        if (rawReserve_ == 0 || pairReserve_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairAmount_ : detfOut_;
        }
        detfOut_ = pairAmount_ * rawReserve_ / pairReserve_;
        if (detfOut_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
        }
    }

    function _topUpFeeCreatorShares() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return;
        (, uint256 f_, uint256 c_) = s.feeOracle.seigniorageSplitOfVault(address(this));
        DETFBondLifecycleLib._topUpFeeCreatorShares(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), f_, c_
        );
    }

    /// @notice Closed-form DETF out for exact-in pair notional against live hook effective reserves.
    /// @dev Pre-live / empty: uses creation rate. Live: ConstProd sale of pair → raw DETF face.
    function _quoteDetfAgainstReserve(uint256 pairAmount_) internal view returns (uint256 detfOut_) {
        if (pairAmount_ == 0) return 0;
        uint256 creation_ = Repo._layoutStruct().creationPairPerDetfWad;
        uint256 pairWad_ = _toWad(pairAmount_, _pairDecimals());
        if (!Repo._layoutStruct().isReserveLive || !_hookIsLive()) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairAmount_ : detfOut_;
        }
        detfOut_ = _quoteDetfLive(pairAmount_, pairWad_, creation_);
    }

    function _quoteDetfLive(uint256 pairAmount_, uint256 pairWad_, uint256 creation_)
        private
        view
        returns (uint256 detfOut_)
    {
        IHook hook_ = IHook(Repo._layoutStruct().reserveHook);
        uint256 rawReserve_ = hook_.rawReserve();
        uint256 pairReserve_ = hook_.currency0() == address(Repo._layoutStruct().pairToken)
            ? hook_.reserveCurrency0()
            : hook_.reserveCurrency1();
        if (rawReserve_ == 0 || pairReserve_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairAmount_ : detfOut_;
        }
        detfOut_ = ConstProdUtils._saleQuote(pairAmount_, pairReserve_, rawReserve_, 300, 100_000);
        if (detfOut_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
        }
    }

    function _hookIsLive() internal view returns (bool) {
        try IHook(Repo._layoutStruct().reserveHook).isLive() returns (bool live_) {
            return live_;
        } catch {
            return false;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Hook deposit / withdraw                        */
    /* ---------------------------------------------------------------------- */

    function _depositSinglePair(uint256 pairAmount_, address lpTo_) internal returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        s.pairToken.forceApprove(s.reserveHook, pairAmount_);
        lpOut_ = IHook(s.reserveHook).depositSingle(
            address(s.pairToken), pairAmount_, lpTo_, 0, block.timestamp + 1
        );
    }

    function _depositProportional(uint256 detfAmount_, uint256 pairAmount_, address lpTo_)
        internal
        returns (uint256 lpOut_)
    {
        address hookAddr_ = Repo._layoutStruct().reserveHook;
        IHook hook_ = IHook(hookAddr_);
        bool detfIs0_ = hook_.currency0() == address(this);
        uint256 a0_ = detfIs0_ ? detfAmount_ : pairAmount_;
        uint256 a1_ = detfIs0_ ? pairAmount_ : detfAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).forceApprove(hookAddr_, detfAmount_);
        if (pairAmount_ > 0) Repo._layoutStruct().pairToken.forceApprove(hookAddr_, pairAmount_);
        (lpOut_,,) = hook_.deposit(a0_, a1_, lpTo_, 0, block.timestamp + 1);
    }

    function _depositSingleDetf(uint256 detfAmount_, address lpTo_) internal returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20(address(this)).forceApprove(s.reserveHook, detfAmount_);
        lpOut_ = IHook(s.reserveHook).depositSingle(address(this), detfAmount_, lpTo_, 0, block.timestamp + 1);
    }

    function _withdrawSinglePair(uint256 lpAmount_, address to_) internal returns (uint256 pairOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20(s.reserveHook).forceApprove(s.reserveHook, lpAmount_);
        pairOut_ = IHook(s.reserveHook).withdrawSingle(
            lpAmount_, address(s.pairToken), to_, 0, block.timestamp + 1
        );
    }

    function _withdrawProportional(uint256 lpAmount_)
        internal
        returns (uint256 detfOut_, uint256 pairOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        IERC20(s.reserveHook).forceApprove(s.reserveHook, lpAmount_);
        (uint256 a0_, uint256 a1_) = hook_.withdraw(lpAmount_, address(this), 0, 0, block.timestamp + 1);
        bool detfIs0_ = hook_.currency0() == address(this);
        detfOut_ = detfIs0_ ? a0_ : a1_;
        pairOut_ = detfIs0_ ? a1_ : a0_;
    }

    function _previewProportional(uint256 lpAmount_)
        internal
        view
        returns (uint256 detfOut_, uint256 pairOut_)
    {
        IHook hook_ = IHook(Repo._layoutStruct().reserveHook);
        (uint256 a0_, uint256 a1_) = hook_.previewWithdraw(lpAmount_);
        bool detfIs0_ = hook_.currency0() == address(this);
        detfOut_ = detfIs0_ ? a0_ : a1_;
        pairOut_ = detfIs0_ ? a1_ : a0_;
    }

    function _previewProportionalDetf(uint256 lpAmount_) internal view returns (uint256) {
        (uint256 detfOut_,) = _previewProportional(lpAmount_);
        return detfOut_;
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol seigniorage compound                      */
    /* ---------------------------------------------------------------------- */

    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn_, uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || !s.isReserveLive) {
            return (0, 0);
        }

        // Realize expansion first (public compound IS a realize path).
        _realizeExpansionIfNeeded();

        uint256 protocolId_ = s.bondNftVault.detfNFTId();
        uint256 pending_ = s.bondNftVault.pendingRewards(protocolId_);
        if (!DETFProtocolCompoundLib.isCompoundable(pending_)) {
            return (0, 0);
        }

        try this.compoundProtocolRewardsAtomic() returns (uint256 d_, uint256 l_) {
            detfIn_ = d_;
            lpOut_ = l_;
            if (lpOut_ > 0) {
                emit IUniswapV4SingleStandardExchangeDETF.ProtocolRewardsCompounded(detfIn_, lpOut_);
            }
        } catch {
            return (0, 0);
        }
    }

    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn_, uint256 lpOut_) {
        if (msg.sender != address(this)) revert NotSelf();
        return _compoundProtocolRewardsAtomic();
    }

    function _compoundProtocolRewardsAtomic() internal returns (uint256 detfIn_, uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IDETFNFTVault vault_ = s.bondNftVault;

        detfIn_ = vault_.reallocateDetfNftRewards(address(this));
        if (detfIn_ == 0) return (0, 0);

        // D13: join LP onto the NFT vault; credit id 0 originalShares.
        lpOut_ = _depositSingleDetf(detfIn_, _bondLpHolder());
        if (lpOut_ == 0) revert CompoundJoinProducedZeroLp();

        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reserveHook),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            s.detfNftId == 0 ? vault_.detfNFTId() : s.detfNftId,
            lpOut_
        );
        _topUpFeeCreatorShares();
    }

    /// @notice NFT vault / claim-authorized unwind of LP → pair.
    /// @dev Bond NFT maturity pulls user LP from NFT; claim/self pulls protocol LP from rebasing.
    function _claimLiquidity(uint256 lpAmount_, address recipient_) internal returns (uint256 pairOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address bond_ = address(s.bondNftVault);
        address claim_ = address(s.rebasingClaimToken);
        if (msg.sender != bond_ && msg.sender != claim_ && msg.sender != address(this)) {
            revert Repo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert Repo.ZeroAmount();
        if (msg.sender == bond_) {
            _pullBondLp(lpAmount_);
        } else {
            _ensureProtocolLpOnDiamond(lpAmount_);
        }
        pairOut_ = _withdrawSinglePair(lpAmount_, recipient_ == address(0) ? msg.sender : recipient_);
        // Money route end-order: pair leave diamond → full hold-set sync (L-DETF-END-ORDER).
        _syncAllExpectedHoldReserves();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Transfers                                 */
    /* ---------------------------------------------------------------------- */

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
        Repo.Storage storage s = Repo._layoutStruct();
        return address(s.feeOracle.feeTo());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }

    /// @dev Settle tokenIn to pair amount (pair itself, SE share→pair, or SE token→pair).
    function _settleToPair(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_, uint256 deadline_)
        internal
        returns (uint256 pairAmount_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(tokenIn_) == address(s.pairToken)) {
            return _pullToken(tokenIn_, amountIn_, pretransferred_);
        }
        uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        if (address(tokenIn_) == address(s.standardExchangeVaultShare) || _isAllowlistedTokenIn(tokenIn_)) {
            // Nested SE fund: push + pretransferred=true (L-DETF-PUSH-NESTED).
            pairAmount_ = _nestedExchangeInPush(
                IStandardExchangeIn(address(s.standardExchangeVault)),
                tokenIn_, pulled_, s.pairToken, 0, address(this), deadline_
            );
            return pairAmount_;
        }
        revert Repo.InvalidRoute(tokenIn_, s.pairToken);
    }
}
