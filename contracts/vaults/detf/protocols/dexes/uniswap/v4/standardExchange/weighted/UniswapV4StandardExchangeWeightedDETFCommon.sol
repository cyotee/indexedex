// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";

/// @title UniswapV4StandardExchangeWeightedDETFCommon
/// @notice Shared pricing, gates, capital rating, whole-reserve FD, expansion, compound, hook LP helpers.
///
/// Hook ABI consumption checklist (frozen — do not invent methods):
/// - joinProportional / joinUnbalanced / exitProportional + previews
/// - depositSingle / joinSingleAssetExactIn + previews
/// - previewExitSingleAssetExactBptIn / previewSwapExactIn
/// - isFullBook / nativeReserves / tokens / weight / standardExchange
/// - IERC20 LP on hook diamond; SE In/Out for residual

/// @dev CompoundFacet surface for diamond `address(this)` self-calls (keeps Bonding Facet thin).
interface IWeightedDetfCompoundSelf {
    function tryCompoundProtocolRewardsExternal() external returns (uint256 detfIn_, uint256 lpOut_);
    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn_, uint256 lpOut_);
    function realizeExpansionExternal() external;
    function redepositDetfExternal(uint256 amountNative_, uint256[] calldata pairDust_) external;
    function swapDetfToCapitalExternal(uint256 detfAmt_, address capital_) external returns (uint256 out_);
}

abstract contract UniswapV4StandardExchangeWeightedDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant ONE_WAD = 1e18;
    uint256 internal constant RESIDUAL_DUST = 1;
    uint256 internal constant MIN_WEIGHT = 0.01e18;
    /// @dev Hook MINIMUM_LIQUIDITY (must match WeightedBufferHookMath).
    uint256 internal constant HOOK_MINIMUM_LIQUIDITY = 1000;

    error NotSelf();
    error CompoundJoinProducedZeroLp();
// L-STRUCT-1: MintSplit from detf/common/core/DETFMintSplit.sol

    struct PairLegRating {
        uint8 fundedProductIndex; // product-order pair index
        uint256 pairNotionalNative;
        uint256 pairNotionalWad;
    }

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

    function _rejectPretransferredFirstBond(bool pretransferred_, uint256[] calldata amountsIn_)
        internal
        pure
    {
        if (!pretransferred_) return;
        uint256 claimed_;
        for (uint256 i; i < amountsIn_.length; ++i) {
            claimed_ += amountsIn_[i];
        }
        revert ISecurePullErrors.TransferDeltaInsufficient(claimed_, 0);
    }

    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = Repo._layoutStruct().bondNftVault.unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) revert Repo.BondNotMature(unlock_);
    }

    function _requireNotStandingRewardNft(uint256 tokenId_) internal pure {
        if (tokenId_ == DETF_FEE_TO_BOND_NFT_ID || tokenId_ == DETF_CREATOR_BOND_NFT_ID) {
            revert IDetfErrors.DETFNFTRestricted(tokenId_);
        }
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert Repo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
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

    function _decimalsOf(address token_) internal view returns (uint8) {
        return IERC20Metadata(token_).decimals();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Protocol / bonded LP accounting                     */
    /* ---------------------------------------------------------------------- */

    function _protocolLpHolder() internal view returns (address) {
        return _bondLpHolder();
    }

    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    function _nftLp() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        address bond_ = address(s.bondNftVault);
        if (bond_ == address(0)) return IERC20(s.reserveHook).balanceOf(address(this));
        return IERC20(s.reserveHook).balanceOf(bond_);
    }

    /// @notice Id-0 4626 slice of NFT-held reserve LP (claim backing). Live-mint extra NAV is excluded.
    function _protocolLp() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        uint256 totalOrig_ = s.bondNftVault.totalOriginalShares();
        if (totalOrig_ == 0) return 0;
        uint256 protoOrig_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        return protoOrig_ * _nftLp() / totalOrig_;
    }

    function _pullProtocolLp(uint256 lpAmount_) internal {
        if (lpAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        uint256 have_ = lp_.balanceOf(address(this));
        if (have_ >= lpAmount_) return;
        uint256 need_ = lpAmount_ - have_;
        address holder_ = _protocolLpHolder();
        if (holder_ == address(this)) {
            if (have_ < lpAmount_) revert Repo.EmptyProtocolLp();
            return;
        }
        if (need_ > lp_.balanceOf(holder_)) revert Repo.EmptyProtocolLp();
        IRebasingClaimToken(holder_).transferHeldToken(lp_, address(this), need_);
    }

    function _pullBondLp(uint256 lpAmount_) internal {
        if (lpAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        uint256 have_ = lp_.balanceOf(address(this));
        if (have_ >= lpAmount_) return;
        uint256 need_ = lpAmount_ - have_;
        address bond_ = address(s.bondNftVault);
        if (bond_ == address(0)) {
            if (have_ < lpAmount_) revert Repo.EmptyProtocolLp();
            return;
        }
        if (need_ > lp_.balanceOf(bond_)) revert Repo.EmptyProtocolLp();
        IDETFNFTVault(bond_).transferHeldToken(lp_, address(this), need_);
    }

    function _ensureProtocolLpOnDiamond(uint256 lpAmount_) internal {
        if (lpAmount_ > _protocolLp()) revert Repo.EmptyProtocolLp();
        _pullProtocolLp(lpAmount_);
    }

    /* ---------------------------------------------------------------------- */
    /*                    Binding-order amount packing                        */
    /* ---------------------------------------------------------------------- */

    /// @notice Pack product-order pair amounts + DETF into binding-order maxes (length n).
    function _packBinding(uint256[] memory pairAmtsProduct_, uint256 detfAmt_)
        internal
        view
        returns (uint256[] memory binding_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        binding_ = new uint256[](s.n);
        binding_[s.detfBindingIndex] = detfAmt_;
        for (uint8 i; i < s.m; ++i) {
            binding_[s.pairBindingIndex[i]] = pairAmtsProduct_[i];
        }
    }

    /// @notice Unpack binding-order residual → (detf, product-order pairs).
    function _unpackBinding(uint256[] memory binding_)
        internal
        view
        returns (uint256 detfAmt_, uint256[] memory pairAmts_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        detfAmt_ = binding_[s.detfBindingIndex];
        pairAmts_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            pairAmts_[i] = binding_[s.pairBindingIndex[i]];
        }
    }

    function _tokenAtBinding(uint8 i_) internal view returns (address) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (i_ == s.detfBindingIndex) return address(this);
        for (uint8 p; p < s.m; ++p) {
            if (s.pairBindingIndex[p] == i_) return address(s.pairTokens[p]);
        }
        revert Repo.InvalidPair();
    }

    /* ---------------------------------------------------------------------- */
    /*              Whole-reserve FD + per-route synthetic                    */
    /* ---------------------------------------------------------------------- */

    function _countedOwnedLp() internal view returns (uint256 totalOwned_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        totalOwned_ = lp_.balanceOf(address(this));
        address bond_ = address(s.bondNftVault);
        if (bond_ != address(0)) totalOwned_ += lp_.balanceOf(bond_);
        address claim_ = address(s.rebasingClaimToken);
        if (claim_ != address(0)) totalOwned_ += lp_.balanceOf(claim_);
    }

    /// @notice Whole-reserve residual → pair_k WAD (includes DETF and other pairs via hook quotes).
    /// @dev Split into helpers to avoid stack-too-deep / StackOverflow on n-leg residual loops.
    function _previewWholeReserveToPair(uint8 productIndex_) internal view returns (uint256 fdWad_) {
        uint256 supply_ = IERC20(Repo._layoutStruct().reserveHook).totalSupply();
        if (supply_ == 0) return 0;
        uint256[] memory residual_;
        try IHook(Repo._layoutStruct().reserveHook).previewExitProportional(supply_) returns (
            uint256[] memory amts_
        ) {
            residual_ = amts_;
        } catch {
            return 0;
        }
        if (residual_.length != Repo._layoutStruct().n) return 0;
        return _fdFromResidual(productIndex_, residual_);
    }

    function _fdFromResidual(uint8 productIndex_, uint256[] memory residual_)
        private
        view
        returns (uint256 fdWad_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        address target_ = address(s.pairTokens[productIndex_]);
        uint8 targetDec_ = _decimalsOf(target_);
        fdWad_ = _toWad(residual_[s.pairBindingIndex[productIndex_]], targetDec_);
        fdWad_ += _fdOtherPairsToTarget(productIndex_, residual_, target_, targetDec_);
        uint256 detfAmt_ = residual_[s.detfBindingIndex];
        if (detfAmt_ > RESIDUAL_DUST) {
            fdWad_ += _toWad(_previewWeightedExactIn(address(this), target_, detfAmt_), targetDec_);
        }
    }

    function _fdOtherPairsToTarget(
        uint8 productIndex_,
        uint256[] memory residual_,
        address target_,
        uint8 targetDec_
    ) private view returns (uint256 addWad_) {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 j; j < s.m; ++j) {
            if (j == productIndex_) continue;
            uint256 amt_ = residual_[s.pairBindingIndex[j]];
            if (amt_ <= RESIDUAL_DUST) continue;
            addWad_ += _toWad(
                _previewWeightedExactIn(address(s.pairTokens[j]), target_, amt_), targetDec_
            );
        }
    }

    function _syntheticSpotVs(uint8 productIndex_) internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        uint256 fd_ = _previewWholeReserveToPair(productIndex_);
        if (fd_ == 0) return ONE_WAD;
        uint256 creation_ = Repo._layoutStruct().creationPairPerDetfWad[productIndex_];
        if (creation_ == 0) return ONE_WAD;
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, supply_);
        return Math.mulDiv(mid_, ONE_WAD, creation_);
    }

    function _syntheticVs(uint8 productIndex_) internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 fd_ = _previewWholeReserveToPair(productIndex_);
        if (fd_ == 0) return ONE_WAD;
        uint256 creation_ = Repo._layoutStruct().creationPairPerDetfWad[productIndex_];
        if (creation_ == 0) return ONE_WAD;
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, effectiveSupply_);
        return Math.mulDiv(mid_, ONE_WAD, creation_);
    }

    function _syntheticVsAddr(address pair_) internal view returns (uint256) {
        return _syntheticVs(Repo._productIndexOfPair(pair_));
    }

    function _syntheticSpotVsAddr(address pair_) internal view returns (uint256) {
        return _syntheticSpotVs(Repo._productIndexOfPair(pair_));
    }

    function _isMintingAllowed(uint8 productIndex_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(
            s.thresholdMode, s.mintThreshold, _syntheticVs(productIndex_)
        );
    }

    function _isBurningAllowed(uint8 productIndex_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(
            s.thresholdMode, s.burnThreshold, _syntheticVs(productIndex_)
        );
    }

    function _isMintingAllowedAddr(address pair_) internal view returns (bool) {
        return _isMintingAllowed(Repo._productIndexOfPair(pair_));
    }

    function _isBurningAllowedAddr(address pair_) internal view returns (bool) {
        return _isBurningAllowed(Repo._productIndexOfPair(pair_));
    }

    /// @notice All external legs mint-rich under Policy (epoch expansion gate).
    /// @dev Uses **spot** synthetics (not debt-inclusive) to avoid circularity:
    ///      syntheticVs → pendingExpansion → allLegsMintRich → syntheticVs.
    ///      Product intent: book richness is inventory/spot; pending is sized from spot min.
    function _allLegsMintRich() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || s.thresholdMode != ThresholdMode.Policy) return false;
        for (uint8 i; i < s.m; ++i) {
            if (_syntheticSpotVs(i) <= s.mintThreshold) return false;
        }
        return true;
    }

    /// @notice Min spot synthetic across external legs (expansion size scalar).
    function _minSpotSynthetic() internal view returns (uint256 minS_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.m == 0) return ONE_WAD;
        minS_ = type(uint256).max;
        for (uint8 i; i < s.m; ++i) {
            uint256 sp_ = _syntheticSpotVs(i);
            if (sp_ < minS_) minS_ = sp_;
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Expansion (epoch)                              */
    /* ---------------------------------------------------------------------- */

    function _expansionInput() internal view returns (DETFEpochNaturalExpansionLib.AccrualInput memory in_) {
        Repo.Storage storage s = Repo._layoutStruct();
        in_.isLive = s.isReserveLive;
        // Gate Policy + all-legs: if not all-rich, treat as non-Policy so pending = 0.
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy && _allLegsMintRich();
        in_.spotSyntheticPrice = _minSpotSynthetic();
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
            emit IUniswapV4StandardExchangeWeightedDETF.NaturalSupplyExpanded(
                mintAmount_, in_.spotSyntheticPrice, newTs_
            );
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Mint quote / rating                          */
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

    function _topUpFeeCreatorShares() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return;
        (, uint256 f_, uint256 c_) =
            IVaultFeeOracleQuery(address(s.feeOracle)).seigniorageSplitOfVault(address(this));
        DETFBondLifecycleLib._topUpFeeCreatorShares(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), f_, c_
        );
    }

    /// @notice Rate capital tokenIn to a funded external pair leg. Never cross-pair mid for mint quote.
    function _rateTokenInToPairLeg(IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        returns (PairLegRating memory r_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (address(tokenIn_) == address(s.pairTokens[i])) {
                r_.fundedProductIndex = i;
                r_.pairNotionalNative = amountIn_;
                r_.pairNotionalWad = _toWad(amountIn_, _decimalsOf(address(s.pairTokens[i])));
                return r_;
            }
        }
        for (uint8 i; i < s.m; ++i) {
            if (address(s.standardExchanges[i]) == address(0)) continue;
            if (
                address(tokenIn_) == address(s.vaultShares[i])
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchanges[i]))
            ) {
                r_.fundedProductIndex = i;
                r_.pairNotionalNative =
                    _previewSeToPair(tokenIn_, amountIn_, s.pairTokens[i], s.standardExchanges[i]);
                r_.pairNotionalWad = _toWad(r_.pairNotionalNative, _decimalsOf(address(s.pairTokens[i])));
                return r_;
            }
        }
        revert Repo.InvalidRoute(tokenIn_, IERC20(address(this)));
    }

    function _tokenInSeTokens(IERC20 token_, address se_) internal view returns (bool) {
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(token_)) return true;
        }
        return false;
    }

    function _previewSeToPair(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 pair_,
        IStandardExchangeProxy se_
    ) internal view returns (uint256) {
        if (address(tokenIn_) == address(pair_)) return amountIn_;
        try IStandardExchangeIn(address(se_)).previewExchangeIn(tokenIn_, amountIn_, pair_) returns (uint256 o_) {
            return o_;
        } catch {
            return 0;
        }
    }

    /// @notice Hook-SoT DETF gross for exact-in pair-leg notional vs live weighted book.
    /// @dev depositSingle(pair) → LP shares → exitSingle DETF equivalent. No WeightedMath here.
    function _quoteDetfAgainstReserve(uint8 productIndex_, uint256 pairNative_)
        internal
        view
        returns (uint256 detfOut_)
    {
        if (pairNative_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address pair_ = address(s.pairTokens[productIndex_]);
        uint256 creation_ = s.creationPairPerDetfWad[productIndex_];
        uint8 dec_ = _decimalsOf(pair_);
        uint256 pairWad_ = _toWad(pairNative_, dec_);

        if (!s.isReserveLive) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairNative_ : detfOut_;
        }

        IHook hook_ = IHook(s.reserveHook);
        // Shared preview path with execution depositSingle.
        uint256 shares_;
        try hook_.previewDepositSingle(pair_, pairNative_) returns (uint256 sh_) {
            shares_ = sh_;
        } catch {
            try hook_.previewJoinSingleAssetExactIn(pair_, pairNative_) returns (uint256 sh2_) {
                shares_ = sh2_;
            } catch {
                shares_ = 0;
            }
        }
        if (shares_ > 0) {
            try hook_.previewExitSingleAssetExactBptIn(address(this), shares_) returns (uint256 d_) {
                if (d_ > 0) return d_;
            } catch {}
        }
        // Fallback: weighted swap pair → DETF.
        detfOut_ = _previewWeightedExactIn(pair_, address(this), pairNative_);
        if (detfOut_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
        }
    }

    function _previewWeightedExactIn(address tokenIn_, address tokenOut_, uint256 amountIn_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0 || tokenIn_ == tokenOut_) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        try IStandardExchangeIn(address(hook_)).previewExchangeIn(
            IERC20(tokenIn_), amountIn_, IERC20(tokenOut_)
        ) returns (uint256 o_) {
            return o_;
        } catch {
            try hook_.previewSwapExactIn(tokenIn_, tokenOut_, amountIn_) returns (uint256 o2_) {
                return o2_;
            } catch {
                return 0;
            }
        }
    }

    function _weightedExactIn(address tokenIn_, address tokenOut_, uint256 amountIn_, address recipient_)
        internal
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0) return 0;
        if (tokenIn_ == tokenOut_) {
            if (recipient_ != address(this) && amountIn_ > 0) {
                IERC20(tokenIn_).safeTransfer(recipient_, amountIn_);
            }
            return amountIn_;
        }
        Repo.Storage storage s = Repo._layoutStruct();
        address hook_ = s.reserveHook;
        // Nested hook fund: push + pretransferred=true (L-DETF-PUSH-NESTED; host WH durable pull).
        amountOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(hook_),
            IERC20(tokenIn_),
            amountIn_,
            IERC20(tokenOut_),
            0,
            recipient_,
            block.timestamp + 1
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Hook deposit / join / exit                     */
    /* ---------------------------------------------------------------------- */

    function _requireSingleAssetEligible() internal view {
        if (!_isSingleAssetEligible()) revert Repo.NotSingleAssetEligible();
    }

    /// @dev Full native book + redeemable LP past MINIMUM_LIQUIDITY (MIN-only book is not single-asset eligible).
    function _isSingleAssetEligible() internal view returns (bool) {
        address hook_ = Repo._layoutStruct().reserveHook;
        if (!IHook(hook_).isFullBook()) return false;
        // Hook depositSingle rejects empty supply; MIN-only residual is exceptional / not user-eligible.
        if (IERC20(hook_).totalSupply() <= HOOK_MINIMUM_LIQUIDITY) return false;
        return true;
    }

    function _depositSingle(address tokenIn_, uint256 amountIn_, address lpTo_)
        internal
        returns (uint256 lpOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        _requireSingleAssetEligible();
        IERC20(tokenIn_).forceApprove(s.reserveHook, amountIn_);
        lpOut_ = IHook(s.reserveHook).depositSingle(tokenIn_, amountIn_, lpTo_, 0, block.timestamp + 1);
    }

    function _joinProportional(uint256[] memory amountsBinding_, address lpTo_)
        internal
        returns (uint256 shares_, uint256[] memory used_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        // Approve each non-zero leg.
        for (uint8 i; i < s.n; ++i) {
            uint256 a_ = amountsBinding_[i];
            if (a_ == 0) continue;
            address t_ = _tokenAtBinding(i);
            IERC20(t_).forceApprove(s.reserveHook, a_);
        }
        (shares_, used_) =
            IHook(s.reserveHook).joinProportional(amountsBinding_, lpTo_, 0, block.timestamp + 1);
    }

    function _joinUnbalanced(uint256[] memory amountsBinding_, address lpTo_)
        internal
        returns (uint256 shares_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 i; i < s.n; ++i) {
            uint256 a_ = amountsBinding_[i];
            if (a_ == 0) continue;
            address t_ = _tokenAtBinding(i);
            IERC20(t_).forceApprove(s.reserveHook, a_);
        }
        shares_ = IHook(s.reserveHook).joinUnbalanced(amountsBinding_, lpTo_, 0, block.timestamp + 1);
    }

    function _exitProportional(uint256 shares_, address to_)
        internal
        returns (uint256[] memory amounts_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20(s.reserveHook).forceApprove(s.reserveHook, shares_);
        uint256[] memory mins_ = new uint256[](s.n);
        amounts_ = IHook(s.reserveHook).exitProportional(shares_, to_, mins_, block.timestamp + 1);
    }

    /// @notice Redeposit DETF self-leg. Prefer depositSingle when full book; else multipath DETF-only.
    function _redepositDetfSelfLeg(uint256 amountNative_) internal returns (uint256 lpOut_) {
        uint256[] memory zeros_ = new uint256[](Repo._layoutStruct().m);
        return _redepositDetfSelfLegWithPairDust(amountNative_, zeros_);
    }

    /// @notice Redeposit DETF; optional pair dust enables multipath when not full-book (sole-bond close).
    function _redepositDetfSelfLegWithPairDust(uint256 amountNative_, uint256[] memory pairDust_)
        internal
        returns (uint256 lpOut_)
    {
        if (amountNative_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address holder_ = _protocolLpHolder();
        IHook hook_ = IHook(s.reserveHook);
        if (hook_.isFullBook()) {
            IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
            try hook_.depositSingle(address(this), amountNative_, holder_, 0, block.timestamp + 1) returns (
                uint256 shares_
            ) {
                return shares_;
            } catch {
                // fall through to multipath
            }
        }
        // Multipath: DETF + optional pair dust (restores full book when reserves still multi-positive).
        uint256[] memory binding_ = _packBinding(pairDust_, amountNative_);
        for (uint8 i; i < s.m; ++i) {
            if (pairDust_[i] > 0) {
                s.pairTokens[i].forceApprove(s.reserveHook, pairDust_[i]);
            }
        }
        IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
        try hook_.joinUnbalanced(binding_, holder_, 0, block.timestamp + 1) returns (uint256 shares_) {
            if (shares_ == 0) revert Repo.RedepositFailed();
            return shares_;
        } catch {
            // Last resort: DETF-only max.
            uint256[] memory zeros_ = new uint256[](s.m);
            uint256[] memory b2_ = _packBinding(zeros_, amountNative_);
            IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
            try hook_.joinUnbalanced(b2_, holder_, 0, block.timestamp + 1) returns (uint256 shares2_) {
                if (shares2_ == 0) revert Repo.RedepositFailed();
                return shares2_;
            } catch {
                revert Repo.RedepositFailed();
            }
        }
    }

    /// @notice Consolidate product-order pair residual → tokenOut pair via hook SE swaps.
    function _consolidateToPair(address tokenOut_, uint256[] memory pairAmts_)
        internal
        returns (uint256 outAmt_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!Repo._isPairToken(tokenOut_)) {
            revert Repo.InvalidRoute(IERC20(address(this)), IERC20(tokenOut_));
        }
        for (uint8 i; i < s.m; ++i) {
            uint256 amt_ = pairAmts_[i];
            if (amt_ == 0) continue;
            address from_ = address(s.pairTokens[i]);
            if (from_ == tokenOut_) {
                outAmt_ += amt_;
            } else if (amt_ > RESIDUAL_DUST) {
                outAmt_ += _weightedExactIn(from_, tokenOut_, amt_, address(this));
            }
        }
    }

    function _previewConsolidateToPair(address tokenOut_, uint256[] memory pairAmts_)
        internal
        view
        returns (uint256 outAmt_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!Repo._isPairToken(tokenOut_)) return 0;
        for (uint8 i; i < s.m; ++i) {
            uint256 amt_ = pairAmts_[i];
            if (amt_ == 0) continue;
            address from_ = address(s.pairTokens[i]);
            if (from_ == tokenOut_) {
                outAmt_ += amt_;
            } else if (amt_ > RESIDUAL_DUST) {
                outAmt_ += _previewWeightedExactIn(from_, tokenOut_, amt_);
            }
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol seigniorage compound                      */
    /* ---------------------------------------------------------------------- */

    /// @dev External self-call resets EVM stack so bond/claim paths do not StackOverflow on n-leg FD.
    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn_, uint256 lpOut_) {
        // Diamond-route to CompoundFacet (not inherited on Bonding Facet — EIP-170).
        try IWeightedDetfCompoundSelf(address(this)).tryCompoundProtocolRewardsExternal() returns (
            uint256 d_, uint256 l_
        ) {
            return (d_, l_);
        } catch {
            return (0, 0);
        }
    }

    /// @dev External entrypoints live on CompoundTarget/Facet so Bonding Facet stays under EIP-170.

    function _tryCompoundProtocolRewardsInner() internal returns (uint256 detfIn_, uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || !s.isReserveLive) {
            return (0, 0);
        }
        _realizeExpansionIfNeeded();
        uint256 protocolId_ = s.bondNftVault.detfNFTId();
        uint256 pending_ = s.bondNftVault.pendingRewards(protocolId_);
        if (!DETFProtocolCompoundLib.isCompoundable(pending_)) {
            return (0, 0);
        }
        // Skip without revert when not single-asset eligible (PRD).
        if (!_isSingleAssetEligible()) {
            return (0, 0);
        }
        try IWeightedDetfCompoundSelf(address(this)).compoundProtocolRewardsAtomic() returns (
            uint256 d_, uint256 l_
        ) {
            detfIn_ = d_;
            lpOut_ = l_;
            if (lpOut_ > 0) {
                emit IUniswapV4StandardExchangeWeightedDETF.ProtocolRewardsCompounded(detfIn_, lpOut_);
            }
        } catch {
            return (0, 0);
        }
    }

    function _compoundProtocolRewardsAtomic() internal returns (uint256 detfIn_, uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IDETFNFTVault vault_ = s.bondNftVault;
        detfIn_ = vault_.reallocateDetfNftRewards(address(this));
        if (detfIn_ == 0) return (0, 0);
        lpOut_ = _depositSingle(address(this), detfIn_, _bondLpHolder());
        if (lpOut_ == 0) revert CompoundJoinProducedZeroLp();
        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reserveHook),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            vault_.detfNFTId(),
            lpOut_
        );
        _topUpFeeCreatorShares();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Transfers                                 */
    /* ---------------------------------------------------------------------- */

    /// @dev Reserve-delta pull (L-DETF-LOCAL-PUSH). No absolute free credit on pretransfer.
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

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

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
        return address(Repo._layoutStruct().feeOracle.feeTo());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }

    /// @dev Settle tokenIn to native pair units for a funded leg.
    function _settleToPairLeg(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_, uint256 deadline_)
        internal
        returns (PairLegRating memory r_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        // Direct pair face.
        for (uint8 i; i < s.m; ++i) {
            if (address(tokenIn_) == address(s.pairTokens[i])) {
                uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
                return _rateTokenInToPairLeg(tokenIn_, pulled_);
            }
        }
        uint256 pulled2_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        for (uint8 i; i < s.m; ++i) {
            if (address(s.standardExchanges[i]) == address(0)) continue;
            if (
                address(tokenIn_) == address(s.vaultShares[i])
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchanges[i]))
            ) {
                address se_ = address(s.standardExchanges[i]);
                // ERC-4626 SE unwrap burns SE shares from msg.sender — keep shares on DETF and
                // let SE pull/burn (pretransferred=false). Pre-transfer to SE would leave DETF with
                // 0 shares and underflow on burn. Other SE vault tokens: transfer then pretransferred.
                bool isSeShare_ = address(tokenIn_) == se_;
                if (isSeShare_) {
                    uint256 pairAmt_ = _nestedExchangeInPush(
                        IStandardExchangeIn(se_), tokenIn_, pulled2_, s.pairTokens[i], 0, address(this), deadline_
                    );
                    r_.fundedProductIndex = i;
                    r_.pairNotionalNative = pairAmt_;
                    r_.pairNotionalWad = _toWad(pairAmt_, _decimalsOf(address(s.pairTokens[i])));
                    return r_;
                }
                tokenIn_.safeTransfer(se_, pulled2_);
                uint256 pairAmt2_ = IStandardExchangeIn(se_).exchangeIn(
                    tokenIn_, pulled2_, s.pairTokens[i], 0, address(this), true, deadline_
                );
                r_.fundedProductIndex = i;
                r_.pairNotionalNative = pairAmt2_;
                r_.pairNotionalWad = _toWad(pairAmt2_, _decimalsOf(address(s.pairTokens[i])));
                return r_;
            }
        }
        revert Repo.InvalidRoute(tokenIn_, IERC20(address(this)));
    }

    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (address(token_) == address(s.pairTokens[i])) return true;
            if (address(token_) == address(s.vaultShares[i])) return true;
            if (
                address(s.standardExchanges[i]) != address(0)
                    && _tokenInSeTokens(token_, address(s.standardExchanges[i]))
            ) {
                return true;
            }
        }
        return false;
    }

    /// @notice Open-time DETF-valued mid of pair notional for effectiveShares (hook SoT).
    function _pairNotionalToDetfWad(uint8 productIndex_, uint256 pairNative_)
        internal
        view
        returns (uint256)
    {
        if (pairNative_ == 0) return 0;
        // Prefer live hook quote; fall back to creation rate.
        uint256 q_ = _quoteDetfAgainstReserve(productIndex_, pairNative_);
        if (q_ > 0) return q_;
        Repo.Storage storage s = Repo._layoutStruct();
        address pair_ = address(s.pairTokens[productIndex_]);
        return Math.mulDiv(
            _toWad(pairNative_, _decimalsOf(pair_)), ONE_WAD, s.creationPairPerDetfWad[productIndex_]
        );
    }

    function _creditBondPot(uint256 potDetf_) internal {
        address bondVault_ = address(Repo._layoutStruct().bondNftVault);
        if (potDetf_ > 0 && bondVault_ != address(0)) {
            _mintDetf(bondVault_, potDetf_);
        }
    }

    /* shared helpers used by bonding + exchange (Option 1e siblings) */
    function _isShareOrSeTokenOut(IERC20 tokenOut_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (address(tokenOut_) == address(s.vaultShares[i])) return true;
            if (
                address(s.standardExchanges[i]) != address(0)
                    && _tokenInSeTokens(tokenOut_, address(s.standardExchanges[i]))
            ) {
                return true;
            }
        }
        return false;
    }


    function _pairForShareOut(IERC20 tokenOut_) internal view returns (address) {
        Repo.Storage storage s = Repo._layoutStruct();
        for (uint8 i; i < s.m; ++i) {
            if (
                address(tokenOut_) == address(s.vaultShares[i])
                    || (
                        address(s.standardExchanges[i]) != address(0)
                            && _tokenInSeTokens(tokenOut_, address(s.standardExchanges[i]))
                    )
            ) {
                return address(s.pairTokens[i]);
            }
        }
        revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
    }


    function _seWrap(address pair_, uint256 pairAmt_, IERC20 tokenOut_, address recipient_)
        internal
        returns (uint256 out_)
    {
        if (pairAmt_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        uint8 idx_ = Repo._productIndexOfPair(pair_);
        address se_ = address(s.standardExchanges[idx_]);
        if (se_ == address(0)) revert Repo.InvalidRoute(IERC20(pair_), tokenOut_);
        out_ = _nestedExchangeInPush(
            IStandardExchangeIn(se_), IERC20(pair_), pairAmt_, tokenOut_, 0, recipient_, block.timestamp + 1
        );
    }


}
