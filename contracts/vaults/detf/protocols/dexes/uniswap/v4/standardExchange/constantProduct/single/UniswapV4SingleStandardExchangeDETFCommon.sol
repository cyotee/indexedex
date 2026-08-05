// SPDX-License-Identifier: BUSL-1.1
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
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @title UniswapV4SingleStandardExchangeDETFCommon
/// @notice Shared pricing, gates, mint split, hook LP helpers, epoch expansion, compound.
abstract contract UniswapV4SingleStandardExchangeDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant ONE_WAD = 1e18;

    error NotSelf();
    error CompoundJoinProducedZeroLp();

    struct MintSplit {
        uint256 grossDetf;
        uint256 userDetf;
        uint256 feeToDetf;
        uint256 inventoryDetf;
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

    /// @notice Protocol LP holder per PRD LOCK: rebasing claim package when wired; else diamond.
    function _protocolLpHolder() internal view returns (address) {
        address claim_ = address(Repo._layoutStruct().rebasingClaimToken);
        return claim_ == address(0) ? address(this) : claim_;
    }

    /// @notice Bond NFT package holds user open-bond reserve LP (PRD LOCK).
    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    /// @notice Protocol-owned hook LP (physical balance of protocol holder).
    function _protocolLp() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        return IERC20(s.reserveHook).balanceOf(_protocolLpHolder());
    }

    /// @notice Pull protocol LP onto this diamond before hook withdraw (burn / claim unwind).
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

    /// @notice Pull LP from bond NFT (maturity close via claimLiquidity).
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

    function _ensureProtocolLpAvailable(uint256 lpAmount_) internal view {
        if (lpAmount_ > _protocolLp()) revert Repo.EmptyProtocolLp();
    }

    /// @dev Back-compat name used by burn path.
    function _ensureProtocolLpOnDiamond(uint256 lpAmount_) internal {
        _ensureProtocolLpAvailable(lpAmount_);
        _pullProtocolLp(lpAmount_);
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
        // inventory = afterFee * (incentive/2) / 1e18
        split_.inventoryDetf = Math.mulDiv(afterFee_, halfInc_, ONE_WAD);
        split_.userDetf = afterFee_ - split_.inventoryDetf;
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

        // Join protocol LP onto claim holder when wired (else diamond).
        lpOut_ = _depositSingleDetf(detfIn_, _protocolLpHolder());
        if (lpOut_ == 0) revert CompoundJoinProducedZeroLp();

        // Credit protocol NFT principal accounting (share units = LP amount).
        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(s.reserveHook),
            IDetfSelfNftInventoryPolicy(address(vault_)),
            s.detfNftId == 0 ? vault_.detfNFTId() : s.detfNftId,
            lpOut_
        );
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
            tokenIn_.safeTransfer(address(s.standardExchangeVault), pulled_);
            pairAmount_ = IStandardExchangeIn(address(s.standardExchangeVault)).exchangeIn(
                tokenIn_, pulled_, s.pairToken, 0, address(this), true, deadline_
            );
            return pairAmount_;
        }
        revert Repo.InvalidRoute(tokenIn_, s.pairToken);
    }
}
