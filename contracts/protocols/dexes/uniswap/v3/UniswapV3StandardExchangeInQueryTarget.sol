// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {UniswapV3ZapQuoter} from "@crane/contracts/utils/math/UniswapV3ZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {UniswapV3PoolAwareRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3PoolAwareRepo.sol";
import {UniswapV3VaultRepo} from "contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol";
import {
    UniswapV3StandardExchangeCommon
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol";

/**
 * @title UniswapV3StandardExchangeInQueryTarget
 * @notice View-only exchange-in previews (size split from mutate facet).
 */
abstract contract UniswapV3StandardExchangeInQueryTarget is UniswapV3StandardExchangeCommon {
    error UniswapV3ExchangeIn_ZeroDeposit();

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        IUniswapV3Pool pool = UniswapV3PoolAwareRepo._uniswapV3Pool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(tokenIn, amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _previewZapInDeposit(IERC20 tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) revert UniswapV3ExchangeIn_ZeroDeposit();

        IUniswapV3Pool pool = UniswapV3PoolAwareRepo._uniswapV3Pool();
        bool zeroForOne = address(tokenIn) == pool.token0();
        bool initialDeposit = !UniswapV3VaultRepo._isPositionCreated();
        ManagedTicks memory managedTicks = _managedTicks();
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();

        UniswapV3ZapQuoter.ZapInQuote memory quote = UniswapV3ZapQuoter.quoteZapInSingleCore(
            UniswapV3ZapQuoter.ZapInParams({
                pool: pool,
                tickLower: managedTicks.centerLower,
                tickUpper: managedTicks.centerUpper,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                sqrtPriceLimitX96: 0,
                maxSwapSteps: 0,
                searchIters: 20
            })
        );

        uint256 available0;
        uint256 available1;
        if (zeroForOne) {
            available0 = amountIn - quote.swap.amountIn;
            available1 = quote.swap.amountOut;
        } else {
            available0 = quote.swap.amountOut;
            available1 = amountIn - quote.swap.amountIn;
        }

        (uint160 currentSqrtPriceX96,,,,,,) = pool.slot0();
        uint160 priceForMint = quote.swapAmountIn > 0 ? quote.swap.sqrtPriceAfterX96 : currentSqrtPriceX96;
        ManagedLiquidityPlan memory plan =
            _managedLiquidityPlanAtState(managedTicks, available0, available1, priceForMint);

        if (initialDeposit || totalShares == 0) {
            return plan.amount0Used + plan.amount1Used;
        }

        return ConstProdUtils._depositQuote(plan.amount0Used, plan.amount1Used, totalShares, reserve0, reserve1);
    }
}
