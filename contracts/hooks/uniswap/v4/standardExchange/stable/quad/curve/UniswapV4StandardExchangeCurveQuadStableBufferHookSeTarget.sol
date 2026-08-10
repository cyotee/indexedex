// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget
 * @notice SE In/Out swap-only surface (rated StableSwap book, internal settle).
 * @dev MultiAssetLiquidity selectors live on LiquidityFacet (same functions as product join/exit).
 *      L-GAPS-11: pretransfer credits only in-window delta (ISecurePullErrors) — leftover not free-spent.
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget is
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget,
    IStandardExchangeIn,
    IStandardExchangeOut
{
    using SafeERC20 for IERC20;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);
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
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (tin == tout) revert IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute();
        _tokenIndex(tin);
        _tokenIndex(tout);

        // Quote on pre-intake book, then fund (L-GAPS-11 delta gate — no free leftover credit).
        amountOut = _previewSwapExactIn(tin, tout, amountIn);
        if (amountOut < minAmountOut) revert Slippage();

        _securePull(IERC20(tin), amountIn, pretransferred);

        uint8 j = _tokenIndex(tout);
        uint8 i = _tokenIndex(tin);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, recipient);
        } else {
            if (amountOut >= _nativeAt(j)) revert WouldZeroReserve();
            _debitRawIntentional(j, amountOut);
            IERC20(tout).safeTransfer(recipient, amountOut);
        }
        if (l.standardExchanges[i] != address(0)) {
            _bufferToken(i, amountIn);
        } else {
            // Credit intentional raw book after funded in.
            _creditRawIntentional(i, amountIn);
        }
        _syncVaultReserves();
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
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
        if (amountOut == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (tin == tout) revert IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute();
        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert Slippage();

        _securePull(IERC20(tin), amountIn, pretransferred);

        uint8 j = _tokenIndex(tout);
        uint8 ii = _tokenIndex(tin);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[j] != address(0)) {
            _unwrapExactTokenOut(j, amountOut, recipient);
        } else {
            if (amountOut >= _nativeAt(j)) revert WouldZeroReserve();
            _debitRawIntentional(j, amountOut);
            IERC20(tout).safeTransfer(recipient, amountOut);
        }
        if (l.standardExchanges[ii] != address(0)) {
            _bufferToken(ii, amountIn);
        } else {
            _creditRawIntentional(ii, amountIn);
        }
        _syncVaultReserves();
    }
}
