// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as BufferClaim}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as RatedMath}
    from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo}
    from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";

/// @notice Dual CP buffer claims. D60: each SE leg of the swap invariant is shares x the leg's
///         configured rate provider (WAD whole pair tokens per whole share); the hook never derives a
///         rate from the SE's own quotes. SE quotes only count shares minted or pair paid out.
/// @dev External library: DELEGATECALL keeps `Repo._layout()` on the hook diamond.
library UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib {
    struct OutputQuote {
        uint256 shares;
        uint256 amount;
    }

    struct ExactOutputLeg {
        address se;
        Leg leg;
        bytes state;
        uint256 rate;
        uint256 reserve;
    }

    function _exactOutputLeg(address token, address manager) private view returns (ExactOutputLeg memory q) {
        Repo.Layout storage l = Repo._layout();
        q.se = token == l.token0 ? l.se0 : l.se1;
        q.leg = _leg(l, q.se);
        q.state = ContextQuote.exactOutputState(q.se, token, manager);
        q.rate = q.state.length == 0 ? _rate(q.leg, q.se) : _rateForState(q.leg, q.se, q.state);
        uint256 held = IERC20(q.se).balanceOf(address(this));
        q.reserve = _ratedWith(q.leg, q.se, held, q.rate);
    }

    /// @dev PM preview only; actual-context execution continues through Common's existing plan.
    function quoteExactOutContext(bool zeroForOne, uint256 amountOut, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        ExactOutputLeg memory input = _exactOutputLeg(zeroForOne ? l.currency0 : l.currency1, manager);
        ExactOutputLeg memory output = _exactOutputLeg(zeroForOne ? l.currency1 : l.currency0, manager);
        uint256 shares = ContextQuote.withdrawFromState(output.se, output.leg.pair, amountOut, output.state);
        if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares >= IERC20(output.se).balanceOf(address(this))) revert InsufficientTokenOut();
        uint256 debit = RatedMath.ratedPairUnitsUp(shares, output.rate,
            10 ** (36 - uint256(output.leg.seDec)), 10 ** (36 - uint256(output.leg.pairDec)));
        uint256 needed = Math.fromWadCeil(Math.purchaseQuote(Math.toWad(debit, output.leg.pairDec),
            Math.toWad(input.reserve, input.leg.pairDec), Math.toWad(output.reserve, output.leg.pairDec)), input.leg.pairDec);
        if (input.se != input.leg.pair && ContextQuote.supported(input.se)) {
            shares = RatedMath.sharesForPairUnitsUp(needed, input.rate,
                10 ** (36 - uint256(input.leg.seDec)), 10 ** (36 - uint256(input.leg.pairDec)));
            if (ContextQuote.inputForSharesFromState(input.se, input.leg.pair, shares, input.state) == 0)
                revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        return _invertBufferClaimIn(input.se, input.leg.pair, needed, input.state);
    }

    function _budgetShares(Leg memory leg, uint256 budget, uint256 rate_) private pure returns (uint256) {
        return RatedMath.sharesForPairUnitsDown(budget, rate_, 10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
    }

    function previewOutputExactIn(address se, uint256 budget) public view returns (OutputQuote memory q) {
        Leg memory leg = _leg(Repo._layout(), se);
        q.shares = _budgetShares(leg, budget, _rate(leg, se));
        if (q.shares == 0) return q;
        if (q.shares >= IERC20(se).balanceOf(address(this))) revert InsufficientTokenOut();
        q.amount = se == leg.pair ? q.shares
            : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), q.shares, IERC20(leg.pair));
    }

    function projectOutputExactIn(address se, bytes memory state, uint256 budget)
        public view returns (OutputQuote memory q, bytes memory next)
    {
        Leg memory leg = _leg(Repo._layout(), se);
        q.shares = _budgetShares(leg, budget, _rateForState(leg, se, state));
        if (q.shares == 0) return (q, state);
        if (q.shares >= IStandardExchangeTransitionQuote(se).quoteShareBalance(state)) revert InsufficientTokenOut();
        (next,, q.amount,) = IStandardExchangeTransitionQuote(se).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, q.shares);
    }

    function previewOutputWithContext(address se, uint256 budget, address manager) external view returns (OutputQuote memory q) {
        Leg memory leg = _leg(Repo._layout(), se);
        bytes memory state = ContextQuote.snapshot(se, leg.pair, address(this), manager);
        if (state.length == 0) return previewOutputExactIn(se, budget);
        (q,) = projectOutputExactIn(se, state, budget);
    }

    function ratedReserveWithContext(address se, address manager) external view returns (uint256) {
        Leg memory leg = _leg(Repo._layout(), se);
        bytes memory state = ContextQuote.snapshot(se, leg.pair, address(this), manager);
        uint256 held = IERC20(se).balanceOf(address(this));
        return state.length == 0 ? _ratedOf(Repo._layout(), se, held) : _ratedWith(leg, se, held, _rateForState(leg, se, state));
    }

    function previewInputWithContext(address se, uint256 amount, address manager) external view returns (uint256) {
        Leg memory leg = _leg(Repo._layout(), se);
        bytes memory state = ContextQuote.snapshot(se, leg.pair, address(this), manager);
        if (state.length == 0) return _claimIn(Repo._layout(), se, leg.pair, amount);
        if (amount == 0) return 0;
        return _projectedGainFromState(leg, se, state, amount);
    }

    function previewOutputExactOut(address se, uint256 amount) external view returns (OutputQuote memory q, uint256 debit) {
        Leg memory leg = _leg(Repo._layout(), se);
        q.amount = amount;
        q.shares = se == leg.pair ? amount
            : IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(leg.pair), amount);
        if (q.shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (q.shares >= IERC20(se).balanceOf(address(this))) revert InsufficientTokenOut();
        debit = RatedMath.ratedPairUnitsUp(q.shares, _rate(leg, se),
            10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
    }

    function requireInputInverse(address se, uint256 ratedInput) external view {
        Leg memory leg = _leg(Repo._layout(), se);
        if (se == leg.pair || !ContextQuote.supported(se)) return;
        uint256 shares = RatedMath.sharesForPairUnitsUp(ratedInput, _rate(leg, se),
            10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
        if (IStandardExchangeOut(se).previewExchangeOut(IERC20(leg.pair), IERC20(se), shares) == 0)
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
    error InsufficientTokenOut();
    error RateProviderFailed();
    error RateProviderRequired();
    error UnknownLeg(address se);

    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return BufferClaim.supportsTransitionQuote(se, pairToken, holder);
    }

    /* ------------------------------ D60 rated valuation ------------------------------ */

    /// @notice `shares` of `se` valued in that leg's pair-token units at the provider rate.
    function ratedOf(address se, uint256 shares) external view returns (uint256) {
        return _ratedOf(Repo._layout(), se, shares);
    }

    /// @notice The hook's `se` balance valued at the provider rate.
    function ratedReserve(address se) external view returns (uint256) {
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        return _ratedOf(Repo._layout(), se, seBal);
    }

    /// @notice D60/F9: the rated reserve a projected SE `state` would hold — the holder's projected share
    ///         balance valued at the provider's rate for that state. Lets a preview size its swap and clamp
    ///         off the same rated book execution reads live, so preview and execution agree to the wei.
    function ratedReserveOfState(address se, bytes memory state) external view returns (uint256) {
        Leg memory leg = _leg(Repo._layout(), se);
        uint256 shares = IStandardExchangeTransitionQuote(se).quoteShareBalance(state);
        if (shares == 0) return 0;
        uint256 r = _ratedWith(leg, se, shares, _rateForState(leg, se, state));
        return r == 0 ? 1 : r;
    }

    /// @notice D60 getter helper: the provider configured for `token_` (pair token or its SE).
    function rateProviderOf(address token_) external view returns (address) {
        Repo.Layout storage l = Repo._layout();
        if (token_ == l.token0 || token_ == l.se0) return l.rateProvider0;
        if (token_ == l.token1 || token_ == l.se1) return l.rateProvider1;
        return address(0);
    }

    struct Leg {
        address pair;
        address rp;
        uint8 seDec;
        uint8 pairDec;
    }

    function _leg(Repo.Layout storage l, address se) private view returns (Leg memory leg) {
        if (se == l.se0) {
            leg.pair = l.token0;
            leg.rp = l.rateProvider0;
            leg.seDec = l.seDecimals0;
        } else if (se == l.se1) {
            leg.pair = l.token1;
            leg.rp = l.rateProvider1;
            leg.seDec = l.seDecimals1;
        } else {
            revert UnknownLeg(se);
        }
        leg.pairDec = leg.pair == l.currency0 ? l.decimalsCurrency0 : l.decimalsCurrency1;
        if (leg.pair == se) leg.seDec = leg.pairDec;
    }

    function _rate(Leg memory leg, address se) private view returns (uint256 rate_) {
        if (leg.rp == address(0)) {
            if (leg.pair == se) return RatedMath.RATE_PRECISION;
            revert RateProviderRequired();
        }
        (bool ok, bytes memory data) = leg.rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate_ = abi.decode(data, (uint256));
        if (rate_ == 0) revert RateProviderFailed();
    }

    function _ratedOf(Repo.Layout storage l, address se, uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        Leg memory leg = _leg(l, se);
        return _ratedWith(leg, se, shares, _rate(leg, se));
    }

    function _ratedWith(Leg memory leg, address se, uint256 shares, uint256 rate_) private pure returns (uint256) {
        if (shares == 0) return 0;
        if (leg.pair == se && leg.rp == address(0)) return shares;
        return RatedMath.ratedPairUnits(
            shares, rate_, 10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec))
        );
    }

    /// @dev The provider's rate for a projected SE `state` (D41 / D48 `IStandardExchangeRateQuote`); a
    ///      provider without projected quotes answers with its live rate. Fails closed like `_rate`.
    function _rateForState(Leg memory leg, address se, bytes memory state) private view returns (uint256) {
        if (leg.rp == address(0)) return _rate(leg, se);
        LegLib.ExternalQuote memory q;
        q.exchange = IStandardExchangeTransitionQuote(se);
        q.state = state;
        q.pair = leg.pair;
        return LegLib.rateAfterExchange(q, leg.pair, leg.rp);
    }

    /* ------------------------------ buffer claim-in ------------------------------ */

    /// @dev Pair units added to the swap reserve when `amountInRaw` pair tokens are buffered into `se`:
    ///      shares minted x provider rate. Identity leg: the pair units themselves.
    function _claimIn(Repo.Layout storage l, address se, address pairToken, uint256 amountInRaw)
        private view returns (uint256)
    {
        if (amountInRaw == 0) return 0;
        if (se == pairToken) return _ratedOf(l, se, amountInRaw);
        uint256 sharesOut = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        Leg memory leg = _leg(l, se);
        if (!BufferClaim.supportsTransitionQuote(se, pairToken, address(this))) {
            return _ratedWith(leg, se, sharesOut, _rate(leg, se));
        }
        return _projectedGain(leg, se, pairToken, amountInRaw);
    }

    /// @dev Rated book after the buffer minus the rated book before it: the provider's projected rate for the
    ///      post-buffer state is what execution will read (an SE usage fee moves the rate).
    function _projectedGain(Leg memory leg, address se, address pairToken, uint256 amountInRaw)
        private view returns (uint256)
    {
        (bytes memory state_,) = IStandardExchangeTransitionQuote(se).quoteState(pairToken, address(this));
        uint256 held_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state_);
        uint256 before_ = _ratedWith(leg, se, held_, _rate(leg, se));
        uint256 after_;
        {
            (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
                .quoteTransition(state_, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw);
            after_ = _ratedWith(leg, se, held_ + minted_, _rateForState(leg, se, next_));
        }
        return after_ > before_ ? after_ - before_ : 0;
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw) external view returns (uint256) {
        return _claimIn(Repo._layout(), se, pairToken, amountInRaw);
    }

    /// @dev F9/D62: buffer claim-in read from a PROJECTED SE `state` instead of the live book. Execution's
    ///      `_quoteExactInAmountOut` reads the post-unwrap live state; a share-input preview projects that same
    ///      state (post ReceiveShares + RedeemExactIn) into `state`, so quoting the buffer gain off it makes
    ///      preview and execution agree to the wei. For a pair input `state` equals the live state and this
    ///      matches `previewBufferClaimIn` exactly. Rated book after buffering `amountInRaw` minus before, both
    ///      valued at the provider's projected rate for the respective state.
    function projectedBufferClaimIn(address se, bytes memory state, uint256 amountInRaw)
        external view returns (uint256)
    {
        if (amountInRaw == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        Leg memory leg = _leg(l, se);
        if (leg.pair == se) return _ratedOf(l, se, amountInRaw);
        return _projectedGainFromState(leg, se, state, amountInRaw);
    }

    /// @dev Buffer gain quoted off a caller-supplied projected `state` (see `projectedBufferClaimIn`).
    function _projectedGainFromState(Leg memory leg, address se, bytes memory state, uint256 amountInRaw)
        private view returns (uint256)
    {
        uint256 held_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state);
        uint256 before_ = _ratedWith(leg, se, held_, _rateForState(leg, se, state));
        uint256 after_;
        {
            (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
                .quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw);
            if (minted_ == 0) return 0;
            after_ = _ratedWith(leg, se, held_ + minted_, _rateForState(leg, se, next_));
        }
        return after_ > before_ ? after_ - before_ : 0;
    }

    function invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded)
        external view returns (uint256 amountInRaw)
    {
        return _invertBufferClaimIn(se, pairToken, claimInNeeded, bytes(""));
    }

    function _claimInContext(Repo.Layout storage l, address se, address pair, uint256 amount, bytes memory state) private view returns (uint256) {
        return state.length == 0 ? _claimIn(l, se, pair, amount) : _projectedGainFromState(_leg(l, se), se, state, amount);
    }

    function _invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded, bytes memory state) private view returns (uint256) {
        if (claimInNeeded == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 hi = claimInNeeded;
        uint256 guard;
        while (_claimInContext(l, se, pairToken, hi, state) < claimInNeeded && guard < 64) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (_claimInContext(l, se, pairToken, hi, state) < claimInNeeded) revert InsufficientTokenOut();
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (_claimInContext(l, se, pairToken, mid, state) >= claimInNeeded) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }
}
