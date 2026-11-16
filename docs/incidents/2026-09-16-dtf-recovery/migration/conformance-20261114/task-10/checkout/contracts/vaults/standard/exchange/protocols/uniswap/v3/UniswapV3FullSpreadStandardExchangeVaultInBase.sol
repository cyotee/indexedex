// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {StandardExchangeConstantProduct} from "../StandardExchangeConstantProduct.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {UniswapV3FullSpreadStandardExchangeVaultRepo} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultCommon
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {
    IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";

abstract contract UniswapV3FullSpreadStandardExchangeVaultInBase is NativeStandardYieldQuoteBase, UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers {
    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256 amountOut)
    {
        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            if (!canOpenBoundPoolOps()) {
                revert UniswapV3Exchange_BoundPoolInteractionBlocked();
            }
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(address(tokenIn), amountIn);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutExactIn(address(tokenOut), amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    error UniswapV3ExchangeIn_DeadlineExceeded();
    error UniswapV3ExchangeIn_SlippageExceeded();
    error UniswapV3ExchangeIn_ZeroDeposit();

    function _executeDirectSwapIn(address tokenIn, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn == _token0();
        address tokenOut = zeroForOne ? _token1() : _token0();
        amountOut = _swap(tokenIn, tokenOut, amountIn, 0, recipient);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _previewZapInDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) {
            return 0;
        }
        uint256 amount0Added = tokenIn == _token0() ? amountIn : 0;
        uint256 amount1Added = tokenIn == _token1() ? amountIn : 0;
        uint256 totalShares = ERC20Repo._totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return _sharesOutForDeposit(amount0Added, amount1Added, totalShares, reserve0, reserve1);
    }

    function _executeZapInDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        returns (uint256 sharesOut)
    {
        if (amountIn == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }

        _collectIfIdle();

        uint256 amount0Added = tokenIn == _token0() ? amountIn : 0;
        uint256 amount1Added = tokenIn == _token1() ? amountIn : 0;
        uint256 totalSharesBefore = ERC20Repo._totalSupply();

        (uint256 total0, uint256 total1) = _totalVaultReservesForShareMath();
        uint256 reserve0Before = total0 - amount0Added;
        uint256 reserve1Before = total1 - amount1Added;

        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
        if (sharesOut == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }
        if (sharesOut < minSharesOut) revert UniswapV3ExchangeIn_SlippageExceeded();

        if (totalSharesBefore == 0) {
            ERC20Repo._mint(DEAD_SHARES_SINK, _minimumLiquidity());
            uint256 residual = _initialResidualShares(amount0Added, amount1Added, reserve0Before, reserve1Before, sharesOut);
            if (residual > 0) {
                ERC20Repo._mint(DEAD_SHARES_SINK, residual);
            }
        }

        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();

        if (canOpenBoundPoolOps()) {
            _rebalanceLiquidReserveBestEffort();
        } else {
            emit IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(tokenIn, amountIn, sharesOut);
        }
    }

    function _previewZapInDualDeposit(uint256 amount0Added, uint256 amount1Added)
        internal
        view
        returns (uint256 sharesOut)
    {
        if (amount0Added == 0 || amount1Added == 0) {
            return 0;
        }
        uint256 totalShares = ERC20Repo._totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return _sharesOutForDeposit(amount0Added, amount1Added, totalShares, reserve0, reserve1);
    }

    function _executeZapInDualDeposit(
        uint256 amount0Added,
        uint256 amount1Added,
        uint256 minSharesOut,
        address recipient
    ) internal returns (uint256 sharesOut) {
        if (amount0Added == 0 || amount1Added == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }

        _collectIfIdle();

        uint256 totalSharesBefore = ERC20Repo._totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReservesForShareMath();
        uint256 reserve0Before = total0 - amount0Added;
        uint256 reserve1Before = total1 - amount1Added;

        sharesOut = _sharesOutForDeposit(amount0Added, amount1Added, totalSharesBefore, reserve0Before, reserve1Before);
        if (sharesOut == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }
        if (sharesOut < minSharesOut) revert UniswapV3ExchangeIn_SlippageExceeded();

        if (totalSharesBefore == 0) {
            ERC20Repo._mint(DEAD_SHARES_SINK, _minimumLiquidity());
            uint256 residual = _initialResidualShares(amount0Added, amount1Added, reserve0Before, reserve1Before, sharesOut);
            if (residual > 0) {
                ERC20Repo._mint(DEAD_SHARES_SINK, residual);
            }
        }

        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();

        if (canOpenBoundPoolOps()) {
            _rebalanceLiquidReserveBestEffort();
        } else {
            emit IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(_token0(), amount0Added, sharesOut);
            emit IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.LocalDepositWhileBlocked(_token1(), amount1Added, sharesOut);
        }
    }

    function _quoteSleeveZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return tokenOut == _token0()
            ? StandardExchangeConstantProduct._singleExit(reserve0, reserve1, sharesBurned, totalShares)
            : StandardExchangeConstantProduct._singleExit(reserve1, reserve0, sharesBurned, totalShares);
    }

    function _quoteZapOutAmount(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        view
        virtual
        returns (uint256 amountOut)
    {
        (uint256 amount0, uint256 amount1) = _quoteManagedWithdrawal(sharesBurned, totalShares);
        (uint256 free0, uint256 free1) = _freeBalancesForShareMath();
        amount0 += (free0 * sharesBurned) / totalShares;
        amount1 += (free1 * sharesBurned) / totalShares;
        if (tokenOut == _token0()) {
            return amount0 + (amount1 > 0 ? _quoteSwapAfterWithdrawal(amount1, false, sharesBurned, totalShares) : 0);
        }
        return amount1 + (amount0 > 0 ? _quoteSwapAfterWithdrawal(amount0, true, sharesBurned, totalShares) : 0);
    }

    function _previewZapOutExactIn(address tokenOut, uint256 sharesBurned) internal view returns (uint256 amountOut) {
        if (sharesBurned == 0) {
            return 0;
        }
        uint256 totalShares = ERC20Repo._totalSupply();
        if (totalShares == 0) {
            return 0;
        }
        if (!canOpenBoundPoolOps()) {
            return _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
        }
        return _quoteZapOutAmount(tokenOut, sharesBurned, totalShares);
    }

    function _executeZapOutExactIn(
        address tokenOut,
        uint256 sharesBurned,
        uint256 minAmountOut,
        address recipient,
        address holder_
    ) internal returns (uint256 amountOut) {
        if (sharesBurned == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }
        uint256 totalShares = ERC20Repo._totalSupply();
        if (totalShares == 0) {
            revert UniswapV3Exchange_ZeroAmount();
        }

        if (!canOpenBoundPoolOps()) {
            amountOut = _quoteSleeveZapOutAmount(tokenOut, sharesBurned, totalShares);
            uint256 freeOut = IERC20(tokenOut).balanceOf(address(this));
            if (amountOut == 0 || freeOut < amountOut) {
                revert UniswapV3Exchange_InsufficientLocalReserve(
                    tokenOut, amountOut == 0 ? minAmountOut : amountOut, freeOut
                );
            }
            if (amountOut < minAmountOut) revert UniswapV3ExchangeIn_SlippageExceeded();
            ERC20Repo._burn(holder_, sharesBurned);
            _transferCurrency(tokenOut, recipient, amountOut);
            _syncVaultReserves();
            return amountOut;
        }

        return _executeFreeZapOutExactIn(tokenOut, sharesBurned, totalShares, minAmountOut, recipient, holder_);
    }

    function _executeFreeZapOutExactIn(
        address tokenOut,
        uint256 sharesBurned,
        uint256 totalShares,
        uint256 minAmountOut,
        address recipient,
        address holder_
    ) internal returns (uint256 amountOut) {
        _collectManagedFees();
        amountOut = _idleZapOutCore(tokenOut, sharesBurned, totalShares);
        if (amountOut < minAmountOut) revert UniswapV3ExchangeIn_SlippageExceeded();

        ERC20Repo._burn(holder_, sharesBurned);
        _transferCurrency(tokenOut, recipient, amountOut);
        _syncVaultReserves();
        _rebalanceLiquidReserveBestEffort();
    }

    function _idleZapOutCore(address tokenOut, uint256 sharesBurned, uint256 totalShares)
        internal
        returns (uint256 amountOut)
    {
        bool outIsToken0 = tokenOut == _token0();
        address otherToken = outIsToken0 ? _token1() : _token0();
        (uint256 free0, uint256 free1) = _freeBalances();
        uint256 freePortionOther =
            outIsToken0 ? (free1 * sharesBurned) / totalShares : (free0 * sharesBurned) / totalShares;
        uint256 freeOutShare = outIsToken0 ? (free0 * sharesBurned) / totalShares : (free1 * sharesBurned) / totalShares;
        uint256 otherBefore = IERC20(otherToken).balanceOf(address(this));
        uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));
        _burnCenterLiquidityForShares(sharesBurned, totalShares);
        _swapRemovedOtherPlusFreeShare(otherToken, tokenOut, freePortionOther, otherBefore);
        return _actualOutPlusFreeShare(tokenOut, outBefore, freeOutShare);
    }
}
