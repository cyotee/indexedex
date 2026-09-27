// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";
import {SlipstreamZapQuoter} from "@crane/contracts/utils/math/SlipstreamZapQuoter.sol";
import {ConstProdUtils} from "@crane/contracts/utils/math/ConstProdUtils.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SlipstreamPoolAwareRepo} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol";
import {SlipstreamVaultRepo} from "contracts/vaults/slipstream/SlipstreamVaultRepo.sol";
import {SlipstreamStandardExchangeCommon} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol";

/// @dev D19 Ext: preview selectors only. Core `exchangeIn` stays on `SlipstreamStandardExchangeInTarget`.
contract SlipstreamStandardExchangeInTargetExt is SlipstreamStandardExchangeCommon {
    error SlipstreamExchangeIn_ZeroDeposit();

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        address token0 = pool.token0();
        address token1 = pool.token1();

        if ((address(tokenIn) == token0 && address(tokenOut) == token1)
            || (address(tokenIn) == token1 && address(tokenOut) == token0)) {
            return _quoteSwap(address(tokenIn), address(tokenOut), amountIn);
        }

        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            return _previewZapInDeposit(tokenIn, amountIn);
        }

        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }

    function _previewZapInDeposit(IERC20 tokenIn, uint256 amountIn) internal view returns (uint256 sharesOut) {
        if (amountIn == 0) revert SlipstreamExchangeIn_ZeroDeposit();

        ICLPool pool = SlipstreamPoolAwareRepo._slipstreamPool();
        bool zeroForOne = address(tokenIn) == pool.token0();
        bool initialDeposit = !SlipstreamVaultRepo._isPositionCreated();
        ManagedTicks memory managedTicks = _managedTicks();
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();

        SlipstreamZapQuoter.ZapInQuote memory quote = SlipstreamZapQuoter.quoteZapInSingleCore(
            SlipstreamZapQuoter.createZapInParams(
                pool,
                managedTicks.centerLower,
                managedTicks.centerUpper,
                address(tokenIn),
                amountIn,
                0,
                0,
                20,
                true
            )
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

        (uint160 currentSqrtPriceX96,,,,,) = pool.slot0();
        uint160 priceForMint = quote.swapAmountIn > 0 ? quote.swap.sqrtPriceAfterX96 : currentSqrtPriceX96;
        ManagedLiquidityPlan memory plan =
            _managedLiquidityPlanAtState(managedTicks, available0, available1, priceForMint);

        if (initialDeposit || totalShares == 0) {
            return plan.amount0Used + plan.amount1Used;
        }

        return ConstProdUtils._depositQuote(plan.amount0Used, plan.amount1Used, totalShares, reserve0, reserve1);
    }
}
