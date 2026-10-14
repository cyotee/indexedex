// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib as DepositQuoteLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookCommon} from "./UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase is
    NativeStandardYieldQuoteBase, UniswapV4DualStandardExchangeBufferConstantProductHookCommon
{
    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            return address(tokenOut) == address(this)
                ? _previewLiquidityJoin(address(tokenIn), amountIn)
                : _previewLiquidityExit(address(tokenOut), amountIn);
        }
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactIn(zfo, amountIn);
    }

    function _previewLiquidityJoin(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        if (!_isLive() || amountIn == 0) return 0;
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            (bool supported, uint256 projected) = DepositQuoteLib.preview(tokenIn, amountIn);
            if (supported) return projected;
            address pair = Repo._layout().legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = IStandardExchangeIn(tokenIn).previewExchangeIn(
                IERC20(tokenIn), amountIn, IERC20(pair)
            );
            if (pairOut == 0) return 0;
            return _previewDepositSingle(pair, pairOut);
        }
        return _previewDepositSingle(tokenIn, amountIn);
    }

    function _previewLiquidityExit(address tokenOut, uint256 sharesIn) internal view returns (uint256) {
        if (sharesIn == 0 || !_isLive()) return 0;
        return _previewExitSingleAsset(tokenOut, sharesIn);
    }

    struct ExitQuoteLeg {
        address se;
        bytes state;
        uint256 assets;
        uint256 withdrawn;
    }

    function _previewExitSingleAsset(address tokenOut, uint256 sharesIn)
        internal view returns (uint256 amountOut)
    {
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        Repo.Layout storage l = Repo._layout();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        bool outIs0 = pair == l.currency0;
        if (!outIs0 && pair != l.currency1) return 0;
        address other = outIs0 ? l.currency1 : l.currency0;
        if (ClaimLib.supportsTransitionQuote(_seFor(pair), pair, address(this))
            && ClaimLib.supportsTransitionQuote(_seFor(other), other, address(this))) {
            return _previewSequentialExit(pair, other, sharesIn, asShare);
        }
        amountOut = _previewFallbackExit(pair, sharesIn, outIs0);
        if (asShare && amountOut > 0) {
            amountOut = IStandardExchangeIn(tokenOut).previewExchangeIn(IERC20(pair), amountOut, IERC20(tokenOut));
        }
    }

    function _previewFallbackExit(address pair, uint256 sharesIn, bool outIs0)
        private view returns (uint256)
    {
        // Quote only the proportional withdraw; execution's residual swap is extra output.
        pair;
        (uint256 a0, uint256 a1) = _previewWithdraw(sharesIn);
        return outIs0 ? a0 : a1;
    }

    function _previewSequentialExit(address pair, address other, uint256 sharesIn, bool asShare)
        private view returns (uint256 amountOut)
    {
        uint256 supply = _supplyAfterProtocolMint();
        ExitQuoteLeg memory output = _previewWithdrawLeg(pair, sharesIn, supply);
        ExitQuoteLeg memory input = _previewWithdrawLeg(other, sharesIn, supply);
        amountOut = output.withdrawn + _projectExitResidual(input, output, other, pair);
        if (asShare && amountOut > 0) {
            (,, amountOut,) = Transition(output.se).quoteTransition(
                output.state, Transition.Operation.DepositExactIn, amountOut
            );
        }
    }

    function _projectExitResidual(ExitQuoteLeg memory input, ExitQuoteLeg memory output, address tokenIn, address tokenOut)
        private view returns (uint256 received)
    {
        if (input.withdrawn == 0) return 0;
        uint256 claimIn = ClaimLib.projectedBufferClaimIn(input.se, input.state, input.withdrawn);
        uint256 budget = _exitSaleQuote(tokenIn, tokenOut, claimIn,
            ClaimLib.ratedReserveOfState(input.se, input.state), ClaimLib.ratedReserveOfState(output.se, output.state));
        ClaimLib.OutputQuote memory quote;
        bytes memory next;
        (quote, next) = ClaimLib.projectOutputExactIn(output.se, output.state, budget);
        if (quote.amount == 0) return 0;
        (input.state,,,) = Transition(input.se).quoteTransition(input.state, Transition.Operation.DepositExactIn, input.withdrawn);
        output.state = next;
        return quote.amount;
    }

    function _previewWithdrawLeg(address pair, uint256 sharesIn, uint256 supply)
        private view returns (ExitQuoteLeg memory leg)
    {
        leg.se = _seFor(pair);
        (leg.state, leg.assets) = Transition(leg.se).quoteState(pair, address(this));
        uint256 seOut = FullMath.mulDiv(IERC20(leg.se).balanceOf(address(this)), sharesIn, supply);
        if (seOut > 0) {
            (leg.state,, leg.withdrawn, leg.assets) = Transition(leg.se).quoteTransition(
                leg.state, Transition.Operation.RedeemExactIn, seOut
            );
        }
    }

    function _exitSaleQuote(address tokenIn, address tokenOut, uint256 claimIn, uint256 reserveIn, uint256 reserveOut)
        private view returns (uint256)
    {
        if (claimIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;
        uint8 decimalsIn = _decimalsOf(tokenIn);
        uint8 decimalsOut = _decimalsOf(tokenOut);
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, decimalsIn), Math.toWad(reserveIn, decimalsIn), Math.toWad(reserveOut, decimalsOut)
        ), decimalsOut);
    }
}
