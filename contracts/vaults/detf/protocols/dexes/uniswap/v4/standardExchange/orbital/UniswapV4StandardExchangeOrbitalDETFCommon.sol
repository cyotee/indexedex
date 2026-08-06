// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";

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
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as HookRepo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFCommon
/// @notice Shared pricing, gates, Q15 rating, FD residual, expansion, compound, hook LP helpers.
///
/// Hook ABI consumption checklist (frozen — do not invent methods):
/// - addLiquidity / removeLiquidity / previewAddLiquidity / previewRemoveLiquidity
/// - depositSingle / previewDepositSingle / isZapEligible
/// - effectiveReserve(i) / effectiveReserves / token0/1/2 / standardExchange(i)
/// - previewSwapExactIn / exchangeIn (SE facet)
/// - IERC20 LP on hook diamond
abstract contract UniswapV4StandardExchangeOrbitalDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant ONE_WAD = 1e18;
    /// @dev Dust threshold for uneconomic residual pair (plan §12 freeze).
    uint256 internal constant RESIDUAL_DUST = 1;

    error NotSelf();
    error CompoundJoinProducedZeroLp();

    struct MintSplit {
        uint256 grossDetf;
        uint256 userDetf;
        uint256 feeToDetf;
        uint256 inventoryDetf;
    }

    struct PairLegRating {
        uint8 fundedPairLeg; // 0 or 1
        uint256 pairNotionalNative;
        uint256 pairNotionalWad;
    }

    struct BindingAmounts {
        uint256 a0;
        uint256 a1;
        uint256 a2;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liveness                                  */
    /* ---------------------------------------------------------------------- */

    function _requireReserveLive() internal view {
        if (!Repo._layoutStruct().isReserveLive) revert Repo.ReserveNotLive();
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        _requireNotDisabled();
        if (amount_ == 0) revert Repo.ZeroAmount();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
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

    function _pair0Decimals() internal view returns (uint8) {
        return _decimalsOf(address(Repo._layoutStruct().pairToken0));
    }

    function _pair1Decimals() internal view returns (uint8) {
        return _decimalsOf(address(Repo._layoutStruct().pairToken1));
    }

    /* ---------------------------------------------------------------------- */
    /*                    Protocol / bonded LP accounting                     */
    /* ---------------------------------------------------------------------- */

    function _protocolLpHolder() internal view returns (address) {
        address claim_ = address(Repo._layoutStruct().rebasingClaimToken);
        return claim_ == address(0) ? address(this) : claim_;
    }

    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    function _protocolLp() internal view returns (uint256) {
        return IERC20(Repo._layoutStruct().reserveHook).balanceOf(_protocolLpHolder());
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

    function _packBinding(uint256 pair0Amt_, uint256 pair1Amt_, uint256 detfAmt_)
        internal
        view
        returns (BindingAmounts memory b_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.detfBindingIndex == 0) {
            b_.a0 = detfAmt_;
            if (s.pair0BindingIndex == 1) {
                b_.a1 = pair0Amt_;
                b_.a2 = pair1Amt_;
            } else {
                b_.a1 = pair1Amt_;
                b_.a2 = pair0Amt_;
            }
        } else if (s.detfBindingIndex == 1) {
            b_.a1 = detfAmt_;
            if (s.pair0BindingIndex == 0) {
                b_.a0 = pair0Amt_;
                b_.a2 = pair1Amt_;
            } else {
                b_.a0 = pair1Amt_;
                b_.a2 = pair0Amt_;
            }
        } else {
            b_.a2 = detfAmt_;
            if (s.pair0BindingIndex == 0) {
                b_.a0 = pair0Amt_;
                b_.a1 = pair1Amt_;
            } else {
                b_.a0 = pair1Amt_;
                b_.a1 = pair0Amt_;
            }
        }
    }

    function _unpackBinding(uint256 a0_, uint256 a1_, uint256 a2_)
        internal
        view
        returns (uint256 detfAmt_, uint256 pair0Amt_, uint256 pair1Amt_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256[3] memory amts = [a0_, a1_, a2_];
        detfAmt_ = amts[s.detfBindingIndex];
        pair0Amt_ = amts[s.pair0BindingIndex];
        pair1Amt_ = amts[s.pair1BindingIndex];
    }

    function _tokenAtBinding(uint8 i_) internal view returns (address) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (i_ == s.detfBindingIndex) return address(this);
        if (i_ == s.pair0BindingIndex) return address(s.pairToken0);
        return address(s.pairToken1);
    }

    /* ---------------------------------------------------------------------- */
    /*                         FD residual (Q21)                              */
    /* ---------------------------------------------------------------------- */

    /// @notice RateAsset WAD value of one LP share claim (full residual incl. DETF→rateAsset).
    function _previewLpToRateAsset(uint256 lp_) internal view returns (uint256 fdWad_) {
        if (lp_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        (uint256 a0_, uint256 a1_, uint256 a2_) = hook_.previewRemoveLiquidity(lp_);
        (uint256 detfAmt_, uint256 p0Amt_, uint256 p1Amt_) = _unpackBinding(a0_, a1_, a2_);

        address rate_ = address(s.rateAsset);
        address other_ = rate_ == address(s.pairToken0) ? address(s.pairToken1) : address(s.pairToken0);
        uint256 rateNative_ = rate_ == address(s.pairToken0) ? p0Amt_ : p1Amt_;
        uint256 otherNative_ = rate_ == address(s.pairToken0) ? p1Amt_ : p0Amt_;

        fdWad_ = _toWad(rateNative_, _decimalsOf(rate_));
        if (otherNative_ > 0) {
            fdWad_ += _toWad(_previewSphereExactIn(other_, rate_, otherNative_), _decimalsOf(rate_));
        }
        // Hop order freeze: other pair first, then DETF → rateAsset.
        if (detfAmt_ > 0) {
            fdWad_ += _toWad(_previewSphereExactIn(address(this), rate_, detfAmt_), _decimalsOf(rate_));
        }
    }

    function _countedOwnedLp() internal view returns (uint256 totalOwned_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.reserveHook);
        totalOwned_ = lp_.balanceOf(address(this));
        address bond_ = address(s.bondNftVault);
        if (bond_ != address(0)) totalOwned_ += lp_.balanceOf(bond_);
        address claim_ = address(s.rebasingClaimToken);
        if (claim_ != address(0)) totalOwned_ += lp_.balanceOf(claim_);
    }

    function _fdRateAssetWad() internal view returns (uint256 fd_) {
        uint256 totalOwned_ = _countedOwnedLp();
        // Exclude address(0) MINIMUM_LIQUIDITY residual (not held by counted holders).
        if (totalOwned_ == 0) return 0;
        return _previewLpToRateAsset(totalOwned_);
    }

    /// @notice Pairs-only residual → rateAsset (excludes DETF self-leg). For FD Q21 tests.
    function _fdPairsOnlyRateAssetWad() internal view returns (uint256 fdWad_) {
        uint256 lp_ = _countedOwnedLp();
        if (lp_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        (uint256 a0_, uint256 a1_, uint256 a2_) = hook_.previewRemoveLiquidity(lp_);
        (, uint256 p0Amt_, uint256 p1Amt_) = _unpackBinding(a0_, a1_, a2_);
        address rate_ = address(s.rateAsset);
        address other_ = rate_ == address(s.pairToken0) ? address(s.pairToken1) : address(s.pairToken0);
        uint256 rateNative_ = rate_ == address(s.pairToken0) ? p0Amt_ : p1Amt_;
        uint256 otherNative_ = rate_ == address(s.pairToken0) ? p1Amt_ : p0Amt_;
        fdWad_ = _toWad(rateNative_, _decimalsOf(rate_));
        if (otherNative_ > 0) {
            fdWad_ += _toWad(_previewSphereExactIn(other_, rate_, otherNative_), _decimalsOf(rate_));
        }
    }

    function _creationRateAssetPerDetfWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        return address(s.rateAsset) == address(s.pairToken0)
            ? s.creationPair0PerDetfWad
            : s.creationPair1PerDetfWad;
    }

    function _syntheticPriceSpot() internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        uint256 fd_ = _fdRateAssetWad();
        if (fd_ == 0) return ONE_WAD;
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, supply_);
        return Math.mulDiv(mid_, ONE_WAD, _creationRateAssetPerDetfWad());
    }

    function _syntheticPrice() internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return ONE_WAD;
        uint256 pending_ = _previewPendingExpansionMint();
        uint256 effectiveSupply_ = supply_ + pending_;
        uint256 fd_ = _fdRateAssetWad();
        if (fd_ == 0) return ONE_WAD;
        uint256 mid_ = Math.mulDiv(fd_, ONE_WAD, effectiveSupply_);
        return Math.mulDiv(mid_, ONE_WAD, _creationRateAssetPerDetfWad());
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
            emit IUniswapV4StandardExchangeOrbitalDETF.NaturalSupplyExpanded(
                mintAmount_, in_.spotSyntheticPrice, newTs_
            );
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                           Mint quote / Q15                             */
    /* ---------------------------------------------------------------------- */

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeeWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.usageFeeOfVault(address(this));
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 afterFee_, uint256 feeTo_) = DETFUsageFeeLib._splitUsageFee(gross_, _usageFeeWad());
        split_.feeToDetf = feeTo_;
        uint256 halfInc_ = _seigniorageIncentiveWad() / 2;
        split_.inventoryDetf = Math.mulDiv(afterFee_, halfInc_, ONE_WAD);
        split_.userDetf = afterFee_ - split_.inventoryDetf;
    }

    /// @notice Rate capital tokenIn to a funded external pair leg (PRD Q15). Never rateAsset mid for mint quote.
    function _rateTokenInToPairLeg(IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        returns (PairLegRating memory r_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(tokenIn_) == address(s.pairToken0)) {
            r_.fundedPairLeg = 0;
            r_.pairNotionalNative = amountIn_;
            r_.pairNotionalWad = _toWad(amountIn_, _pair0Decimals());
            return r_;
        }
        if (address(tokenIn_) == address(s.pairToken1)) {
            r_.fundedPairLeg = 1;
            r_.pairNotionalNative = amountIn_;
            r_.pairNotionalWad = _toWad(amountIn_, _pair1Decimals());
            return r_;
        }
        if (address(s.standardExchange0) != address(0)) {
            if (
                address(tokenIn_) == address(s.vaultShare0)
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchange0))
            ) {
                r_.fundedPairLeg = 0;
                r_.pairNotionalNative = _previewSeToPair(tokenIn_, amountIn_, s.pairToken0, s.standardExchange0);
                r_.pairNotionalWad = _toWad(r_.pairNotionalNative, _pair0Decimals());
                return r_;
            }
        }
        if (address(s.standardExchange1) != address(0)) {
            if (
                address(tokenIn_) == address(s.vaultShare1)
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchange1))
            ) {
                r_.fundedPairLeg = 1;
                r_.pairNotionalNative = _previewSeToPair(tokenIn_, amountIn_, s.pairToken1, s.standardExchange1);
                r_.pairNotionalWad = _toWad(r_.pairNotionalNative, _pair1Decimals());
                return r_;
            }
        }
        revert Repo.InvalidRoute(tokenIn_, s.rateAsset);
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

    /// @notice Fee-aware closed-form DETF gross for exact-in pair-leg notional vs live reserves.
    function _quoteDetfAgainstReserve(uint8 fundedPairLeg_, uint256 pairNative_)
        internal
        view
        returns (uint256 detfOut_)
    {
        if (pairNative_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address pair_ = fundedPairLeg_ == 0 ? address(s.pairToken0) : address(s.pairToken1);
        uint256 creation_ =
            fundedPairLeg_ == 0 ? s.creationPair0PerDetfWad : s.creationPair1PerDetfWad;
        uint8 dec_ = fundedPairLeg_ == 0 ? _pair0Decimals() : _pair1Decimals();
        uint256 pairWad_ = _toWad(pairNative_, dec_);

        if (!s.isReserveLive) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
            return detfOut_ == 0 ? pairNative_ : detfOut_;
        }

        // Live: sphere exact-in pair → DETF (fee-aware via hook SE surface).
        detfOut_ = _previewSphereExactIn(pair_, address(this), pairNative_);
        if (detfOut_ == 0) {
            detfOut_ = Math.mulDiv(pairWad_, ONE_WAD, creation_);
        }
    }

    function _previewSphereExactIn(address tokenIn_, address tokenOut_, uint256 amountIn_)
        internal
        view
        returns (uint256 amountOut_)
    {
        if (amountIn_ == 0 || tokenIn_ == tokenOut_) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        // Prefer SE exchange preview (same book as V4 doors).
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

    function _sphereExactIn(address tokenIn_, address tokenOut_, uint256 amountIn_, address recipient_)
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
        IERC20(tokenIn_).forceApprove(hook_, amountIn_);
        amountOut_ = IStandardExchangeIn(hook_).exchangeIn(
            IERC20(tokenIn_),
            amountIn_,
            IERC20(tokenOut_),
            0,
            recipient_,
            false,
            block.timestamp + 1
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Hook deposit / withdraw                        */
    /* ---------------------------------------------------------------------- */

    function _requireZapEligible() internal view {
        if (!IHook(Repo._layoutStruct().reserveHook).isZapEligible()) revert Repo.NotZapEligible();
    }

    function _depositSingle(address tokenIn_, uint256 amountIn_, address lpTo_)
        internal
        returns (uint256 lpOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        _requireZapEligible();
        IERC20(tokenIn_).forceApprove(s.reserveHook, amountIn_);
        lpOut_ = IHook(s.reserveHook).depositSingle(
            tokenIn_, amountIn_, lpTo_, 0, block.timestamp + 1, ""
        );
    }

    function _addLiquidity(
        uint256 pair0Amt_,
        uint256 pair1Amt_,
        uint256 detfAmt_,
        address lpTo_
    ) internal returns (uint256 shares_) {
        Repo.Storage storage s = Repo._layoutStruct();
        BindingAmounts memory b_ = _packBinding(pair0Amt_, pair1Amt_, detfAmt_);
        if (pair0Amt_ > 0) s.pairToken0.forceApprove(s.reserveHook, pair0Amt_);
        if (pair1Amt_ > 0) s.pairToken1.forceApprove(s.reserveHook, pair1Amt_);
        if (detfAmt_ > 0) IERC20(address(this)).forceApprove(s.reserveHook, detfAmt_);
        (shares_,,,) = IHook(s.reserveHook).addLiquidity(
            b_.a0, b_.a1, b_.a2, lpTo_, 0, block.timestamp + 1, ""
        );
    }

    function _removeLiquidity(uint256 shares_, address to_)
        internal
        returns (uint256 detfAmt_, uint256 pair0Amt_, uint256 pair1Amt_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20(s.reserveHook).forceApprove(s.reserveHook, shares_);
        (uint256 a0_, uint256 a1_, uint256 a2_) =
            IHook(s.reserveHook).removeLiquidity(shares_, to_, 0, 0, 0, block.timestamp + 1);
        (detfAmt_, pair0Amt_, pair1Amt_) = _unpackBinding(a0_, a1_, a2_);
    }

    /// @notice Redeposit DETF self-leg (burn/claim/maturity). Prefer depositSingle; multipath fallbacks.
    /// @dev When book is at MINIMUM_LIQUIDITY only, zap is ineligible and DETF-only multipath fails
    ///      FullBookRequiresThreeLegs. Callers that hold residual pair dust from the same remove
    ///      should use `_redepositDetfSelfLegWithPairDust` so DETF can rejoin with dust co-legs.
    function _redepositDetfSelfLeg(uint256 amountNative_) internal returns (uint256 lpOut_) {
        return _redepositDetfSelfLegWithPairDust(amountNative_, 0, 0);
    }

    /// @notice Redeposit DETF; optional pair dust enables multipath when zap-ineligible (sole-bond close).
    /// @return lpOut_ LP minted to protocol holder; pair dust consumed is not returned (caller subtracts).
    function _redepositDetfSelfLegWithPairDust(
        uint256 amountNative_,
        uint256 pair0Dust_,
        uint256 pair1Dust_
    ) internal returns (uint256 lpOut_) {
        if (amountNative_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        address holder_ = _protocolLpHolder();
        IHook hook_ = IHook(s.reserveHook);
        if (hook_.isZapEligible()) {
            IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
            lpOut_ = hook_.depositSingle(address(this), amountNative_, holder_, 0, block.timestamp + 1, "");
            return lpOut_;
        }
        // Multipath: DETF + optional pair dust (full-book when reserves still 3-positive after remove).
        BindingAmounts memory b_ = _packBinding(pair0Dust_, pair1Dust_, amountNative_);
        if (pair0Dust_ > 0) s.pairToken0.forceApprove(s.reserveHook, pair0Dust_);
        if (pair1Dust_ > 0) s.pairToken1.forceApprove(s.reserveHook, pair1Dust_);
        IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
        try hook_.addLiquidity(b_.a0, b_.a1, b_.a2, holder_, 0, block.timestamp + 1, "") returns (
            uint256 shares_, uint256, uint256, uint256
        ) {
            if (shares_ == 0) revert Repo.RedepositFailed();
            return shares_;
        } catch {
            // Last resort: DETF-only max (partial-book path when hook allows).
            BindingAmounts memory b2_ = _packBinding(0, 0, amountNative_);
            IERC20(address(this)).forceApprove(s.reserveHook, amountNative_);
            try hook_.addLiquidity(b2_.a0, b2_.a1, b2_.a2, holder_, 0, block.timestamp + 1, "") returns (
                uint256 shares2_, uint256, uint256, uint256
            ) {
                if (shares2_ == 0) revert Repo.RedepositFailed();
                return shares2_;
            } catch {
                revert Repo.RedepositFailed();
            }
        }
    }

    /// @notice Consolidate non-rate residual → tokenOut (sphere via hook SE).
    function _consolidateTo(address tokenOut_, uint256 pair0Amt_, uint256 pair1Amt_)
        internal
        returns (uint256 outAmt_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        address p0_ = address(s.pairToken0);
        address p1_ = address(s.pairToken1);
        if (tokenOut_ == p0_) {
            outAmt_ = pair0Amt_;
            if (pair1Amt_ > RESIDUAL_DUST) {
                outAmt_ += _sphereExactIn(p1_, p0_, pair1Amt_, address(this));
            }
        } else if (tokenOut_ == p1_) {
            outAmt_ = pair1Amt_;
            if (pair0Amt_ > RESIDUAL_DUST) {
                outAmt_ += _sphereExactIn(p0_, p1_, pair0Amt_, address(this));
            }
        } else {
            revert Repo.InvalidRoute(IERC20(p0_), IERC20(tokenOut_));
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol seigniorage compound                      */
    /* ---------------------------------------------------------------------- */

    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn_, uint256 lpOut_) {
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
        // Skip without revert when not zap-eligible (PRD Q6).
        if (!IHook(s.reserveHook).isZapEligible()) {
            return (0, 0);
        }
        try this.compoundProtocolRewardsAtomic() returns (uint256 d_, uint256 l_) {
            detfIn_ = d_;
            lpOut_ = l_;
            if (lpOut_ > 0) {
                emit IUniswapV4StandardExchangeOrbitalDETF.ProtocolRewardsCompounded(detfIn_, lpOut_);
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
        lpOut_ = _depositSingle(address(this), detfIn_, _protocolLpHolder());
        if (lpOut_ == 0) revert CompoundJoinProducedZeroLp();
        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reserveHook),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            s.detfNftId == 0 ? vault_.detfNFTId() : s.detfNftId,
            lpOut_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              Transfers                                 */
    /* ---------------------------------------------------------------------- */

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        if (pretransferred_) return amount_;
        uint256 before_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        actual_ = token_.balanceOf(address(this)) - before_;
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
        if (address(tokenIn_) == address(s.pairToken0) || address(tokenIn_) == address(s.pairToken1)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            return _rateTokenInToPairLeg(tokenIn_, pulled_);
        }
        uint256 pulled2_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        // SE share / SE vault token → pair via SE exchangeIn.
        if (address(s.standardExchange0) != address(0)) {
            if (
                address(tokenIn_) == address(s.vaultShare0)
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchange0))
            ) {
                tokenIn_.safeTransfer(address(s.standardExchange0), pulled2_);
                uint256 pairAmt_ = IStandardExchangeIn(address(s.standardExchange0)).exchangeIn(
                    tokenIn_, pulled2_, s.pairToken0, 0, address(this), true, deadline_
                );
                r_.fundedPairLeg = 0;
                r_.pairNotionalNative = pairAmt_;
                r_.pairNotionalWad = _toWad(pairAmt_, _pair0Decimals());
                return r_;
            }
        }
        if (address(s.standardExchange1) != address(0)) {
            if (
                address(tokenIn_) == address(s.vaultShare1)
                    || _tokenInSeTokens(tokenIn_, address(s.standardExchange1))
            ) {
                tokenIn_.safeTransfer(address(s.standardExchange1), pulled2_);
                uint256 pairAmt_ = IStandardExchangeIn(address(s.standardExchange1)).exchangeIn(
                    tokenIn_, pulled2_, s.pairToken1, 0, address(this), true, deadline_
                );
                r_.fundedPairLeg = 1;
                r_.pairNotionalNative = pairAmt_;
                r_.pairNotionalWad = _toWad(pairAmt_, _pair1Decimals());
                return r_;
            }
        }
        revert Repo.InvalidRoute(tokenIn_, s.rateAsset);
    }

    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(token_) == address(s.pairToken0) || address(token_) == address(s.pairToken1)) return true;
        if (address(token_) == address(s.vaultShare0) || address(token_) == address(s.vaultShare1)) return true;
        if (address(s.standardExchange0) != address(0) && _tokenInSeTokens(token_, address(s.standardExchange0))) {
            return true;
        }
        if (address(s.standardExchange1) != address(0) && _tokenInSeTokens(token_, address(s.standardExchange1))) {
            return true;
        }
        return false;
    }

    /// @notice Open-time sphere mid: convert pair notional → rateAsset WAD for effectiveShares (Q18).
    function _pairNotionalToRateAssetWad(uint8 leg_, uint256 pairNative_) internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        address pair_ = leg_ == 0 ? address(s.pairToken0) : address(s.pairToken1);
        address rate_ = address(s.rateAsset);
        if (pair_ == rate_) {
            return _toWad(pairNative_, _decimalsOf(pair_));
        }
        uint256 out_ = _previewSphereExactIn(pair_, rate_, pairNative_);
        return _toWad(out_, _decimalsOf(rate_));
    }

    function _mintBondFreeLegs(uint256 grossDetf_, address recipient_) internal {
        MintSplit memory split_ = _splitMintedDetf(grossDetf_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
        address bondVault_ = address(Repo._layoutStruct().bondNftVault);
        if (split_.inventoryDetf > 0 && bondVault_ != address(0)) {
            _mintDetf(bondVault_, split_.inventoryDetf);
        }
    }
}
