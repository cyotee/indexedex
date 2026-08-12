// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookSeTarget is UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactIn(zfo, amountIn);
    }


    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (recipient == address(0)) revert ZeroAddress();
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        // Quote on pre-pull book so inventory does not reprice the trade mid-path.
        amountOut = _previewSwapExactIn(zfo, amountIn);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        // L-GAPS-11 / ISecurePullErrors: pretransfer credits claimed only when in-window
        // delta covers it — blocks free extract of dual SE book / pair inventory. Leftover
        // spendable economics unchanged (surplus delta not exact-matched).
        _securePull(IERC20(address(tokenIn)), amountIn, pretransferred);
        _executeBookSwap(zfo, amountIn, amountOut, recipient);
    }


    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _previewSwapExactOut(zfo, amountOut);
    }


    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        if (recipient == address(0)) revert ZeroAddress();
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        amountIn = _previewSwapExactOut(zfo, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();
        // L-GAPS-11: delta-gate claimed amountIn. Refund only in-window surplus above amountIn
        // (never absolute maxAmountIn - amountIn from free inventory / SE book).
        uint256 observedDelta = _securePull(IERC20(address(tokenIn)), amountIn, pretransferred);
        if (pretransferred && observedDelta > amountIn) {
            IERC20(address(tokenIn)).safeTransfer(msg.sender, observedDelta - amountIn);
        }
        _executeBookSwap(zfo, amountIn, amountOut, recipient);
    }


}
