// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

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
        uint256 local;
        uint256 refundedShares;
    }

    /// @dev PM preview only; actual-context execution continues through Common's existing plan.
    function quoteExactOutContext(bool zeroForOne, uint256 amountOut, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address pairIn = zeroForOne ? l.currency0 : l.currency1;
        address pairOut = zeroForOne ? l.currency1 : l.currency0;
        address seIn = l.legs.standardExchangeOf[pairIn];
        address seOut = l.legs.standardExchangeOf[pairOut];
        (, uint256 debit) = _outputExactOut(seOut, amountOut, manager);
        Leg memory input = _leg(l, seIn);
        Leg memory output = _leg(l, seOut);
        bytes memory stateIn = snapshotState(seIn, manager);
        uint256 reserveIn = l.localReserves[pairIn] + ratedAt(seIn, l.shareReserves[seIn], stateIn);
        uint256 reserveOut = l.localReserves[pairOut] + ratedAt(seOut, l.shareReserves[seOut], snapshotState(seOut, manager));
        uint256 needed = Math.fromWadCeil(Math.purchaseQuote(Math.toWad(debit, output.pairDec),
            Math.toWad(reserveIn, input.pairDec), Math.toWad(reserveOut, output.pairDec)), input.pairDec);
        _requireInputInverse(seIn, needed, stateIn);
        return _invertBufferClaimIn(seIn, pairIn, needed, stateIn);
    }

    /// @dev Unknown registrations and failed authority queries fail closed.
    function disabled(address se) public view returns (bool) {
        IVaultRegistryDisableQuery registry = IVaultRegistryDisableQuery(Repo._layout().disableRegistry);
        if (registry.packageOfVault(se) == address(0)) revert UnknownLeg(se);
        return registry.isDisabled(se);
    }

    function snapshotState(address se, address manager) public view returns (bytes memory state) {
        Leg memory leg = _leg(Repo._layout(), se);
        if (se == leg.pair) return state;
        state = ContextQuote.snapshot(se, leg.pair, address(this), manager);
        if (state.length == 0 && BufferClaim.supportsTransitionQuote(se, leg.pair, address(this))) {
            (state,) = IStandardExchangeTransitionQuote(se).quoteState(leg.pair, address(this));
        }
    }

    function ratedAt(address se, uint256 shares, bytes memory state) public view returns (uint256) {
        if (shares == 0) return 0;
        Leg memory leg = _leg(Repo._layout(), se);
        return _ratedWith(leg, se, shares, state.length == 0 ? _rate(leg, se) : _rateForState(leg, se, state));
    }

    function conversion(address se, uint256 amount, bool deposit, bytes memory state)
        public view returns (ExchangeInAmount.Result memory result, bytes memory next)
    {
        Leg memory leg = _leg(Repo._layout(), se);
        if (amount == 0 || se == leg.pair) return (ExchangeInAmount.Result(amount, 0), state);
        if (deposit && disabled(se)) return (ExchangeInAmount.Result(0, amount), state);
        if (state.length == 0) {
            return (ExchangeInAmount.previewResult(IStandardExchangeIn(se),
                IERC20(deposit ? leg.pair : se), amount, IERC20(deposit ? se : leg.pair)), state);
        }
        uint256 consumed;
        uint256 output;
        (next, consumed, output,) = IStandardExchangeTransitionQuote(se).quoteTransition(state,
            deposit ? IStandardExchangeTransitionQuote.Operation.DepositExactIn
                : IStandardExchangeTransitionQuote.Operation.RedeemExactIn, amount);
        result = ExchangeInAmount.fromConsumedInput(amount, consumed, output);
    }

    function inputGain(address se, uint256 bookedShares, uint256 amount, bytes memory state)
        public view returns (uint256)
    {
        if (amount == 0) return 0;
        if (disabled(se)) return amount;
        (ExchangeInAmount.Result memory result, bytes memory next) = conversion(se, amount, true, state);
        uint256 beforeValue = ratedAt(se, bookedShares, state);
        uint256 afterValue = ratedAt(se, bookedShares + result.amountOut, next) + result.amountRefunded;
        return afterValue > beforeValue ? afterValue - beforeValue : 0;
    }

    function outputAt(address se, uint256 budget, uint256 bookedShares, uint256 local, bytes memory state)
        public view returns (OutputQuote memory q, bytes memory next)
    {
        q.local = budget < local ? budget : local;
        q.amount = q.local;
        next = state;
        if (budget == q.local) return (q, next);
        Leg memory leg = _leg(Repo._layout(), se);
        q.shares = _budgetShares(leg, budget - q.local,
            state.length == 0 ? _rate(leg, se) : _rateForState(leg, se, state));
        if (q.shares == 0) return (q, next);
        if (q.shares >= bookedShares) revert InsufficientTokenOut();
        ExchangeInAmount.Result memory result;
        (result, next) = conversion(se, q.shares, false, state);
        q.amount += result.amountOut;
        q.refundedShares = result.amountRefunded;
    }

    function _outputExactOut(address se, uint256 amount, address manager)
        private view returns (OutputQuote memory q, uint256 debit)
    {
        Repo.Layout storage l = Repo._layout();
        Leg memory leg = _leg(l, se);
        q.amount = amount;
        uint256 local = l.localReserves[leg.pair];
        q.local = amount < local ? amount : local;
        debit = q.local;
        if (q.local == amount) return (q, debit);
        bytes memory state = ContextQuote.exactOutputState(se, leg.pair, manager);
        q.shares = ContextQuote.withdrawFromState(se, leg.pair, amount - q.local, state);
        if (q.shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (q.shares >= l.shareReserves[se]) revert InsufficientTokenOut();
        debit += RatedMath.ratedPairUnitsUp(q.shares, state.length == 0 ? _rate(leg, se) : _rateForState(leg, se, state),
            10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
    }

    function _requireInputInverse(address se, uint256 ratedInput, bytes memory state) private view {
        Leg memory leg = _leg(Repo._layout(), se);
        if (se == leg.pair || disabled(se) || !ContextQuote.supported(se)) return;
        uint256 shares = RatedMath.sharesForPairUnitsUp(ratedInput,
            state.length == 0 ? _rate(leg, se) : _rateForState(leg, se, state),
            10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
        if (ContextQuote.inputForSharesFromState(se, leg.pair, shares, state) == 0)
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function _budgetShares(Leg memory leg, uint256 budget, uint256 rate_) private pure returns (uint256) {
        return RatedMath.sharesForPairUnitsDown(budget, rate_, 10 ** (36 - uint256(leg.seDec)), 10 ** (36 - uint256(leg.pairDec)));
    }

    function previewOutputExactIn(address se, uint256 budget) public view returns (OutputQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        (q,) = outputAt(se, budget, l.shareReserves[se], l.localReserves[_leg(l, se).pair], bytes(""));
    }

    function previewOutputWithContext(address se, uint256 budget, address manager) external view returns (OutputQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        (q,) = outputAt(se, budget, l.shareReserves[se], l.localReserves[_leg(l, se).pair], snapshotState(se, manager));
    }

    function ratedReserveWithContext(address se, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        Leg memory leg = _leg(l, se);
        return l.localReserves[leg.pair] + ratedAt(se, l.shareReserves[se], snapshotState(se, manager));
    }

    function previewInputWithContext(address se, uint256 amount, address manager) external view returns (uint256) {
        return inputGain(se, Repo._layout().shareReserves[se], amount, snapshotState(se, manager));
    }

    function previewOutputExactOut(address se, uint256 amount) external view returns (OutputQuote memory q, uint256 debit) {
        return _outputExactOut(se, amount, address(0));
    }

    function requireInputInverse(address se, uint256 ratedInput) external view {
        _requireInputInverse(se, ratedInput, bytes(""));
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
        Repo.Layout storage l = Repo._layout();
        Leg memory leg = _leg(l, se);
        return l.localReserves[leg.pair] + _ratedOf(l, se, l.shareReserves[se]);
    }

    /// @notice D60/F9: the rated reserve a projected SE `state` would hold — the holder's projected share
    ///         balance valued at the provider's rate for that state. Lets a preview size its swap and clamp
    ///         off the same rated book execution reads live, so preview and execution agree to the wei.


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
        pairToken;
        return inputGain(se, l.shareReserves[se], amountInRaw, snapshotState(se, address(0)));
    }

    /// @dev Rated book after the buffer minus the rated book before it: the provider's projected rate for the
    ///      post-buffer state is what execution will read (an SE usage fee moves the rate).


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
        leg;
        return inputGain(se, Repo._layout().shareReserves[se], amountInRaw, state);
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
