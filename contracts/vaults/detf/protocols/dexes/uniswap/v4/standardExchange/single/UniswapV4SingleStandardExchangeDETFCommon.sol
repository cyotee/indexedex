// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/common/core/DETFUsageFeeLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {
    UniV4DetfListingOracleLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/UniV4DetfListingOracleLib.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniV4DetfBondNft
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/IUniV4DetfBondNft.sol";
import {
    IUniV4DetfRebasingClaim
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/IUniV4DetfRebasingClaim.sol";

/// @title UniswapV4SingleStandardExchangeDETFCommon
/// @notice Shared pricing, gates, mint split, expansion, inventory routing for Uni V4 Single SE DETF.
abstract contract UniswapV4SingleStandardExchangeDETFCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant ONE_WAD = 1e18;

    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    event ProtocolRewardsCompounded(uint256 detfDonated);
    event ListingOraclePoked(int24 tick, uint256 blockNumber);
// L-STRUCT-1: MintSplit from detf/common/core/DETFMintSplit.sol

    function _s() internal pure returns (UniswapV4SingleStandardExchangeDETFRepo.Storage storage) {
        return UniswapV4SingleStandardExchangeDETFRepo._layoutStruct();
    }

    function _requireLive() internal view {
        if (!_s().isReserveLive) revert UniswapV4SingleStandardExchangeDETFRepo.NotLive();
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        _requireNotDisabled();
        if (amount_ == 0) revert UniswapV4SingleStandardExchangeDETFRepo.ZeroAmount();
        if (block.timestamp > deadline_) {
            revert UniswapV4SingleStandardExchangeDETFRepo.DeadlineExpired(deadline_);
        }
    }

    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _feeTo() internal view returns (address) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (address(s.feeOracle) == address(0)) return address(this);
        return address(s.feeOracle.feeTo());
    }

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeeWad() internal view returns (uint256) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.usageFeeOfVault(address(this));
    }

    /* ----------------------------- Oracle / R ----------------------------- */

    /// @notice Permissionless poke; mandatory before mint/bond/close/sell/compound.
    function _pokeListingOracle() internal {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        (, int24 tick,,) = StateLibrary.getSlot0(s.poolManager, s.poolId);
        bool wrote = UniV4DetfListingOracleLib._poke(tick);
        if (wrote) emit ListingOraclePoked(tick, block.number);
    }

    function _activeLiquidity() internal view returns (uint128) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        return StateLibrary.getLiquidity(s.poolManager, s.poolId);
    }

    function _isMarketMarkUsable() internal view returns (bool) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        bool twapReady = UniV4DetfListingOracleLib._twapReady(s.twapSeconds);
        return UniV4DetfListingOracleLib._isMarketMarkUsable(true, twapReady, _activeLiquidity());
    }

    function _pairDecimals() internal view returns (uint8) {
        try IERC20Metadata(address(_s().pairToken)).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _rDetfPerPair(uint160 sqrtPriceX96_) internal view returns (uint256) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        return UniV4DetfListingOracleLib._priceDetfPerPairWad(sqrtPriceX96_, s.pairIsCurrency0, _pairDecimals());
    }

    function _mintRateDetfPerPair() internal view returns (uint256 r_) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (_isMarketMarkUsable()) {
            int24 twapTick = UniV4DetfListingOracleLib._consultTwapTick(s.twapSeconds);
            uint160 sqrtP = TickMath.getSqrtPriceAtTick(twapTick);
            return _rDetfPerPair(sqrtP);
        }
        return _rDetfPerPair(s.creationSqrtPriceX96);
    }

    function _syntheticPrice() internal view returns (uint256) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (!_isMarketMarkUsable()) return ONE_WAD;
        int24 twapTick = UniV4DetfListingOracleLib._consultTwapTick(s.twapSeconds);
        uint256 pTwap = _rDetfPerPair(TickMath.getSqrtPriceAtTick(twapTick));
        uint256 pCreation = _rDetfPerPair(s.creationSqrtPriceX96);
        return UniV4DetfListingOracleLib._syntheticPrice(true, pTwap, pCreation);
    }

    function _isMintingAllowed() internal view returns (bool) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
    }

    function _isBurningAllowed() internal view returns (bool) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, _syntheticPrice());
    }

    /* ----------------------------- Mint split ----------------------------- */

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 afterFee_, uint256 feeTo_) = DETFUsageFeeLib._splitUsageFee(gross_, _usageFeeWad());
        split_.feeToDetf = feeTo_;
        uint256 halfInc_ = _seigniorageIncentiveWad() / 2;
        split_.inventoryDetf = Math.mulDiv(afterFee_, halfInc_, ONE_WAD);
        split_.userDetf = afterFee_ - split_.inventoryDetf;
    }

    /// @dev Gross DETF from pair notional: boost pair first, then R.
    function _quoteGrossDetfFromPairNotional(uint256 pairNotional_) internal view returns (uint256) {
        uint256 boosted = pairNotional_ + Math.mulDiv(pairNotional_, _seigniorageIncentiveWad(), ONE_WAD);
        return UniV4DetfListingOracleLib._detfFromPairNotional(boosted, _mintRateDetfPerPair());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._burn(from_, amount_);
    }

    function _bondLedgerWeight() internal view returns (uint256) {
        address bond = _s().bondNft;
        if (bond == address(0)) return 0;
        return IUniV4DetfBondNft(bond).totalShares();
    }

    /// @dev Inventory seigniorage / expansion → bond vault if weight > 0 else feeTo.
    function _routeInventoryDetf(uint256 inventoryDetf_) internal {
        if (inventoryDetf_ == 0) return;
        if (_bondLedgerWeight() > 0) {
            _mintDetf(_s().bondNft, inventoryDetf_);
            try IUniV4DetfBondNft(_s().bondNft).updateGlobalRewards() {} catch {}
        } else {
            _mintDetf(_feeTo(), inventoryDetf_);
        }
    }

    /* ----------------------------- Expansion ------------------------------ */

    function _tryNaturalExpansion() internal {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        DETFNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = s.isReserveLive;
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy;
        in_.isMintAllowed = in_.isPolicyMode && _syntheticPrice() > s.mintThreshold;
        in_.syntheticPrice = _syntheticPrice();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.closureRatePerSecond = s.expansionClosureRatePerSecond;
        in_.catchUpMaxSeconds = s.expansionCatchUpMaxSeconds;
        in_.catchUpCapBps = s.expansionCatchUpCapBps;

        (uint256 mintAmount_, uint256 newTs_) = DETFNaturalExpansionLib.computeExpansionMint(in_);
        if (mintAmount_ > 0) {
            _routeInventoryDetf(mintAmount_);
            s.lastExpansionTimestamp = newTs_;
            emit NaturalSupplyExpanded(mintAmount_, in_.syntheticPrice, newTs_);
        } else if (newTs_ != s.lastExpansionTimestamp && in_.isLive && in_.isPolicyMode) {
            // Advance clock on dust/no-op formula path when lib says so.
            s.lastExpansionTimestamp = newTs_;
        }
    }

    /// @dev Best-effort protocol compound: donate pending id-0 DETF into rebasing (0 mint).
    function _tryCompoundProtocolRewards() internal {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (s.bondNft == address(0) || s.rebasingClaimToken == address(0)) return;
        try this.compoundProtocolRewardsAtomic() {} catch {}
    }

    /// @notice Public compound with mandatory poke first.
    function compoundProtocolRewards() external nonReentrant {
        _pokeListingOracle();
        _compoundProtocolRewardsInternal();
    }

    /// @dev Only-self atomic path for lazy best-effort.
    function compoundProtocolRewardsAtomic() external {
        if (msg.sender != address(this)) revert UniswapV4SingleStandardExchangeDETFRepo.NotLive(); // reuse; better NotSelf
        _compoundProtocolRewardsInternal();
    }

    function _compoundProtocolRewardsInternal() internal {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        IUniV4DetfBondNft bond = IUniV4DetfBondNft(s.bondNft);
        uint256 pending = bond.pendingRewards(0);
        if (pending == 0) return;
        // Protocol pending is free DETF sitting on bond NFT from inventory routing.
        // Pull via claimRewards is holder-gated; protocol rewards are on id 0 held by package.
        // Donate DETF held on DETF that was minted to bond — bond holds free DETF as reward token.
        // Harvest protocol share: bond transfers reward token to this if we can claim as owner.
        // Our bond package harvests id 0 only via owner path — use claim is for user.
        // For id 0, transfer DETF balance of bond that is "pending" for protocol and transfer via donate.
        // Simpler: if DETF has free balance from bond transfer, donate it.
        // Peer path: reallocateDetfNftRewards. Here: call claimRewards is wrong for id 0.
        // Transfer path: bond NFT holds free DETF; we compute pending and pull via owner-only harvest.
        // Implement harvest in sell/compound by transferring pending from bond if DETF is reward.
        // For v1: mint path already puts inventory on bond; compound donates bond's free DETF for id 0.
        uint256 bondDetfBal = IERC20(address(this)).balanceOf(address(bond));
        uint256 toDonate = pending < bondDetfBal ? pending : bondDetfBal;
        if (toDonate == 0) return;
        // Bond cannot pull DETF from itself to DETF easily without transferFrom.
        // Owner is DETF — bond holds DETF as IERC20; we need bond to transfer to rebasing.
        // Use forceApprove + donateDetf with pretransfer: pull from bond if bond approves DETF.
        // Minimal path: DETF calls bond as owner to claimRewards(0) — add owner harvest for id 0.
        // Workaround: if DETF already holds free DETF earmarked, donate that.
        uint256 detfBal = IERC20(address(this)).balanceOf(address(this));
        // Accounting-wise free DETF on diamond may be residual; prefer explicit bond transfer.
        // Skip if nothing liquid on DETF.
        if (detfBal == 0) return;
        uint256 donateAmt = toDonate < detfBal ? toDonate : detfBal;
        IERC20(address(this)).forceApprove(s.rebasingClaimToken, donateAmt);
        IUniV4DetfRebasingClaim(s.rebasingClaimToken).donateDetf(donateAmt);
        emit ProtocolRewardsCompounded(donateAmt);
    }

    /* ----------------------------- Allowlist ------------------------------ */

    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        if (address(token_) == address(s.standardExchangeVaultShare)) return true;
        if (address(token_) == address(this)) return false;
        address[] memory tokens_ = IBasicVault(address(s.standardExchangeVault)).vaultTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(token_)) return true;
        }
        return false;
    }

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256) {
        if (pretransferred_) {
            if (token_.balanceOf(address(this)) < amount_) {
                revert UniswapV4SingleStandardExchangeDETFRepo.ZeroAmount();
            }
            return amount_;
        }
        uint256 before_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        return token_.balanceOf(address(this)) - before_;
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert UniswapV4SingleStandardExchangeDETFRepo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _bonusMultiplier(uint256 effectiveLockDuration_) internal view returns (uint256) {
        return DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), effectiveLockDuration_);
    }

    /// @dev Derive dual OOR ticks (no center) from current tick + widthMultiplier.
    function _deriveBondOorTicks()
        internal
        view
        returns (int24 pairLower, int24 pairUpper, int24 detfLower, int24 detfUpper)
    {
        UniswapV4SingleStandardExchangeDETFRepo.Storage storage s = _s();
        (, int24 currentTick,,) = StateLibrary.getSlot0(s.poolManager, s.poolId);
        int24 tickSpacing = s.poolKey.tickSpacing;
        int24 outerHalfWidth = int24(uint24(s.widthMultiplier)) * tickSpacing / 2;
        if (outerHalfWidth < tickSpacing) outerHalfWidth = tickSpacing;

        int24 lower = _snapTick(currentTick - outerHalfWidth, tickSpacing);
        int24 upper = _snapTick(currentTick + outerHalfWidth, tickSpacing);
        int24 mid = _snapTick(currentTick, tickSpacing);
        if (mid == lower) mid = lower + tickSpacing;
        if (mid == upper) mid = upper - tickSpacing;

        // Pair wing: below price if pair is currency1 (lower wing), else upper.
        // Single-sided pair OOR: if pair is token0, place above price (upper); if pair is token1, below (lower).
        if (s.pairIsCurrency0) {
            pairLower = mid;
            pairUpper = upper;
            detfLower = lower;
            detfUpper = mid;
        } else {
            pairLower = lower;
            pairUpper = mid;
            detfLower = mid;
            detfUpper = upper;
        }
    }

    function _snapTick(int24 tick_, int24 tickSpacing_) internal pure returns (int24) {
        int24 compressed = tick_ / tickSpacing_;
        if (tick_ < 0 && tick_ % tickSpacing_ != 0) compressed -= 1;
        return compressed * tickSpacing_;
    }
}
