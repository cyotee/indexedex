// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase as QuoteBase, ISingleBufferQuoteErrors} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib
 * @notice D78 claim-in / invert for pair-side buffer composition (ERC-4626 SE peer).
 * @dev D60: the pair leg of the swap invariant is SE shares x the configured rate provider
 *      (WAD whole pair tokens per whole share). The hook never derives a rate from the SE's
 *      own quotes; SE quotes are used only to count shares minted or pair paid out.
 *      External library: DELEGATECALL keeps `Repo._layout()` on the hook diamond.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib {
    using SafeERC20 for IERC20;

    function singleZapState(address tokenIn, uint256 sold, uint256 other, uint256 kept)
        external view returns (QuoteBase.SingleZapQuote memory q)
    {
        Repo.Layout storage l = Repo._layout();
        (q.state,) = Transition(l.standardExchange).quoteState(l.pairToken, address(this));
        q.pairReserve = ratedClaimOfState(l.standardExchange, q.state);
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        if (tokenIn == l.rawToken) {
            uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(sold, singleDecimals(l.rawToken)),
                Math.toWad(q.rawReserve, singleDecimals(l.rawToken)), Math.toWad(q.pairReserve, singleDecimals(l.pairToken))), singleDecimals(l.pairToken));
            (q.state, other, q.pairReserve) = _singleZapUnwrap(q.state, budget);
            q.rawReserve += sold;
            q.rawAdded = kept;
            q.pairAdded = other;
        } else {
            uint256 minted;
            (q.state,, minted, q.pairReserve) = _singleMintableDeposit(q.state, sold);
            if (minted == 0) return q;
            q.rawReserve -= other;
            q.rawAdded = other;
            q.pairAdded = kept;
        }
        if (q.pairReserve == 0) q.pairReserve = 1;
    }

    function singleShareZapState(bytes memory state, uint256 shares) external view returns (QuoteBase.SingleZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        Transition quote = Transition(l.standardExchange);
        q.state = state;
        (q.state,,,) = quote.quoteTransition(q.state, Transition.Operation.ReceiveShares, shares);
        uint256 amount;
        (q.state,, amount,) = quote.quoteTransition(q.state, Transition.Operation.RedeemExactIn, shares);
        q.pairReserve = ratedClaimOfState(l.standardExchange, q.state);
        if (q.pairReserve == 0) q.pairReserve = 1;
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        (,,, uint256 fullClaim) = _singleMintableDeposit(q.state, amount);
        fullClaim = fullClaim > q.pairReserve ? fullClaim - q.pairReserve : 0;
        uint256 sold = _singlePairZapSale(amount, fullClaim, q.pairReserve);
        uint256 afterClaim;
        (q.state,,, afterClaim) = _singleMintableDeposit(q.state, sold);
        uint256 claimIn = afterClaim > q.pairReserve ? afterClaim - q.pairReserve : 0;
        q.rawAdded = singlePairRawOut(claimIn, q.pairReserve, q.rawReserve);
        q.rawReserve -= q.rawAdded;
        q.pairReserve = afterClaim == 0 ? 1 : afterClaim;
        q.pairAdded = amount - sold;
    }

    /// @dev Return the mutated projection because external library calls copy memory arguments.
    function singleFinishDeposit(QuoteBase.SingleZapQuote memory q, uint256 supply)
        external view returns (QuoteBase.SingleZapQuote memory updated, uint256 minted, uint256 finalSupply)
    {
        if (q.rawAdded == 0 || q.pairAdded == 0) return (q, 0, supply);
        Repo.Layout storage l = Repo._layout();
        (uint256 used0, uint256 used1) = singleClamp(
            singleOrderX(q.rawReserve, q.pairReserve), singleOrderY(q.rawReserve, q.pairReserve),
            singleOrderX(q.rawAdded, q.pairAdded), singleOrderY(q.rawAdded, q.pairAdded)
        );
        uint256 claimAfter;
        uint256 sharesBefore = Transition(l.standardExchange).quoteShareBalance(q.state);
        (q.state,,, claimAfter) = _singleMintableDeposit(q.state, l.currency0 == l.pairToken ? used0 : used1);
        if (claimAfter == 0) claimAfter = 1;
        uint256 sharesAfter = Transition(l.standardExchange).quoteShareBalance(q.state);
        minted = _singleSharesAfterZap(q, sharesAfter - sharesBefore, sharesBefore, supply);
        q.rawReserve += q.rawAdded;
        q.pairReserve = claimAfter;
        q.pairAdded -= l.currency0 == l.pairToken ? used0 : used1;
        finalSupply = supply + minted;
        updated = q;
    }

    function _singleSharesAfterZap(QuoteBase.SingleZapQuote memory q, uint256 delta, uint256 reserve, uint256 supply)
        private view returns (uint256)
    {
        return Math.mintSharesLater(singleOrderX(q.rawAdded, delta), singleOrderY(q.rawAdded, delta),
            singleOrderX(q.rawReserve, reserve), singleOrderY(q.rawReserve, reserve), supply);
    }

    function _singleMintableDeposit(bytes memory state, uint256 amount) private view returns (bytes memory, uint256, uint256, uint256) {
        Repo.Layout storage l = Repo._layout();
        return quoteMintableDepositExactIn(l.standardExchange, l.pairToken, state, amount);
    }

    function _singleZapUnwrap(bytes memory state, uint256 budget) private view returns (bytes memory next, uint256 received, uint256 claimAfter) {
        Repo.Layout storage l = Repo._layout();
        uint256 held = Transition(l.standardExchange).quoteShareBalance(state);
        uint256 amount = sharesForPairUnitsDownAtState(budget, state);
        if (amount == 0) return (state, 0, ratedClaimOfState(l.standardExchange, state));
        if (amount >= held) revert ISingleBufferQuoteErrors.InsufficientTokenOut();
        (next,, received,) = Transition(l.standardExchange).quoteTransition(state, Transition.Operation.RedeemExactIn, amount);
        if (received == 0) return (state, 0, ratedClaimOfState(l.standardExchange, state));
        claimAfter = ratedClaimOfState(l.standardExchange, next);
    }

    function _singlePairZapSale(uint256 amount, uint256 claim, uint256 reserve) private view returns (uint256 sold) {
        uint8 decimals = singleDecimals(Repo._layout().pairToken);
        uint256 saleClaim = Math.fromWadFloor(Math.swapDepositSaleAmt(Math.toWad(claim, decimals), Math.toWad(reserve, decimals)), decimals);
        sold = claim == 0 ? amount / 2 : amount * saleClaim / claim;
        if (sold > amount) sold = amount;
        if (sold == 0 || sold >= amount) sold = amount / 2;
    }

    function singlePairRawOut(uint256 claimIn, uint256 pairReserve, uint256 rawReserve) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint8 pairDecimals = singleDecimals(l.pairToken);
        uint8 rawDecimals = singleDecimals(l.rawToken);
        return Math.fromWadFloor(Math.saleQuote(Math.toWad(claimIn, pairDecimals), Math.toWad(pairReserve, pairDecimals),
            Math.toWad(rawReserve, rawDecimals)), rawDecimals);
    }

    function singleDecimals(address token) internal view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) d = l.decimalsCurrency0;
        else if (token == l.currency1) d = l.decimalsCurrency1;
        else revert ISingleBufferQuoteErrors.InvalidToken();
        if (d == 0) d = 18;
    }
    function singleOrderX(uint256 raw, uint256 pair) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? raw : pair;
    }
    function singleOrderY(uint256 raw, uint256 pair) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? pair : raw;
    }
    function singleClamp(uint256 x, uint256 y, uint256 amount0, uint256 amount1) internal pure returns (uint256 used0, uint256 used1) {
        used0 = amount0;
        used1 = amount1;
        if (x == 0 || y == 0) revert ISingleBufferQuoteErrors.NotLive();
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) used1 = ideal1;
        else used0 = (used1 * x) / y;
        if (used0 == 0 || used1 == 0) {
            if (used0 == 0 && (amount0 > 0 || x > 0)) used0 = 1;
            if (used1 == 0 && (amount1 > 0 || y > 0)) used1 = 1;
            if (used0 == 0 || used1 == 0) revert ISingleBufferQuoteErrors.ZeroAmount();
        }
    }

    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

    struct WithdrawalPlan {
        uint256 pairUser;
        uint256 residualOut;
        uint256 residualShares;
        uint256 remainingShares;
        uint256 remainingRated;
        uint256 rate;
        bytes state;
    }

    /// @dev Pro-rata redemption precedes the residual swap, including in the quote state.
    function withdrawalPlan(uint256 rawUser, uint256 seUser, uint256 rawRemain, bool asPair)
        external view returns (WithdrawalPlan memory q)
    {
        Repo.Layout storage l = Repo._layout();
        q.remainingShares = IERC20(l.standardExchange).balanceOf(address(this)) - seUser;
        if (l.standardExchange != l.pairToken && _supportsTransitionQuote(l.standardExchange, l.pairToken, address(this))) {
            (q.state,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteState(l.pairToken, address(this));
            if (seUser != 0) {
                (q.state,, q.pairUser,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                    q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, seUser);
            }
            q.rate = _rateForState(l, q.state);
        } else {
            q.pairUser = seUser == 0 ? 0 : l.standardExchange == l.pairToken ? seUser
                : IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), seUser, IERC20(l.pairToken));
            q.rate = _rate(l);
        }
        q.remainingRated = _ratedWith(l, q.remainingShares, q.rate);
        if (q.remainingRated == 0 && q.remainingShares != 0) q.remainingRated = 1;
        if (asPair) _quoteWithdrawalRawSale(l, q, rawUser, rawRemain);
        else _quoteWithdrawalPairSale(l, q, rawRemain);
    }

    function _quoteWithdrawalRawSale(Repo.Layout storage l, WithdrawalPlan memory q, uint256 rawUser, uint256 rawRemain) private view {
        if (rawUser == 0 || rawRemain == 0 || q.remainingRated == 0) return;
        uint8 rawDecimals = l.currency0 == l.rawToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
        uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(rawUser, rawDecimals),
            Math.toWad(rawRemain, rawDecimals), Math.toWad(q.remainingRated, _pairDecimals(l))), _pairDecimals(l));
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        q.residualShares = Math.sharesForPairUnitsDown(budget, q.rate, invScale, ratedScale);
        if (q.residualShares == 0) return;
        if (q.residualShares >= q.remainingShares) revert InsufficientTokenOut();
        if (q.state.length != 0) {
            (,, q.residualOut,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, q.residualShares);
        } else {
            q.residualOut = l.standardExchange == l.pairToken ? q.residualShares
                : IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), q.residualShares, IERC20(l.pairToken));
        }
    }

    function _quoteWithdrawalPairSale(Repo.Layout storage l, WithdrawalPlan memory q, uint256 rawRemain) private view {
        if (q.pairUser == 0 || rawRemain == 0 || q.remainingRated == 0) return;
        uint256 gain;
        if (q.state.length != 0) {
            (bytes memory next,, uint256 minted,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
                q.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, q.pairUser);
            uint256 afterRated = _ratedWith(l, q.remainingShares + minted, _rateForState(l, next));
            gain = afterRated > q.remainingRated ? afterRated - q.remainingRated : 0;
        } else {
            gain = _ratedOf(l, _previewPairToShares(l.standardExchange, l.pairToken, q.pairUser));
        }
        if (gain == 0) return;
        uint8 rawDecimals = l.currency0 == l.rawToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
        q.residualOut = Math.fromWadFloor(Math.saleQuote(Math.toWad(gain, _pairDecimals(l)),
            Math.toWad(q.remainingRated, _pairDecimals(l)), Math.toWad(rawRemain, rawDecimals)), rawDecimals);
    }

    function sharesForPairUnitsDown(uint256 units) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsDown(units, _rate(l), invScale, ratedScale);
    }

    function sharesForPairUnitsDownAtState(uint256 units, bytes memory state) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsDown(units, _rateForState(l, state), invScale, ratedScale);
    }

    function previewBudget(uint256 ratedBudget) public view returns (ExactInOutput memory output) {
        Repo.Layout storage l = Repo._layout();
        output.sharesOut = sharesForPairUnitsDown(ratedBudget);
        uint256 held = IERC20(l.standardExchange).balanceOf(address(this));
        if (held == 0 || output.sharesOut >= held) revert InsufficientTokenOut();
        if (output.sharesOut == 0) return output;
        output.amountOut = l.standardExchange == l.pairToken ? output.sharesOut
            : IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), output.sharesOut, IERC20(l.pairToken));
        if (output.amountOut == 0) output.sharesOut = 0;
    }

    function previewBudgetWithContext(uint256 ratedBudget, address manager) external view returns (ExactInOutput memory output) {
        Repo.Layout storage l = Repo._layout();
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        if (state.length == 0) return previewBudget(ratedBudget);
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        output.sharesOut = Math.sharesForPairUnitsDown(ratedBudget, _rateForState(l, state), invScale, ratedScale);
        uint256 held = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(state);
        if (held == 0 || output.sharesOut >= held) revert InsufficientTokenOut();
        if (output.sharesOut == 0) return output;
        (,, output.amountOut,) = IStandardExchangeTransitionQuote(l.standardExchange).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, output.sharesOut);
        if (output.amountOut == 0) output.sharesOut = 0;
    }

    function ratedReserveWithContext(address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        uint256 held = IERC20(l.standardExchange).balanceOf(address(this));
        uint256 value = state.length == 0 ? _ratedOf(l, held) : _ratedWith(l, held, _rateForState(l, state));
        return value == 0 && held != 0 ? 1 : value;
    }

    function previewBufferClaimInWithContext(uint256 amount, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        bytes memory state = ContextQuote.snapshot(l.standardExchange, l.pairToken, address(this), manager);
        if (state.length == 0) return _claimIn(l, amount);
        if (amount == 0) return 0;
        uint256 held = IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(state);
        (, uint256 gained) = projectedClaimIn(l.standardExchange, state, held, amount);
        return gained;
    }

    function unwrapQuoted(ExactInOutput memory output) external returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        if (output.sharesOut == 0 || output.sharesOut >= IERC20(l.standardExchange).balanceOf(address(this))) revert InsufficientTokenOut();
        if (l.standardExchange == l.pairToken) return output.sharesOut;
        uint256 beforeOut = IERC20(l.pairToken).balanceOf(address(this));
        IERC20(l.standardExchange).forceApprove(l.standardExchange, output.sharesOut);
        IStandardExchangeIn(l.standardExchange).exchangeIn(IERC20(l.standardExchange), output.sharesOut,
            IERC20(l.pairToken), output.amountOut, address(this), false, block.timestamp);
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
        amountOut = IERC20(l.pairToken).balanceOf(address(this)) - beforeOut;
        if (amountOut < output.amountOut) revert InsufficientTokenOut();
    }

    function exactOutputRatedDebit(uint256 amountOut) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 shares = l.standardExchange == l.pairToken ? amountOut
            : IStandardExchangeOut(l.standardExchange).previewExchangeOut(IERC20(l.standardExchange), IERC20(l.pairToken), amountOut);
        if (shares == 0 || shares >= IERC20(l.standardExchange).balanceOf(address(this))) revert InsufficientTokenOut();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnitsUp(shares, _rate(l), invScale, ratedScale);
    }

    function requireInputInverse(uint256 ratedInput) public view {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchange == l.pairToken || !ContextQuote.supported(l.standardExchange)) return;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        uint256 shares = Math.sharesForPairUnitsUp(ratedInput, _rate(l), invScale, ratedScale);
        if (IStandardExchangeOut(l.standardExchange).previewExchangeOut(IERC20(l.pairToken), IERC20(l.standardExchange), shares) == 0)
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
    error InsufficientTokenOut();

    struct ExactOutputContext {
        bytes state;
        uint256 reserve;
        uint256 raw;
        uint8 rawDecimals;
        uint8 pairDecimals;
    }

    /// @dev Linked EO coordinator. Zero manager preserves the actual-context owner/SE path.
    function quoteExactOutContext(bool zeroForOne, uint256 amountOut, address manager)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        ExactOutputContext memory q;
        q.state = ContextQuote.exactOutputState(l.standardExchange, l.pairToken, manager);
        uint256 held = IERC20(l.standardExchange).balanceOf(address(this));
        q.reserve = q.state.length == 0 ? _ratedOf(l, held) : _ratedWith(l, held, _rateForState(l, q.state));
        if (held != 0 && q.reserve == 0) q.reserve = 1;
        q.rawDecimals = l.rawToken == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        if (q.rawDecimals == 0) q.rawDecimals = 18;
        q.pairDecimals = _pairDecimals(l);
        if (q.pairDecimals == 0) q.pairDecimals = 18;
        q.raw = Math.toWad(IERC20(l.rawToken).balanceOf(address(this)), q.rawDecimals);
        q.reserve = Math.toWad(q.reserve, q.pairDecimals);
        if (zeroForOne == (l.currency0 == l.rawToken)) {
            uint256 debit = _exactOutputDebit(l, amountOut, q.state);
            return Math.fromWadCeil(Math.purchaseQuote(Math.toWad(debit, q.pairDecimals), q.raw, q.reserve), q.rawDecimals);
        }
        uint256 needed = Math.fromWadCeil(Math.purchaseQuote(Math.toWad(amountOut, q.rawDecimals), q.reserve, q.raw), q.pairDecimals);
        _requireInputInverseContext(l, needed, q.state);
        return _invertBufferClaimIn(l, needed, q.state);
    }

    function _requireInputInverseContext(Repo.Layout storage l, uint256 needed, bytes memory state) private view {
        if (l.standardExchange == l.pairToken || !ContextQuote.supported(l.standardExchange)) return;
        if (state.length == 0) requireInputInverse(needed);
        else {
            (uint256 invScale, uint256 ratedScale) = _scales(l);
            uint256 shares = Math.sharesForPairUnitsUp(needed, _rateForState(l, state), invScale, ratedScale);
            if (ContextQuote.inputForSharesFromState(l.standardExchange, l.pairToken, shares, state) == 0)
                revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
    }

    function _exactOutputDebit(Repo.Layout storage l, uint256 amount, bytes memory state) private view returns (uint256) {
        if (state.length == 0) return exactOutputRatedDebit(amount);
        uint256 shares = ContextQuote.withdrawFromState(l.standardExchange, l.pairToken, amount, state);
        if (shares == 0 || shares >= IERC20(l.standardExchange).balanceOf(address(this))) revert InsufficientTokenOut();
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnitsUp(shares, _rateForState(l, state), invScale, ratedScale);
    }

    /// @dev Residual maintenance only. A zero quote means the amount cannot enter
    /// the vault yet and stays owned locally.
    function previewResidualBuffer(uint256 amount) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        return IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.pairToken), amount, IERC20(l.standardExchange)
        );
    }

    /// @dev Consume the immediately preceding residual quote without evaluating
    /// the same read-only composition plan a second time. The minimum is retained.
    function bufferQuotedResidual(uint256 amount, uint256 minimum) external {
        Repo.Layout storage l = Repo._layout();
        IERC20(l.pairToken).forceApprove(l.standardExchange, amount);
        IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.pairToken), amount, IERC20(l.standardExchange), minimum, address(this), false, block.timestamp
        );
        IERC20(l.pairToken).forceApprove(l.standardExchange, 0);
    }
    error RateProviderFailed();
    error RateProviderRequired();

    /* ------------------------------ D60 rated valuation ------------------------------ */

    /// @notice Fail-closed provider read. Identity leg without a provider reads as 1e18 (raw balance).
    function rate() external view returns (uint256) {
        return _rate(Repo._layout());
    }

    /// @notice SE shares (or identity pair units) valued in pair-token units at the provider rate.
    function ratedOf(uint256 shares) external view returns (uint256) {
        return _ratedOf(Repo._layout(), shares);
    }

    /// @notice Shares needed to represent `pairUnits` at the provider rate, rounding up.
    function sharesForPairUnitsUp(uint256 pairUnits) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (pairUnits == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return pairUnits;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsUp(pairUnits, _rate(l), invScale, ratedScale);
    }

    /// @notice The hook's SE balance valued at the provider rate; a non-empty book never reads zero.
    function ratedReserve() external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        if (seBal == 0) return 0;
        uint256 claim = _ratedOf(l, seBal);
        return claim == 0 ? 1 : claim;
    }

    function _rate(Repo.Layout storage l) private view returns (uint256 rate_) {
        address rp = l.rateProvider;
        if (rp == address(0)) {
            if (l.pairToken == l.standardExchange) return Math.RATE_PRECISION;
            revert RateProviderRequired();
        }
        (bool ok, bytes memory data) = rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate_ = abi.decode(data, (uint256));
        if (rate_ == 0) revert RateProviderFailed();
    }

    function _scales(Repo.Layout storage l) private view returns (uint256 invScale, uint256 ratedScale) {
        uint8 seDec = l.pairToken == l.standardExchange ? _pairDecimals(l) : l.seDecimals;
        invScale = 10 ** (36 - uint256(seDec));
        ratedScale = 10 ** (36 - uint256(_pairDecimals(l)));
    }

    function _pairDecimals(Repo.Layout storage l) private view returns (uint8) {
        return l.currency0 == l.pairToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
    }

    function _ratedOf(Repo.Layout storage l, uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, _rate(l), invScale, ratedScale);
    }

    function _ratedWith(Repo.Layout storage l, uint256 shares, uint256 rate_) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, rate_, invScale, ratedScale);
    }

    /// @dev The provider's rate for a projected SE `state` (D41 / D48 `IStandardExchangeRateQuote`), so a
    ///      preview rates the post-buffer book the way execution will read it; a provider without projected
    ///      quotes answers with its live rate. Fails closed like `_rate`.
    function _rateForState(Repo.Layout storage l, bytes memory state) private view returns (uint256) {
        if (l.rateProvider == address(0)) return _rate(l);
        LegLib.ExternalQuote memory q;
        q.exchange = IStandardExchangeTransitionQuote(l.standardExchange);
        q.state = state;
        q.pair = l.pairToken;
        return LegLib.rateAfterExchange(q, l.pairToken, l.rateProvider);
    }

    /* ------------------------------ transition quotes ------------------------------ */

    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return _supportsTransitionQuote(se, pairToken, holder);
    }

    function _supportsTransitionQuote(address se, address pairToken, address holder) private view returns (bool) {
        if (ContextQuote.supported(se)) {
            IStandardExchangeTransitionQuote(se).quoteState(pairToken, holder);
            return true;
        }
        if (!IERC165(se).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId)) return false;
        // D37: probe with staticcall. Identity SE (share == pair) and other
        // unquotable assets must not hard-revert the join; fallback 1:1 claim.
        (bool ok, bytes memory ret) = se.staticcall(
            abi.encodeCall(IStandardExchangeTransitionQuote.quoteState, (pairToken, holder))
        );
        return ok && ret.length > 0;
    }

    function _previewPairToShares(address se, address pairToken, uint256 amountInRaw)
        private
        view
        returns (uint256)
    {
        if (amountInRaw == 0) return 0;
        if (se == pairToken) return amountInRaw;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
    }

    /// @notice Projected SE state after depositing `amountInRaw` pair tokens, with the holder's
    ///         projected share balance valued at the provider rate (D60) as `ratedHolderClaimAfter`.
    /// @dev H2: Uni V3/V4 `quoteTransition(DepositExactIn)` reverts `InvalidQuoteState`
    ///      when the deposit mints 0 shares (1 wei of an 18-dec pair into a large book).
    ///      `previewExchangeIn` returns 0 for that dust; skip the transition call.
    function quoteMintableDepositExactIn(
        address se,
        address pairToken,
        bytes memory state,
        uint256 amountInRaw
    )
        public
        view
        returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 ratedHolderClaimAfter)
    {
        Repo.Layout storage l = Repo._layout();
        if (amountInRaw == 0 || _previewPairToShares(se, pairToken, amountInRaw) == 0) {
            return (state, 0, 0, _ratedClaimOfState(l, se, state));
        }
        (nextState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(se).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw
        );
        ratedHolderClaimAfter = _ratedClaimOfState(l, se, nextState);
    }

    /// @notice Rated holder claim for an already projected `state`: shares x the provider's rate for that state.
    function ratedClaimOfState(address se, bytes memory state) public view returns (uint256) {
        return _ratedClaimOfState(Repo._layout(), se, state);
    }

    function _ratedClaimOfState(Repo.Layout storage l, address se, bytes memory state) private view returns (uint256) {
        uint256 shares_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state);
        if (shares_ == 0) return 0;
        return _ratedWith(l, shares_, _rateForState(l, state));
    }

    /// @notice Swap-side book at a projected external SE `state` (a route that redeems or deposits before the
    ///         hook swaps): the held shares valued at that state's rate, and the claim `assets` pair tokens add
    ///         when buffered from that state (post-buffer projected rate), computed the way `_claimIn` does.
    function projectedClaimIn(address se, bytes memory state, uint256 heldShares, uint256 assets)
        public view returns (uint256 reserveBefore, uint256 claimIn)
    {
        Repo.Layout storage l = Repo._layout();
        reserveBefore = _ratedWith(l, heldShares, _rateForState(l, state));
        if (assets == 0) return (reserveBefore, 0);
        if (l.pairToken == se) return (reserveBefore, _ratedOf(l, assets));
        if (!ContextQuote.supported(se) && _previewPairToShares(se, l.pairToken, assets) == 0) return (reserveBefore, 0);
        (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
            .quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets);
        uint256 after_ = _ratedWith(l, heldShares + minted_, _rateForState(l, next_));
        claimIn = after_ > reserveBefore ? after_ - reserveBefore : 0;
    }

    /* ------------------------------ buffer claim-in ------------------------------ */

    /// @dev Pair units the swap reserve gains when `amountInRaw` pair tokens are buffered: the rated book after
    ///      the buffer minus the rated book before it. With a transition-quoting SE the post-buffer book is
    ///      `(held + minted) x rateAfter`, where `rateAfter` is the provider's projected rate for that state
    ///      (an SE usage fee or first-deposit rounding moves the rate; execution reads the moved rate). Without a
    ///      transition quote the gain is `previewExchangeIn(pair -> se) x live rate`. Identity leg: the pair units.
    function _claimIn(Repo.Layout storage l, uint256 amountInRaw) private view returns (uint256) {
        if (amountInRaw == 0) return 0;
        address se = l.standardExchange;
        address pairToken = l.pairToken;
        if (se == pairToken) return _ratedOf(l, amountInRaw);
        uint256 sharesOut = _previewPairToShares(se, pairToken, amountInRaw);
        if (sharesOut == 0) return 0;
        if (!_supportsTransitionQuote(se, pairToken, address(this))) return _ratedOf(l, sharesOut);
        (bytes memory state_,) = IStandardExchangeTransitionQuote(se).quoteState(pairToken, address(this));
        uint256 held_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state_);
        (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
            .quoteTransition(state_, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw);
        uint256 after_ = _ratedWith(l, held_ + minted_, _rateForState(l, next_));
        uint256 before_ = _ratedOf(l, held_);
        return after_ > before_ ? after_ - before_ : 0;
    }

    function previewBufferClaimIn(uint256 amountInRaw) external view returns (uint256) {
        return _claimIn(Repo._layout(), amountInRaw);
    }

    function invertBufferClaimIn(uint256 claimInNeeded) external view returns (uint256 amountInRaw) {
        return _invertBufferClaimIn(Repo._layout(), claimInNeeded, bytes(""));
    }

    function _claimInContext(Repo.Layout storage l, uint256 amount, bytes memory state) private view returns (uint256 gain) {
        if (state.length == 0) return _claimIn(l, amount);
        (, gain) = projectedClaimIn(l.standardExchange, state,
            IStandardExchangeTransitionQuote(l.standardExchange).quoteShareBalance(state), amount);
    }

    function _invertBufferClaimIn(Repo.Layout storage l, uint256 claimInNeeded, bytes memory state) private view returns (uint256) {
        if (claimInNeeded == 0) return 0;
        uint256 hi = claimInNeeded;
        uint256 guard;
        while (_claimInContext(l, hi, state) < claimInNeeded && guard < 64) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (_claimInContext(l, hi, state) < claimInNeeded) {
            revert InsufficientTokenOut();
        }
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (_claimInContext(l, mid, state) >= claimInNeeded) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }
}
