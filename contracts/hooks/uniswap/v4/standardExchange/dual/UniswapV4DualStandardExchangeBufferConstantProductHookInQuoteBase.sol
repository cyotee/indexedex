// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib as DepositQuoteLib} from "./UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookCommon} from "./UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase is
    NativeStandardYieldQuoteBase, UniswapV4DualStandardExchangeBufferConstantProductHookCommon
{
    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256)
    {
        _requireQueryUnlocked();
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            return address(tokenOut) == address(this)
                ? _previewLiquidityJoin(address(tokenIn), amountIn)
                : _previewLiquidityExit(address(tokenOut), amountIn);
        }
        return _previewSwapExactIn(_routeZeroForOne(address(tokenIn), address(tokenOut)), amountIn);
    }

    function _previewLiquidityJoin(address tokenIn, uint256 amountIn) internal view returns (uint256 shares) {
        if (!_isZapEligible() || amountIn == 0) return 0;
        if (_classify(tokenIn) == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        (, shares) = DepositQuoteLib.preview(tokenIn, amountIn);
    }

    function _previewLiquidityExit(address tokenOut, uint256 sharesIn) internal view returns (uint256) {
        if (sharesIn == 0 || !_isLive()) return 0;
        return _previewExitSingleAsset(tokenOut, sharesIn);
    }

    function _previewExitSingleAsset(address tokenOut, uint256 sharesIn) internal view returns (uint256) {
        if (_classify(tokenOut) == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        return DepositQuoteLib.previewExit(tokenOut, sharesIn);
    }
}
