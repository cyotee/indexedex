// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {SlipstreamStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol";

contract SlipstreamStandardExchangeOutTarget is SlipstreamStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using BetterSafeERC20 for IERC20;

    struct ZapOutState {
        uint256 totalShares;
        address token0;
        address token1;
        uint256 outBalanceBefore;
        uint256 amount0;
        uint256 amount1;
        uint256 actualOut;
    }

    error SlipstreamExchangeOut_DeadlineExceeded();
    error SlipstreamExchangeOut_InsufficientOutput();
    error SlipstreamExchangeOut_ZeroShares();
    error SlipstreamExchangeOut_SlippageExceeded();

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        override
        returns (uint256 amountIn)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(tokenOut, amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amountIn) {
        if (deadline < block.timestamp) revert SlipstreamExchangeOut_DeadlineExceeded();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            amountIn = _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
            if (amountIn > maxAmountIn) revert SlipstreamExchangeOut_InsufficientOutput();

            _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            _swap(address(tokenIn), address(tokenOut), amountIn, amountOut, recipient);
            _refundExcess(tokenIn, maxAmountIn, amountIn, pretransferred, msg.sender);
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _executeZapOutWithdrawal(tokenOut, maxAmountIn, amountOut, recipient, pretransferred);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function _previewZapOutWithdrawal(IERC20 tokenOut, uint256 desiredAmountOut)
        internal
        view
        returns (uint256 sharesRequired)
    {
        if (desiredAmountOut == 0) revert SlipstreamExchangeOut_ZeroShares();

        uint256 totalShares = IERC20(address(this)).totalSupply();
        if (totalShares == 0 || !SlipstreamVaultRepo._isPositionCreated()) revert SlipstreamExchangeOut_ZeroShares();

        uint256 low = 1;
        uint256 high = totalShares;

        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            uint256 quotedAmountOut = _quoteZapOutAmount(tokenOut, mid, totalShares);
            if (quotedAmountOut >= desiredAmountOut) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (high < totalShares) {
            uint256 buffer = high / 100;
            if (buffer == 0) {
                buffer = 1;
            }
            uint256 buffered = high + buffer;
            return buffered > totalShares ? totalShares : buffered;
        }
        return high;
    }

    function _quoteZapOutAmount(IERC20 tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        address token0 = _pool().token0();
        if (address(tokenOut) == token0) {
            return amount0 + _quoteSwap(_pool().token1(), token0, amount1);
        }
        return amount1 + _quoteSwap(token0, _pool().token1(), amount0);
    }

    function _executeZapOutWithdrawal(
        IERC20 tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 sharesBurned) {
        ZapOutState memory state;
        _collectManagedFees();

        state.totalShares = IERC20(address(this)).totalSupply();
        sharesBurned = _previewZapOutWithdrawal(tokenOut, minAmountOut);
        if (sharesBurned == 0 || sharesBurned > maxSharesToBurn) revert SlipstreamExchangeOut_InsufficientOutput();

        state.token0 = _pool().token0();
        state.token1 = _pool().token1();
        state.outBalanceBefore = IERC20(address(tokenOut)).balanceOf(address(this));

        (state.amount0, state.amount1) = _burnManagedLiquidity(sharesBurned, state.totalShares);

        if (address(tokenOut) == state.token0 && state.amount1 > 0) {
            _swap(state.token1, state.token0, state.amount1, 0, address(this));
        } else if (address(tokenOut) == state.token1 && state.amount0 > 0) {
            _swap(state.token0, state.token1, state.amount0, 0, address(this));
        }

        _updateManagedPositionLiquidities();

        state.actualOut = IERC20(address(tokenOut)).balanceOf(address(this)) - state.outBalanceBefore;
        if (state.actualOut < minAmountOut) revert SlipstreamExchangeOut_SlippageExceeded();

        if (pretransferred) {
            ERC20Repo._burn(address(this), sharesBurned);
            if (maxSharesToBurn > sharesBurned) {
                ERC20Repo._transfer(address(this), msg.sender, maxSharesToBurn - sharesBurned);
            }
        } else {
            ERC20Repo._burn(msg.sender, sharesBurned);
        }

        IERC20(address(tokenOut)).safeTransfer(recipient, state.actualOut);
    }

    function _burnManagedLiquidity(uint256 sharesBurned, uint256 totalShares)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 center0, uint256 center1) =
            _burnPositionLiquidity(SlipstreamVaultRepo.PositionKind.Center, sharesBurned, totalShares);
        (uint256 lower0, uint256 lower1) =
            _burnPositionLiquidity(SlipstreamVaultRepo.PositionKind.LowerWing, sharesBurned, totalShares);
        (uint256 upper0, uint256 upper1) =
            _burnPositionLiquidity(SlipstreamVaultRepo.PositionKind.UpperWing, sharesBurned, totalShares);

        amount0 = center0 + lower0 + upper0;
        amount1 = center1 + lower1 + upper1;
    }

    function _burnPositionLiquidity(
        SlipstreamVaultRepo.PositionKind kind_,
        uint256 sharesBurned,
        uint256 totalShares
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint128 currentLiquidity = _getPositionLiquidityFromPool(kind_);
        if (currentLiquidity == 0 || totalShares == 0) {
            return (0, 0);
        }

        uint128 liquidityToBurn = uint128((sharesBurned * currentLiquidity) / totalShares);
        if (liquidityToBurn == 0) {
            return (0, 0);
        }

        (int24 tickLower, int24 tickUpper) = SlipstreamVaultRepo._getPositionTicks(kind_);
        return _burnAndCollect(tickLower, tickUpper, liquidityToBurn);
    }

    function _burnAndCollect(int24 tickLower, int24 tickUpper, uint128 liquidityToBurn)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        uint256 bal0Before = IERC20(token0).balanceOf(address(this));
        uint256 bal1Before = IERC20(token1).balanceOf(address(this));

        pool.burn(tickLower, tickUpper, liquidityToBurn);
        pool.collect(address(this), tickLower, tickUpper, type(uint128).max, type(uint128).max);

        amount0 = IERC20(token0).balanceOf(address(this)) - bal0Before;
        amount1 = IERC20(token1).balanceOf(address(this)) - bal1Before;
    }

    function _refundExcess(
        IERC20 token,
        uint256 maxAmount,
        uint256 usedAmount,
        bool pretransferred,
        address recipient
    ) internal {
        if (pretransferred && maxAmount > usedAmount) {
            token.safeTransfer(recipient, maxAmount - usedAmount);
        }
    }
}
