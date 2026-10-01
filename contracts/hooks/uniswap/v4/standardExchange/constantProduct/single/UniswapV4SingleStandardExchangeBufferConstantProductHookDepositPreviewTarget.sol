// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget
/// @notice CP deposit and join previews using the shared reserve accounting.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
{
    /// @notice CP previewJoinProportional entry point.
    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != 2) revert InvalidRoute();
        uint256 amt0 = l.currency0 == l.rawToken ? amounts[0] : amounts[1];
        uint256 amt1 = l.currency0 == l.rawToken ? amounts[1] : amounts[0];
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = IHook(address(this)).previewDeposit(amt0, amt1);
        usedAmounts = new uint256[](2);
        usedAmounts[0] = l.currency0 == l.rawToken ? used0 : used1;
        usedAmounts[1] = l.currency0 == l.rawToken ? used1 : used0;
    }

    /// @notice CP previewJoinUnbalanced entry point.
    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        external
        view
        returns (uint256 shares)
    {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (!_isLive() && (acc.raw == 0 || (acc.pair == 0 && acc.seShare == 0))) {
            return 0;
        }
        if (acc.seShare > 0) {
            (shares,,) = IHook(address(this)).previewDepositWithSeShares(acc.raw, acc.seShare);
            return shares;
        }
        Repo.Layout storage l = Repo._layout();
        uint256 amt0 = l.currency0 == l.rawToken ? acc.raw : acc.pair;
        uint256 amt1 = l.currency0 == l.rawToken ? acc.pair : acc.raw;
        if (amt0 == 0 || amt1 == 0) return 0;
        (shares,,) = IHook(address(this)).previewDeposit(amt0, amt1);
    }

    /// @notice CP previewJoinSingleAssetExactIn entry point.
    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn) external view returns (uint256 shares) {
        if (!_isLive() || amountIn == 0) return 0;
        return IHook(address(this)).previewDepositSingle(tokenIn, amountIn);
    }

    /// @notice CP previewJoinSingleAssetExactOut entry point.
    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256 amountIn)
    {
        if (!_isLive() || sharesOut == 0) return 0;
        return 0;
    }

    /// @notice CP previewDeposit entry point.
    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        if (amount0 == 0 || amount1 == 0) return (0, 0, 0);
        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            uint256 geometric = Math.mintSharesFirst(
                Math.toWad(_previewReserveAfterIntake(true, used0, used1), Repo._layout().decimalsCurrency0),
                Math.toWad(_previewReserveAfterIntake(false, used0, used1), Repo._layout().decimalsCurrency1)
            );
            if (geometric <= Repo.MINIMUM_LIQUIDITY) return (0, used0, used1);
            return (geometric - Repo.MINIMUM_LIQUIDITY, used0, used1);
        }
        (used0, used1) = _clampToReserveRatio(amount0, amount1);
        // D59: the clamp sizes the intake on the rated book; issuance follows the raw book.
        lpAmount = Math.mintSharesLater(
            _previewRawDelta(true, used0, used1), _previewRawDelta(false, used0, used1),
            _rawReserveCurrency0(), _rawReserveCurrency1(), _supplyAfterProtocolMint()
        );
    }

    /// @notice CP previewDepositSingle entry point.
    function previewDepositSingle(address tokenIn, uint256 amountIn) external view returns (uint256 lpAmount) {
        if (ClaimLib.supportsTransitionQuote(Repo._layout().standardExchange, Repo._layout().pairToken, address(this))) {
            return _previewSequentialDepositSingle(tokenIn, amountIn);
        }
        (uint256 saleAmt, uint256 otherOut, uint256 kept) = _previewZapSplit(tokenIn, amountIn);
        if (otherOut == 0 || kept == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 add0 = tokenIn == l.currency0 ? kept : otherOut;
        uint256 add1 = tokenIn == l.currency0 ? otherOut : kept;
        (uint256 used0, uint256 used1) = _clampToReserveRatio(add0, add1);
        // D59: issuance follows the raw book (raw token, SE shares).
        lpAmount = Math.mintSharesLater(
            _previewRawDelta(true, used0, used1), _previewRawDelta(false, used0, used1),
            _rawReserveCurrency0(), _rawReserveCurrency1(), _supplyAfterProtocolMint()
        );
        saleAmt;
        l;
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256 sharesOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken) revert InvalidRoute();
        LegLib.ExternalQuote memory externalQuote = LegLib.afterExternalDeposit(
            l.standardExchange, pairToken, tokenIn, amountIn, address(this)
        );
        uint256 claim = ClaimLib.ratedClaimOfState(l.standardExchange, externalQuote.state); // D60: state rate
        if (claim == 0 && externalQuote.heldShares > 0) claim = 1;
        uint256 supply = _supplyAfterProtocolMintForPairClaim(claim);
        ZapQuote memory q = _quoteShareZapStateAt(externalQuote.state, externalQuote.assets);
        (sharesOut,) = _finishDepositQuote(q, supply);
    }

    struct ZapQuote {
        bytes state;
        uint256 rawReserve;
        uint256 pairReserve;
        uint256 rawAdded;
        uint256 pairAdded;
    }

    function _previewSequentialDepositSingle(address tokenIn_, uint256 amountIn_) private view returns (uint256 minted_) {
        (, minted_,) = _quoteDepositSingleState(tokenIn_, amountIn_);
    }

    function _quoteDepositSingleState(address tokenIn_, uint256 amountIn_)
        private view returns (ZapQuote memory q, uint256 minted_, uint256 supply_)
    {
        q = _quoteZapState(tokenIn_, amountIn_);
        (minted_, supply_) = _finishDepositQuote(q, _supplyAfterProtocolMint());
    }

    function _finishDepositQuote(ZapQuote memory q, uint256 supply_)
        private view returns (uint256 minted_, uint256 finalSupply_)
    {
        if (q.rawAdded == 0 || q.pairAdded == 0) return (0, supply_);
        Repo.Layout storage l = Repo._layout();
        uint256 x_ = _poolOrderX(q.rawReserve, q.pairReserve);
        uint256 y_ = _poolOrderY(q.rawReserve, q.pairReserve);
        (uint256 used0_, uint256 used1_) = _clampToReserveRatioFrom(
            x_, y_, _poolOrderX(q.rawAdded, q.pairAdded), _poolOrderY(q.rawAdded, q.pairAdded)
        );
        uint256 claimAfter_;
        // D59: issuance follows the raw book; the SE share balance of the projected state before and after.
        uint256 sharesBefore_ = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(q.state);
        (q.state,,, claimAfter_) = _quoteMintablePairDeposit(
            q.state, l.currency0 == l.pairToken ? used0_ : used1_
        );
        if (claimAfter_ == 0) claimAfter_ = 1;
        uint256 sharesAfter_ = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(q.state);
        minted_ = _sharesAfterZap(q, sharesAfter_ - sharesBefore_, sharesBefore_, supply_);
        q.rawReserve += q.rawAdded;
        q.pairReserve = claimAfter_;
        q.pairAdded -= l.currency0 == l.pairToken ? used0_ : used1_;
        finalSupply_ = supply_ + minted_;
    }

    /// @dev D59: LP from the raw book (raw token, SE shares) of the projected state.
    function _sharesAfterZap(ZapQuote memory q, uint256 shareDelta, uint256 shareReserve, uint256 supply)
        private view returns (uint256)
    {
        return Math.mintSharesLater(
            _poolOrderX(q.rawAdded, shareDelta), _poolOrderY(q.rawAdded, shareDelta),
            _poolOrderX(q.rawReserve, shareReserve), _poolOrderY(q.rawReserve, shareReserve), supply
        );
    }

    function previewClaimAfterJoin(uint256 detfIn, uint256 lpAmount) external view returns (uint256 detfValue) {
        Repo.Layout storage l = Repo._layout();
        (ZapQuote memory q,, uint256 supply) = _quoteDepositSingleState(l.rawToken, detfIn);
        supply = _quoteClaimSupplyAfterDust(q, supply);
        if (lpAmount == 0 || supply == 0) return 0;
        uint256 rawOut = q.rawReserve * lpAmount / supply;
        uint256 seBalance = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(q.state);
        uint256 seOut = seBalance * lpAmount / supply;
        uint256 rawCap = q.rawReserve > Repo.MAX_DUST_WEI ? q.rawReserve - Repo.MAX_DUST_WEI : 0;
        uint256 seCap = seBalance > Repo.MAX_DUST_WEI ? seBalance - Repo.MAX_DUST_WEI : 0;
        detfValue = rawOut > rawCap ? rawCap : rawOut;
        if (seOut > seCap) seOut = seCap;
        if (seOut == 0) return detfValue;
        uint256 pairOut = IStandardExchangeTransitionQuote(l.standardExchange).quoteAssets(q.state, seOut);
        if (pairOut == 0) return detfValue;
        return detfValue + _quotePairToRawAfterJoin(q, pairOut);
    }

    function _quoteClaimSupplyAfterDust(ZapQuote memory q, uint256 supply) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 pairDust = IERC20(l.pairToken).balanceOf(address(this)) + q.pairAdded;
        if (pairDust <= Repo.MAX_DUST_WEI) return supply;
        uint256 beforePair = q.pairReserve;
        (q.state,,, q.pairReserve) = _quoteMintablePairDeposit(q.state, pairDust - Repo.MAX_DUST_WEI);
        // Deposit snapshots k before its final dust buffer. Exit valuation includes
        // the protocol LP that this final reserve growth can mint.
        (bool feeOn,, uint256 ownerFeeShare) = _feeOnAndShare();
        if (!feeOn) return supply;
        uint256 rawWad = Math.toWad(q.rawReserve, _decimalsOf(l.rawToken));
        return supply + Math.calculateProtocolFee(
            supply, rawWad * Math.toWad(q.pairReserve, _decimalsOf(l.pairToken)),
            rawWad * Math.toWad(beforePair, _decimalsOf(l.pairToken)), ownerFeeShare
        );
    }

    function _quotePairToRawAfterJoin(ZapQuote memory q, uint256 pairOut) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (,,, uint256 claimAfter) = _quoteMintablePairDeposit(q.state, pairOut);
        uint256 delta = claimAfter > q.pairReserve ? claimAfter - q.pairReserve : 0;
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(delta, _decimalsOf(l.pairToken)), Math.toWad(q.pairReserve, _decimalsOf(l.pairToken)),
            Math.toWad(q.rawReserve, _decimalsOf(l.rawToken))
        ), _decimalsOf(l.rawToken));
    }

    function _quoteMintablePairDeposit(bytes memory state, uint256 amountInRaw)
        private
        view
        returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 ratedHolderClaimAfter)
    {
        Repo.Layout storage l = Repo._layout();
        return ClaimLib.quoteMintableDepositExactIn(l.standardExchange, l.pairToken, state, amountInRaw);
    }

    function _quoteZapState(address tokenIn_, uint256 amountIn_) private view returns (ZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn_ == l.standardExchange) return _quoteShareZapState(amountIn_);
        (uint256 sold_, uint256 other_, uint256 kept_) = _previewZapSplit(tokenIn_, amountIn_);
        (q.state,) = IStandardExchangeTransitionQuote(l.standardExchange)
            .quoteState(l.pairToken, address(this));
        q.pairReserve = ClaimLib.ratedClaimOfState(l.standardExchange, q.state); // D60
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        if (tokenIn_ == l.rawToken) {
            uint256 budget_ = Math.fromWadFloor(Math.saleQuote(Math.toWad(sold_, _decimalsOf(l.rawToken)),
                Math.toWad(q.rawReserve, _decimalsOf(l.rawToken)), Math.toWad(q.pairReserve, _decimalsOf(l.pairToken))), _decimalsOf(l.pairToken));
            (q.state, other_, q.pairReserve) = _quoteZapUnwrap(q.state, budget_);
            q.rawReserve += sold_;
            q.rawAdded = kept_;
            q.pairAdded = other_;
        } else {
            (q.state,,, q.pairReserve) = _quoteMintablePairDeposit(q.state, sold_);
            q.rawReserve -= other_;
            q.rawAdded = other_;
            q.pairAdded = kept_;
        }
        // The spendable-share cap preserves a positive SE balance throughout a
        // live zap; mirror the execution book's one-unit minimum virtual reserve.
        if (q.pairReserve == 0) q.pairReserve = 1;
    }

    /// @dev Fee LP is minted before payment receipt by joinSingleAssetExactIn.
    /// The received SE shares are then unwrapped before the existing pair-side zap.
    function _quoteShareZapState(uint256 shares) private view returns (ZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        (bytes memory state,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteState(l.pairToken, address(this));
        return _quoteShareZapStateAt(state, shares);
    }

    function _quoteShareZapStateAt(bytes memory state, uint256 shares) private view returns (ZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(l.standardExchange);
        q.state = state;
        (q.state,,,) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares);
        uint256 amount;
        (q.state,, amount,) = quote.quoteTransition(
            q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, shares
        );
        q.pairReserve = ClaimLib.ratedClaimOfState(l.standardExchange, q.state); // D60
        if (q.pairReserve == 0) q.pairReserve = 1;
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        (,,, uint256 fullClaim) = _quoteMintablePairDeposit(q.state, amount);
        fullClaim = fullClaim > q.pairReserve ? fullClaim - q.pairReserve : 0;
        uint256 sold = _pairZapSaleAmount(amount, fullClaim, q.pairReserve);
        uint256 afterClaim;
        (q.state,,, afterClaim) = _quoteMintablePairDeposit(q.state, sold);
        uint256 claimIn = afterClaim > q.pairReserve ? afterClaim - q.pairReserve : 0;
        q.rawAdded = _pairZapRawOut(claimIn, q.pairReserve, q.rawReserve);
        q.rawReserve -= q.rawAdded;
        q.pairReserve = afterClaim == 0 ? 1 : afterClaim;
        q.pairAdded = amount - sold;
    }

    function _pairZapRawOut(uint256 claimIn, uint256 pairReserve, uint256 rawReserve)
        private view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 pairDecimals = _decimalsOf(l.pairToken);
        uint8 rawDecimals = _decimalsOf(l.rawToken);
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, pairDecimals), Math.toWad(pairReserve, pairDecimals),
            Math.toWad(rawReserve, rawDecimals)
        ), rawDecimals);
    }

    function _pairZapSaleAmount(uint256 amount, uint256 claim, uint256 reserve) private view returns (uint256 sold) {
        uint8 decimals = _decimalsOf(Repo._layout().pairToken);
        uint256 saleClaim = Math.fromWadFloor(
            Math.swapDepositSaleAmt(Math.toWad(claim, decimals), Math.toWad(reserve, decimals)), decimals
        );
        sold = claim == 0 ? amount / 2 : amount * saleClaim / claim;
        if (sold > amount) sold = amount;
        if (sold == 0 || sold >= amount) sold = amount / 2;
    }

    function _quoteZapUnwrap(bytes memory state_, uint256 budget_)
        private view returns (bytes memory next_, uint256 received_, uint256 claimAfter_)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 held_ = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(state_);
        uint256 amount_ = ClaimLib.sharesForPairUnitsDownAtState(budget_, state_);
        if (amount_ == 0) return (state_, 0, ClaimLib.ratedClaimOfState(l.standardExchange, state_));
        if (amount_ >= held_) revert InsufficientTokenOut();
        (next_,, received_,) = IStandardExchangeTransitionQuote(l.standardExchange)
            .quoteTransition(state_, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, amount_);
        if (received_ == 0) return (state_, 0, ClaimLib.ratedClaimOfState(l.standardExchange, state_));
        claimAfter_ = ClaimLib.ratedClaimOfState(l.standardExchange, next_); // D60
    }

    /// @notice CP previewZapSplit entry point.
    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        (amountToSwap, amountOtherOut, amountKeptIn) = _previewZapSplit(tokenIn, amountIn);
        if (tokenIn == Repo._layout().rawToken && ClaimLib.supportsTransitionQuote(
            Repo._layout().standardExchange, Repo._layout().pairToken, address(this)
        )) {
            ZapQuote memory q = _quoteZapState(tokenIn, amountIn);
            amountOtherOut = q.pairAdded;
        }
    }

    /// @notice CP previewDepositWithSeShares entry point.
    function previewDepositWithSeShares(uint256 amountRaw, uint256 amountSe)
        external
        view
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        // H2: leftover sweep may quote a single SE-share residual with 0 raw.
        if (amountRaw == 0 || amountSe == 0) return (0, 0, 0);
        uint256 claimOffered = _previewSeClaimOfBal(amountSe);
        if (claimOffered == 0) return (0, 0, 0);

        if (ERC20Repo._totalSupply() == 0) {
            usedRaw = amountRaw;
            usedSe = amountSe;
            lpAmount = _previewFirstMintSeShares(usedRaw, claimOffered);
            return (lpAmount, usedRaw, usedSe);
        }

        return _previewLaterMintSeShares(amountRaw, amountSe, claimOffered);
    }
}
