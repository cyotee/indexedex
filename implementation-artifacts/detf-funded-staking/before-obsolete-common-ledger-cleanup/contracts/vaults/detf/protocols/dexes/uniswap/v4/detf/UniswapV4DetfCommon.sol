// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    IUniswapV4DetfSelfCall
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4DetfSelfCall.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IUniswapV4SeBufferHookClaimExitQuote} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimTokenSupply} from "contracts/interfaces/IRebasingClaimToken.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {DETFThresholdPolicy, ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {DETF_CREATOR_BOND_NFT_ID, DETF_FEE_TO_BOND_NFT_ID} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {DETFDecimalScaleLib} from "contracts/vaults/detf/common/core/DETFDecimalScaleLib.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";

/// @title UniswapV4DetfCommon
/// @notice Shared gates, quotes, pull, sweep, expansion, compound. Opaque hook ABI only.
abstract contract UniswapV4DetfCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    uint256 internal constant ONE_WAD = 1e18;


    function _requireReserveLive() internal view {
        if (!Repo._layoutStruct().isReserveLive) revert Repo.ReserveNotLive();
    }

    function _requireReserveWired() internal view {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || address(s.rebasingClaimToken) == address(0)) {
            revert Repo.ReserveNotWired();
        }
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert Repo.ZeroAmount();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
    }

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

    function _requireBondNft() internal view {
        if (msg.sender != address(Repo._layoutStruct().bondNftVault)) {
            revert Repo.NotAuthorized(msg.sender);
        }
    }

    function _hook() internal view returns (IUniswapV4SeBufferHook) {
        return IUniswapV4SeBufferHook(Repo._layoutStruct().hook);
    }

    function _quote() internal view returns (IDetfReserveQuote) {
        return IDetfReserveQuote(Repo._layoutStruct().hook);
    }

    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    function _protocolLp() internal view returns (uint256) {
        IERC20 lp_ = IERC20(Repo._layoutStruct().hook);
        address holder_ = _bondLpHolder();
        uint256 held_ = lp_.balanceOf(address(this));
        return holder_ == address(this) ? held_ : held_ + lp_.balanceOf(holder_);
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert Repo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

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
    }

    function _splitBondDetf(uint256 purchasedGross_, uint256 joinDetf_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = purchasedGross_;
        (uint256 user_, uint256 pot_,) =
            DETFMintSplitLib._splitBond(purchasedGross_, joinDetf_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ == 0) return;
        ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        if (amount_ == 0) return;
        ERC20Repo._burn(from_, amount_);
    }

    function _hookPairOfVault(IStandardExchange vault_) internal view returns (address pair_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] storage pairs_ = s.hookPairTokens._values();
        for (uint256 i; i < pairs_.length; ++i) {
            if (
                address(s.mintTable.vaultOf[pairs_[i]]) == address(vault_)
                    || IUniswapV4SeBufferHook(s.hook).standardExchangeOf(pairs_[i]) == address(vault_)
            ) {
                return pairs_[i];
            }
        }
        revert Repo.InvalidRoute(address(vault_), address(this));
    }

    function _pairEq(IStandardExchange vault_, IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        returns (uint256 pairEq_)
    {
        address share_ = address(vault_);
        address pair_ = _hookPairOfVault(vault_);
        if (address(tokenIn_) == pair_) return amountIn_;
        if (address(tokenIn_) == share_) {
            try vault_.previewExchangeIn(tokenIn_, amountIn_, IERC20(pair_)) returns (uint256 out_) {
                return out_;
            } catch {
                revert Repo.InvalidRoute(address(tokenIn_), pair_);
            }
        }
        try vault_.previewExchangeIn(tokenIn_, amountIn_, IERC20(pair_)) returns (uint256 out_) {
            if (out_ == 0) revert Repo.InvalidRoute(address(tokenIn_), pair_);
            return out_;
        } catch {
            revert Repo.InvalidRoute(address(tokenIn_), pair_);
        }
    }

    function _quoteCtx(address pair_, bool previewSettlement_)
        internal view returns (IDetfReserveQuote.DetfQuoteCtx memory ctx_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 creation_ = s.creationOfPair[pair_];
        uint256 supply_ = ERC20Repo._totalSupply();
        if (previewSettlement_) supply_ += _pendingExpansionDetf();
        ctx_ = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: supply_ * 1e9,
            pendingExpansion: 0,
            ownedLp: _protocolLp(),
            creationPairPerDetfWad: creation_
        });
    }

    function _syntheticOfPair(address pair_) internal view returns (uint256 wad_) {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        wad_ = _quote().previewSynthetic(_quoteCtx(pair_, false), pair_);
    }

    function _mintPriceGate(address pair_, bool previewSettlement_) internal view returns (bool) {
        uint256 price_ = _quote().previewSynthetic(_quoteCtx(pair_, previewSettlement_), pair_);
        return DETFThresholdPolicy._isMintingAllowed(Repo._layoutStruct().mintThreshold, price_);
    }

    function _burnPriceGate(address pair_, bool previewSettlement_) internal view returns (bool) {
        uint256 price_ = _quote().previewSynthetic(_quoteCtx(pair_, previewSettlement_), pair_);
        return DETFThresholdPolicy._isBurningAllowed(Repo._layoutStruct().burnThreshold, price_);
    }

    function _syntheticPrice() internal view returns (uint256 wad_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] storage pairs_ = s.hookPairTokens._values();
        if (pairs_.length == 0) return 0;
        return _syntheticOfPair(pairs_[0]);
    }

    function _isMintingAllowedToken(IERC20 tokenIn_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        if (!s.mintTable.tokens._contains(address(tokenIn_))) return false;
        IStandardExchange v_ = s.mintTable.vaultOf[address(tokenIn_)];
        address pair_ = _hookPairOfVault(v_);
        return _mintPriceGate(pair_, false);
    }

    function _isBurningAllowedToken(IERC20 tokenOut_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        if (!s.burnTable.tokens._contains(address(tokenOut_))) return false;
        IStandardExchange v_ = s.burnTable.vaultOf[address(tokenOut_)];
        address pair_ = _hookPairOfVault(v_);
        return _burnPriceGate(pair_, false);
    }

    function _isMintingAllowedAny() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        address[] storage toks_ = s.mintTable.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            if (_isMintingAllowedToken(IERC20(toks_[i]))) return true;
        }
        return false;
    }

    function _isBurningAllowedAny() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        address[] storage toks_ = s.burnTable.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            if (_isBurningAllowedToken(IERC20(toks_[i]))) return true;
        }
        return false;
    }

    function _quoteMintGross(address pair_, uint256 pairEq_) internal view returns (uint256 gross_) {
        uint256 p_ = _seigniorageIncentiveWad();
        uint256 boosted_ = Math.mulDiv(pairEq_, ONE_WAD + p_, ONE_WAD);
        gross_ = _hook().previewSwapExactIn(pair_, address(this), boosted_);
    }

    /// @dev Initial configured human price is linear; native DETF has nine decimals.
    function _openingBondQuote(address pair_, uint256 pairEq_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 opening_ = s_.openingOfPair[pair_];
        if (opening_ == 0) opening_ = s_.creationOfPair[pair_];
        return Math.mulDiv(DETFDecimalScaleLib.nativeToWad(pair_, pairEq_), 1e9, opening_);
    }

    /// @dev The liquidity self-leg is sized from the actual unboosted payment.
    function _quoteBondG(address pair_, uint256 pairEq_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.isReserveLive || !_hook().isLive()) return _openingBondQuote(pair_, pairEq_);
        uint256 supply_ = IERC20(s_.hook).totalSupply();
        if (supply_ == 0) return _openingBondQuote(pair_, pairEq_);
        uint256[] memory amounts_ = _hook().previewExitProportional(supply_);
        address[] memory tokens_ = _hook().tokens();
        uint256 reserveDetf_;
        uint256 reservePair_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(this)) reserveDetf_ = amounts_[i];
            if (tokens_[i] == pair_) reservePair_ = amounts_[i];
        }
        if (reserveDetf_ == 0 || reservePair_ == 0) return _openingBondQuote(pair_, pairEq_);
        return Math.mulDiv(reserveDetf_, pairEq_, reservePair_);
    }

    /// @dev Duration buys more principal once, without stacking ordinary mint's 1+p uplift.
    function _quoteBondPurchase(address pair_, uint256 pairEq_, uint256 duration_) internal view returns (uint256) {
        uint256 multiplier_ = DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), duration_);
        uint256 boosted_ = Math.mulDiv(pairEq_, multiplier_, ONE_WAD);
        if (!Repo._layoutStruct().isReserveLive) return _openingBondQuote(pair_, boosted_);
        return _hook().previewSwapExactIn(pair_, address(this), boosted_);
    }

    /// @dev Price each distinct non-DETF entitlement against the same pre-payment reserve book.
    /// The hook's proportional preview includes buffered SE assets and its fee dilution once.
    /// No LP is withdrawn, no DETF self-leg is sold, and no matching liquidity DETF is issued.
    function _quoteReserveLpBond(uint256 lpAmount_, uint256 duration_) internal view returns (uint256 gross_) {
        _requireReserveLive();
        address[] memory tokens_ = _hook().tokens();
        uint256[] memory amounts_ = _hook().previewExitProportional(lpAmount_);
        if (amounts_.length != tokens_.length) revert Repo.InvalidRoute(Repo._layoutStruct().hook, address(this));
        if (lpAmount_ > IERC20(Repo._layoutStruct().hook).totalSupply()) revert Repo.ZeroAmount();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] != address(this) && amounts_[i_] != 0) {
                gross_ += _quoteBondPurchase(tokens_[i_], amounts_[i_], duration_);
            }
        }
    }

    function _pendingExpansionDetf() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        DETFEpochNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = s.isReserveLive;
        in_.spotSyntheticPrice = _syntheticPriceView();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.expansionClosureRatePerYearWad = s.expansionClosureRatePerYearWad;
        return DETFEpochNaturalExpansionLib.previewPendingExpansionMint(in_);
    }

    function _syntheticPriceView() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return 0;
        address[] storage pairs_ = s.hookPairTokens._values();
        if (pairs_.length == 0) return 0;
        IDetfReserveQuote.DetfQuoteCtx memory ctx_ = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: ERC20Repo._totalSupply() * 1e9,
            pendingExpansion: 0,
            ownedLp: _protocolLp(),
            creationPairPerDetfWad: s.creationPairPerDetfWad.length == 0 ? ONE_WAD : s.creationPairPerDetfWad[0]
        });
        return _quote().previewSynthetic(ctx_, pairs_[0]);
    }

    function _realizeExpansionIfNeeded() internal returns (uint256 mintAmount_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return 0;
        DETFEpochNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = true;
        in_.spotSyntheticPrice = _syntheticPriceView();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.expansionClosureRatePerYearWad = s.expansionClosureRatePerYearWad;
        uint256 newTs_;
        (mintAmount_, newTs_) = DETFEpochNaturalExpansionLib.computeRealization(in_);
        if (newTs_ != s.lastExpansionTimestamp) {
            s.lastExpansionTimestamp = newTs_;
        }
        if (mintAmount_ > 0) {
            _fundStakingRewards(mintAmount_);
            emit IUniswapV4Detf.NaturalSupplyExpanded(mintAmount_, in_.spotSyntheticPrice, newTs_);
        }
    }

    /// @dev Expansion and issuance seigniorage are separate actual DETF funding transfers.
    function _fundStakingRewards(uint256 amount_) internal {
        if (amount_ == 0) return;
        address staking_ = address(Repo._layoutStruct().rebasingClaimToken);
        _mintDetf(address(this), amount_);
        IERC20(address(this)).forceApprove(staking_, amount_);
        IStakedDETF(staking_).fundRewards(amount_);
        IERC20(address(this)).forceApprove(staking_, 0);
    }

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
        uint256 B0 = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            return token_.balanceOf(address(this)) - B0;
        }
        uint256 U = B0 > R ? B0 - R : 0;
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

    function _nestedExchangeIn(
        IStandardExchangeIn host_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (amountIn_ == 0) return 0;
        // Use the standard approval-based route, including SEs whose own-share
        // redemption burns the caller's balance. Authorize only this payment.
        tokenIn_.forceApprove(address(host_), amountIn_);
        amountOut_ = host_.exchangeIn(tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, false, deadline_);
        tokenIn_.forceApprove(address(host_), 0);
    }

    function _toShare(IStandardExchange vault_, IERC20 tokenIn_, uint256 amountIn_, uint256 deadline_)
        internal
        returns (uint256 shareOut_)
    {
        address share_ = address(vault_);
        if (address(tokenIn_) == share_) return amountIn_;
        shareOut_ = _nestedExchangeIn(
            IStandardExchangeIn(share_), tokenIn_, amountIn_, IERC20(share_), 0, address(this), deadline_
        );
        if (shareOut_ == 0) revert Repo.InvalidRoute(address(tokenIn_), share_);
    }

    function _joinShare(uint256 shareAmount_, address shareToken_) internal returns (uint256 lpOut_) {
        if (shareAmount_ == 0) return 0;
        IERC20(shareToken_).forceApprove(Repo._layoutStruct().hook, shareAmount_);
        lpOut_ = _hook().joinSingleAssetExactIn(shareToken_, shareAmount_, _bondLpHolder(), 0, block.timestamp + 1);
        IERC20(shareToken_).forceApprove(Repo._layoutStruct().hook, 0);
    }

    function _joinUnbalanced(address[] memory tokens_, uint256[] memory amounts_) internal returns (uint256 lpOut_) {
        address hook_ = Repo._layoutStruct().hook;
        for (uint256 i; i < tokens_.length; ++i) {
            if (amounts_[i] > 0) {
                IERC20(tokens_[i]).forceApprove(hook_, amounts_[i]);
            }
        }
        lpOut_ =
            IUniswapV4SeBufferHook(hook_).joinUnbalanced(tokens_, amounts_, _bondLpHolder(), 0, block.timestamp + 1);
        for (uint256 j; j < tokens_.length; ++j) {
            IERC20(tokens_[j]).forceApprove(hook_, 0);
        }
    }

    function _pullNftLp(uint256 lpAmount_) internal {
        if (lpAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.hook);
        uint256 have_ = lp_.balanceOf(address(this));
        if (have_ >= lpAmount_) return;
        uint256 need_ = lpAmount_ - have_;
        s.bondNftVault.transferHeldToken(lp_, address(this), need_);
    }

    function _returnLeftoverLp() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.hook);
        uint256 bal_ = lp_.balanceOf(address(this));
        if (bal_ == 0 || address(s.bondNftVault) == address(0)) return;
        lp_.safeTransfer(address(s.bondNftVault), bal_);
    }

    function _trySweepDust() internal {
        try IUniswapV4DetfSelfCall(address(this)).sweepDustAtomic() {} catch {}
    }

    function _entrySweepDustAtomic() internal {
        if (msg.sender != address(this)) revert Repo.NotAuthorized(msg.sender);
        _sweepDustBody();
    }

    function _sweepDustBody() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        address hookAddr_ = s.hook;
        if (hookAddr_ == address(0)) return;
        IERC20 lp_ = IERC20(hookAddr_);
        uint256 lpBal_ = lp_.balanceOf(address(this));
        if (lpBal_ > 0 && address(s.bondNftVault) != address(0)) {
            lp_.safeTransfer(address(s.bondNftVault), lpBal_);

        }
        if (!s.isReserveLive) return;
        address[] memory tokens_ = IUniswapV4SeBufferHook(hookAddr_).tokens();
        address[] storage ses_ = s.hookStandardExchanges._values();
        // Later residual joins can refund an earlier-cleared pair via conservation.
        // Repeat until diamond leftovers are dust or the round makes no progress.
        for (uint256 round_; round_ < 8; ++round_) {
            uint256 dirty_;
            for (uint256 i; i < tokens_.length; ++i) {
                uint256 before_ = IERC20(tokens_[i]).balanceOf(address(this));
                _tryJoinResidual(tokens_[i]);
                if (IERC20(tokens_[i]).balanceOf(address(this)) > 10) dirty_ = 1;
                if (IERC20(tokens_[i]).balanceOf(address(this)) + 10 < before_) dirty_ = 1;
            }
            for (uint256 j; j < ses_.length; ++j) {
                uint256 beforeSe_ = IERC20(ses_[j]).balanceOf(address(this));
                _tryJoinResidual(ses_[j]);
                if (IERC20(ses_[j]).balanceOf(address(this)) > 10) dirty_ = 1;
                if (IERC20(ses_[j]).balanceOf(address(this)) + 10 < beforeSe_) dirty_ = 1;
            }
            if (dirty_ == 0) break;
        }
    }

    function _tryJoinResidual(address token_) internal {
        uint256 bal_ = IERC20(token_).balanceOf(address(this));
        if (bal_ == 0) return;

        Repo.Storage storage s = Repo._layoutStruct();
        bool isSe_ = s.hookStandardExchanges._contains(token_);
        // Book residual capital directly before a ratio zap can create new refunds.
        // DETF and SE shares use the same partial-add path.
        _joinResidualUnbalanced(token_, bal_);
        uint256 leftover_ = IERC20(token_).balanceOf(address(this));
        if (leftover_ > 10 && !isSe_ && token_ != address(this)) {
            _joinResidualCapped(token_, leftover_);
        }

        if (token_ == address(this)) {
            return;
        }
        leftover_ = IERC20(token_).balanceOf(address(this));
        if (leftover_ <= 10) return;
        // Last-resort only: tiny unjoinable remainder. Do not park large SE
        // (donates book without LP and can fail later burns).
        if (s.hookPairTokens._contains(token_)) {
            _wrapAndParkPair(token_);
        } else if (isSe_) {
            _parkResidualOnHook(token_);
        }
    }

    /// @dev Orbital leftover can MathDomain on a 3-leg zap of the full residual.
    ///      Halve and retry so R19 still clears.
    function _joinResidualCapped(address token_, uint256 amount_) internal {
        if (amount_ == 0) return;
        address hook_ = Repo._layoutStruct().hook;
        uint256 amt_ = amount_;
        for (uint256 i; i < 24 && amt_ > 10; ++i) {
            uint256 before_ = IERC20(token_).balanceOf(address(this));
            if (amt_ > before_) amt_ = before_;
            if (amt_ <= 10) break;
            IERC20(token_).forceApprove(hook_, amt_);
            try _hook().joinSingleAssetExactIn(token_, amt_, _bondLpHolder(), 0, block.timestamp + 1) returns (
                uint256 lpOut_
            ) {
                IERC20(token_).forceApprove(hook_, 0);

                uint256 after_ = IERC20(token_).balanceOf(address(this));
                if (lpOut_ == 0 || after_ + 10 >= before_) {
                    amt_ = amt_ / 2;
                } else {
                    amt_ = after_;
                }
            } catch {
                IERC20(token_).forceApprove(hook_, 0);
                amt_ = amt_ / 2;
            }
        }
        IERC20(token_).forceApprove(hook_, 0);
    }

    function _joinResidualUnbalanced(address token_, uint256 amount_) internal {
        if (amount_ <= 10) return;
        address hook_ = Repo._layoutStruct().hook;
        address[] memory tokensIn_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokensIn_[0] = token_;
        uint256 amt_ = amount_;
        for (uint256 i; i < 24 && amt_ > 10; ++i) {
            uint256 before_ = IERC20(token_).balanceOf(address(this));
            if (amt_ > before_) amt_ = before_;
            if (amt_ <= 10) break;
            amounts_[0] = amt_;
            IERC20(token_).forceApprove(hook_, amt_);
            try _hook().joinUnbalanced(tokensIn_, amounts_, _bondLpHolder(), 0, block.timestamp + 1) returns (
                uint256 lpOut_
            ) {
                IERC20(token_).forceApprove(hook_, 0);

                uint256 after_ = IERC20(token_).balanceOf(address(this));
                if (lpOut_ == 0 || after_ + 10 >= before_) {
                    amt_ = amt_ / 2;
                } else {
                    amt_ = after_;
                }
            } catch {
                IERC20(token_).forceApprove(hook_, 0);
                amt_ = amt_ / 2;
            }
        }
        IERC20(token_).forceApprove(hook_, 0);
    }

    function _parkResidualOnHook(address token_) internal {
        uint256 left_ = IERC20(token_).balanceOf(address(this));
        if (left_ <= 10) return;
        IERC20(token_).safeTransfer(Repo._layoutStruct().hook, left_ - 10);
    }

    function _wrapAndParkPair(address pair_) internal {
        Repo.Storage storage s = Repo._layoutStruct();
        address se_ = IUniswapV4SeBufferHook(s.hook).standardExchangeOf(pair_);
        if (se_ == address(0)) return;
        uint256 amt_ = IERC20(pair_).balanceOf(address(this));
        if (amt_ > 10) amt_ -= 10;
        for (uint256 i; i < 16 && amt_ > 0; ++i) {
            uint256 before_ = IERC20(pair_).balanceOf(address(this));
            if (amt_ + 10 > before_) amt_ = before_ > 10 ? before_ - 10 : 0;
            if (amt_ == 0) break;
            try IUniswapV4DetfSelfCall(address(this)).sweepPairToShare(se_, pair_, amt_) returns (uint256) {
                uint256 seBal_ = IERC20(se_).balanceOf(address(this));
                if (seBal_ > 10) IERC20(se_).safeTransfer(s.hook, seBal_ - 10);
                uint256 after_ = IERC20(pair_).balanceOf(address(this));
                if (after_ + 10 >= before_) amt_ = amt_ / 2;
                else amt_ = after_ > 10 ? after_ - 10 : 0;
            } catch {
                amt_ = amt_ / 2;
            }
        }
        _parkResidualOnHook(se_);
    }

    function _entrySweepPairToShare(address se_, address pair_, uint256 amount_) internal returns (uint256 shares_) {
        if (msg.sender != address(this)) revert Repo.NotAuthorized(msg.sender);
        IERC20(pair_).forceApprove(se_, amount_);
        shares_ = IStandardExchangeIn(se_)
            .exchangeIn(IERC20(pair_), amount_, IERC20(se_), 0, address(this), false, block.timestamp + 1);
        IERC20(pair_).forceApprove(se_, 0);
    }
}
