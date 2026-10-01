// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "./UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as Math} from "./UniswapV4StandardExchangeOrbitalBufferHookMath.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookClaimLib
 * @notice SE claim / rate / buffer-unwrap helpers (external previews + fail-closed rates).
 * @dev Pure Math must not call SE/RP — composition lives here.
 */
library UniswapV4StandardExchangeOrbitalBufferHookClaimLib {
    error RateProviderFailed();
    error RateProviderRequired();
    error SeInvertUnavailable();
    error InsufficientTokenOut();
    error ZeroAmount();
    error NotLive();
    error InvalidPoolToken();
    error InvalidRoute(address tokenIn, address tokenOut);

    struct SphereLegsWad {
        uint256 R;
        uint256 L2;
        uint256 xWad;
        uint256 yWad;
        uint256 zWad;
    }

    struct SwapLiveCtx {
        address tokenZ;
        uint256 feeWad;
        uint256 eOutNative;
    }

    /// @dev PM EO uses the same sphere and buffer-gain inverse with projected manager context.
    function previewSwapExactOutContext(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad, address manager)
        external view returns (uint256 amountIn)
    {
        if (amountOut == 0) revert ZeroAmount();
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        address other = _witnessAndLegs(tokenIn, tokenOut);
        uint256 outReserve = _effectiveNativeWithContext(tokenOut, manager);
        if (Repo._layout().R == 0 || outReserve == 0 || _effectiveNativeWithContext(tokenIn, manager) == 0) revert NotLive();
        uint256 debit = _exactOutputDebit(tokenOut, amountOut, manager);
        if (debit >= outReserve) revert Math.Drain();
        SphereLegsWad memory s = _sphereLegsWithContext(tokenIn, tokenOut, other, manager);
        uint256 net = _sphereExactOut(s, _toWad(tokenOut, debit));
        uint256 needed = Math.fromWadCeil(Math.grossUpExactOut(net, feeWad), _decimalsOf(tokenIn));
        amountIn = _exactOutputInput(tokenIn, needed, manager);
        if (amountIn == 0) revert ZeroAmount();
    }

    function _sphereExactOut(SphereLegsWad memory s, uint256 dyWad) private pure returns (uint256) {
        return Math.sphereExactOutInNetWad(s.R, s.L2, s.xWad, s.yWad, s.zWad, dyWad);
    }

    function _exactOutputDebit(address token, uint256 amount, address manager) private view returns (uint256) {
        address se = _seOf(token);
        if (se == address(0)) return amount;
        bytes memory state = ContextQuote.exactOutputState(se, token, manager);
        uint256 shares = ContextQuote.withdrawFromState(se, token, amount, state);
        if (shares == 0) revert InsufficientTokenOut();
        if (shares > _spendableSeShares(token)) revert Math.Drain();
        address rp = _rpOf(token);
        if (rp == address(0)) revert RateProviderRequired();
        uint256 rate_ = state.length == 0 ? getRateFailClosed(rp) : ContextQuote.rateFromState(se, token, rp, state);
        return ratedNative(shares, rate_, se, token);
    }

    function _exactOutputInput(address token, uint256 needed, address manager) private view returns (uint256) {
        address se = _seOf(token);
        if (se == address(0)) return needed;
        BufferClaimQuote memory quote;
        quote.se = se;
        quote.token = token;
        quote.state = ContextQuote.exactOutputState(se, token, manager);
        if (quote.state.length == 0) quote = bufferClaimQuote(se, _rpOf(token), token, address(this));
        else {
            if (_rpOf(token) == address(0)) revert RateProviderRequired();
            quote.rate = ContextQuote.rateFromState(se, token, _rpOf(token), quote.state);
        }
        if (se != token && ContextQuote.supported(se)) {
            uint256 shares = sharesForNativeUp(needed, quote.rate, se, token);
            if (ContextQuote.inputForSharesFromState(se, token, shares, quote.state) == 0) revert SeInvertUnavailable();
        }
        return _invertBufferForEffective(quote, needed);
    }

    /// @dev Linked copy of the family quote coordinator; no funding or settlement moves here.
    function previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad, address manager)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        SwapLiveCtx memory ctx;
        if (manager == address(0)) ctx = _loadSwapLiveCtxBook(tokenIn, tokenOut);
        else {
            ctx.tokenZ = _witnessAndLegs(tokenIn, tokenOut);
            ctx.eOutNative = _effectiveNativeWithContext(tokenOut, manager);
            if (Repo._layout().R == 0 || ctx.eOutNative == 0 || _effectiveNativeWithContext(tokenIn, manager) == 0) revert NotLive();
        }
        ctx.feeWad = feeWad;
        uint256 dInNative = manager == address(0) ? _faceInToEffectiveNative(tokenIn, amountIn)
            : previewInputWithContext(_seOf(tokenIn), _rpOf(tokenIn), tokenIn, amountIn, manager);
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, dInNative), ctx.feeWad);
        SphereLegsWad memory legs = manager == address(0) ? _loadSphereLegs(tokenIn, tokenOut, ctx.tokenZ)
            : _sphereLegsWithContext(tokenIn, tokenOut, ctx.tokenZ, manager);
        uint256 dOutNative = _fromWadFloor(tokenOut, _sphereExactIn(legs, dxNet));
        if (dOutNative == 0 || dOutNative >= ctx.eOutNative) revert Math.Drain();
        if (manager == address(0)) (amountOut, sharesOut) = _effectiveOutToFaceOut(tokenOut, dOutNative);
        else {
            (amountOut, sharesOut) = previewOutputWithContext(_seOf(tokenOut), _rpOf(tokenOut), tokenOut, dOutNative, manager);
            if (_seOf(tokenOut) != address(0)) {
                if (sharesOut == 0) revert InsufficientTokenOut();
                if (sharesOut > _spendableSeShares(tokenOut)) revert Math.Drain();
            }
        }
        if (amountOut == 0) revert Math.Drain();
    }

    function _effectiveOutToFaceOut(address tokenOut, uint256 dOutNative) private view returns (uint256 amountOut, uint256 sharesOut) {
        address se = _seOf(tokenOut);
        if (se != address(0)) {
            (amountOut, sharesOut) = previewUnwrapForEffectiveOut(se, _rpOf(tokenOut), tokenOut, dOutNative);
            if (sharesOut == 0) revert InsufficientTokenOut();
            if (sharesOut > _spendableSeShares(tokenOut)) revert Math.Drain();
        } else amountOut = dOutNative;
    }

    function _sphereExactIn(SphereLegsWad memory s, uint256 dxNet) private pure returns (uint256) {
        return Math.sphereExactInOutWad(s.R, s.L2, s.xWad, s.yWad, s.zWad, dxNet);
    }

    function _toWad(address token, uint256 amount) private view returns (uint256) {
        return Math.toWad(amount, _decimalsOf(token));
    }

    function _fromWadFloor(address token, uint256 amount) private view returns (uint256) {
        return Math.fromWadFloor(amount, _decimalsOf(token));
    }

    function _loadSwapLiveCtxBook(address tokenIn, address tokenOut) private view returns (SwapLiveCtx memory ctx) {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) revert NotLive();
        uint256 eIn = _effectiveNativeOf(tokenIn);
        ctx.eOutNative = _effectiveNativeOf(tokenOut);
        if (eIn == 0 || ctx.eOutNative == 0) revert NotLive();
        ctx.tokenZ = _witnessAndLegs(tokenIn, tokenOut);
    }

    function _loadSphereLegs(address tokenIn, address tokenOut, address tokenZ) private view returns (SphereLegsWad memory s) {
        s.R = Repo._layout().R;
        s.xWad = _toWad(tokenIn, _effectiveNativeOf(tokenIn));
        s.yWad = _toWad(tokenOut, _effectiveNativeOf(tokenOut));
        s.zWad = _toWad(tokenZ, _effectiveNativeOf(tokenZ));
        s.L2 = Math.recomputeL2(s.R, s.xWad, s.yWad, s.zWad);
    }

    function _sphereLegsWithContext(address input, address output, address other, address manager)
        private view returns (SphereLegsWad memory s)
    {
        s.R = Repo._layout().R;
        s.xWad = _toWad(input, _effectiveNativeWithContext(input, manager));
        s.yWad = _toWad(output, _effectiveNativeWithContext(output, manager));
        s.zWad = _toWad(other, _effectiveNativeWithContext(other, manager));
        s.L2 = Math.recomputeL2(s.R, s.xWad, s.yWad, s.zWad);
    }

    function _faceInToEffectiveNative(address tokenIn, uint256 amountIn) private view returns (uint256 dInNative) {
        dInNative = amountIn;
        address se = _seOf(tokenIn);
        if (se != address(0) && se != tokenIn) {
            uint256 claim = previewBufferClaimIn(se, _rpOf(tokenIn), tokenIn, amountIn, address(this));
            if (claim != 0) dInNative = claim;
        }
    }

    function _effectiveNativeOf(address token) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint8 i = Repo._indexOf(l, token);
        address t = Repo._tokenAt(l, i);
        address se = Repo._seAt(l, i);
        address rp = Repo._rpAt(l, i);
        uint256 held = se == address(0) ? 0 : IERC20(se).balanceOf(address(this));
        return effectiveNative(se, rp, t, l.reserves[t], held);
    }

    function _effectiveNativeWithContext(address token, address manager) private view returns (uint256) {
        address se = _seOf(token);
        return effectiveNativeWithContext(se, _rpOf(token), token, Repo._layout().reserves[token],
            se == address(0) ? 0 : IERC20(se).balanceOf(address(this)), manager);
    }

    function _witnessAndLegs(address tokenIn, address tokenOut) private view returns (address) {
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (tokenIn != l.token0 && tokenOut != l.token0) return l.token0;
        if (tokenIn != l.token1 && tokenOut != l.token1) return l.token1;
        return l.token2;
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.token0 || token == l.token1 || token == l.token2;
    }

    function _decimalsOf(address token) private view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.token0) d = l.decimals0;
        else if (token == l.token1) d = l.decimals1;
        else if (token == l.token2) d = l.decimals2;
        else revert InvalidPoolToken();
        if (d == 0) d = 18;
    }

    function _seOf(address token) private view returns (address) {
        return Repo._seAt(Repo._layout(), Repo._indexOf(Repo._layout(), token));
    }

    function _rpOf(address token) private view returns (address) {
        return Repo._rpAt(Repo._layout(), Repo._indexOf(Repo._layout(), token));
    }

    function _spendableSeShares(address token) private view returns (uint256) {
        address se = _seOf(token);
        if (se == address(0)) return 0;
        uint256 held = IERC20(se).balanceOf(address(this));
        return held > 1 ? held - 1 : 0;
    }

    function invertBufferForEffective(address se, address rp, address token, uint256 dInNative)
        external view returns (uint256 amountInRaw)
    {
        if (dInNative == 0) return 0;
        BufferClaimQuote memory quote = bufferClaimQuote(se, rp, token, address(this));
        return _invertBufferForEffective(quote, dInNative);
    }

    function _invertBufferForEffective(BufferClaimQuote memory quote, uint256 dInNative) private view returns (uint256) {
        if (dInNative == 0) return 0;
        uint256 hi = dInNative * 2 + 1;
        uint256 above = previewBufferClaimIn(quote, hi);
        uint256 guard;
        while (above < dInNative && guard < 64) {
            hi = hi * 2;
            above = previewBufferClaimIn(quote, hi);
            unchecked { ++guard; }
        }
        if (above < dInNative) revert SeInvertUnavailable();
        uint256 lo = 1;
        uint256 below;
        uint256 probes;
        while (lo < hi) {
            uint256 mid = lo + (hi - lo) / 2;
            if (above > below && probes < 8) {
                mid = lo - 1 + FullMath.mulDiv(dInNative - below, hi - lo + 1, above - below);
                mid = FullMath.max(lo, FullMath.min(mid, hi - 1));
                ++probes;
            }
            uint256 claim = previewBufferClaimIn(quote, mid);
            if (claim >= dInNative) { hi = mid; above = claim; }
            else { lo = mid + 1; below = claim; }
        }
        return lo;
    }

    /// @dev Immutable inputs to repeated previews against one unchanged SE book.
    struct BufferClaimQuote {
        address se;
        address token;
        uint256 rate;
        uint256 heldShares;
        uint256 heldClaim;
        bytes state;
    }

    function bufferClaimQuote(address se, address rp, address token, address hook)
        internal view returns (BufferClaimQuote memory quote)
    {
        quote.se = se;
        quote.token = token;
        // D60: a buffered leg always carries a rate provider (package init rejects an SE leg without one);
        // a raw leg may carry one. The hook never derives a rate from the SE's own quotes.
        if (rp != address(0)) quote.rate = getRateFailClosed(rp);
        else if (se != address(0)) revert RateProviderRequired();
        hook;
    }

    function previewBufferClaimIn(BufferClaimQuote memory quote, uint256 amountInRaw)
        internal view returns (uint256)
    {
        if (amountInRaw == 0 || quote.se == address(0)) return 0;
        if (quote.se == quote.token) return amountInRaw;
        uint256 sharesOut;
        if (quote.state.length == 0) sharesOut = IStandardExchangeIn(quote.se).previewExchangeIn(
            IERC20(quote.token), amountInRaw, IERC20(quote.se));
        else (,, sharesOut,) = Transition(quote.se).quoteTransition(quote.state, Transition.Operation.DepositExactIn, amountInRaw);
        if (sharesOut == 0) return amountInRaw;
        if (quote.rate == 0) revert RateProviderRequired();
        return ratedNative(sharesOut, quote.rate, quote.se, quote.token);
    }


    /// @notice D60: raw SE shares to the leg token's native units through a WAD rate of whole tokens per
    ///         whole share, honoring share and token decimals.
    function ratedNative(uint256 shares, uint256 rate, address se, address token) public view returns (uint256) {
        uint8 sd = IERC20Metadata(se).decimals();
        uint8 td = IERC20Metadata(token).decimals();
        if (sd >= td) return FullMath.mulDiv(shares, rate, 1e18 * (10 ** uint256(sd - td)));
        return FullMath.mulDiv(shares * (10 ** uint256(td - sd)), rate, 1e18);
    }

    /// @notice D60: inverse of `ratedNative`, rounding up.
    function sharesForNativeUp(uint256 native, uint256 rate, address se, address token) public view returns (uint256) {
        uint8 sd = IERC20Metadata(se).decimals();
        uint8 td = IERC20Metadata(token).decimals();
        if (sd >= td) return FullMath.mulDiv(native, 1e18 * (10 ** uint256(sd - td)), rate, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(native, 1e18, rate * (10 ** uint256(td - sd)), FullMath.Rounding.Ceil);
    }

    function getRateFailClosed(address rp) public view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        (bool ok, bytes memory data) = rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length < 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function effectiveNativeWithContext(address se, address rp, address token, uint256 rawReserve, uint256 held, address manager)
        public view returns (uint256)
    {
        if (se == address(0) || se == token) return effectiveNative(se, rp, token, rawReserve, held);
        if (held == 0) return 0;
        if (rp == address(0)) revert RateProviderRequired();
        return ratedNative(held, ContextQuote.rate(se, token, rp, manager), se, token);
    }

    function previewInputWithContext(address se, address rp, address token, uint256 amount, address manager)
        public view returns (uint256)
    {
        if (se == address(0) || se == token) return amount;
        (uint256 shares,) = ContextQuote.deposit(se, token, address(this), amount, manager);
        if (shares == 0) return amount;
        if (rp == address(0)) revert RateProviderRequired();
        return ratedNative(shares, ContextQuote.rate(se, token, rp, manager), se, token);
    }

    function previewOutputWithContext(address se, address rp, address token, uint256 budget, address manager)
        public view returns (uint256 assets, uint256 shares)
    {
        if (se == address(0) || budget == 0) return (budget, 0);
        if (rp == address(0)) revert RateProviderRequired();
        shares = sharesForNativeUp(budget, ContextQuote.rate(se, token, rp, manager), se, token);
        (assets,) = ContextQuote.redeem(se, token, address(this), shares, manager);
    }

    /// @notice SE claim of `seBal` shares → pool token (unwrap preview; fee-inclusive).
    function seClaimOf(address se, address token, uint256 seBal) internal view returns (uint256) {
        if (se == address(0) || seBal == 0) return 0;
        if (se == token) return seBal;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(token));
    }

    /// @notice Effective native reserve for a leg: raw face, or shares×rate, or SE claim.
    function effectiveNative(
        address se,
        address rp,
        address token,
        uint256 rawReserve,
        uint256 seBal
    ) public view returns (uint256) {
        // D60: raw leg = raw balance, times the rate when a provider is configured; buffered leg = shares x rate.
        if (se == address(0)) {
            return rp == address(0) ? rawReserve : (rawReserve * getRateFailClosed(rp)) / 1e18;
        }
        if (seBal == 0) return 0;
        if (rp == address(0)) revert RateProviderRequired();
        return ratedNative(seBal, getRateFailClosed(rp), se, token);
    }

    /// @notice Preview claim-in (effective native) from buffering `amountInRaw` pool tokens into SE.
    function previewBufferClaimIn(
        address se,
        address rp,
        address token,
        uint256 amountInRaw,
        address hook
    ) public view returns (uint256 dInNative) {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == token) return amountInRaw;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(token), amountInRaw, IERC20(se));
        if (sharesOut == 0) return amountInRaw;
        if (rp == address(0)) revert RateProviderRequired();
        hook;
        return ratedNative(sharesOut, getRateFailClosed(rp), se, token);
    }

    /// @notice Preview pool-token out from unwrapping SE shares that deliver `dOutNative` effective.
    function previewUnwrapForEffectiveOut(
        address se,
        address rp,
        address token,
        uint256 dOutNative
    ) public view returns (uint256 amountOutNative, uint256 sharesOut) {
        if (dOutNative == 0 || se == address(0)) return (0, 0);
        if (rp == address(0)) revert RateProviderRequired();
        uint256 rate = getRateFailClosed(rp);
        // ceil shares for exact effective out when selling; the unwrap amount is the SE's buffering quote
        sharesOut = sharesForNativeUp(dOutNative, rate, se, token);
        amountOutNative = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(token));
        return (amountOutNative, sharesOut);
    }

    /// @notice Preview pool-token out from burning `sharesOut` SE shares (pro-rata remove).
    function previewUnwrapShares(address se, address token, uint256 sharesOut)
        public
        view
        returns (uint256)
    {
        if (sharesOut == 0 || se == address(0)) return 0;
        if (se == token) return sharesOut;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(token));
    }

    /// @notice Shares needed so unwrap delivers at least `amountOutNative` pool tokens (exact-out).
    function invertUnwrapExactTokenOut(address se, address token, uint256 amountOutNative)
        public
        view
        returns (uint256 sharesIn)
    {
        if (amountOutNative == 0) return 0;
        if (se == token) return amountOutNative;
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(token), amountOutNative);
    }
}
