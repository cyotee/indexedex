// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LiquidityAmounts} from "../../libraries/LiquidityAmounts.sol";

contract WeirLiquidityAmountsExposure {
    function liquidityForAmount0(uint160 a, uint160 b, uint256 amount) external pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmount0(a, b, amount);
    }

    function liquidityForAmount1(uint160 a, uint160 b, uint256 amount) external pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmount1(a, b, amount);
    }

    function liquidityForAmounts(uint160 p, uint160 a, uint160 b, uint256 amount0, uint256 amount1)
        external
        pure
        returns (uint128)
    {
        return LiquidityAmounts.getLiquidityForAmounts(p, a, b, amount0, amount1);
    }

    function amount0ForLiquidity(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return LiquidityAmounts.getAmount0ForLiquidity(a, b, liquidity);
    }

    function amount1ForLiquidity(uint160 a, uint160 b, uint128 liquidity) external pure returns (uint256) {
        return LiquidityAmounts.getAmount1ForLiquidity(a, b, liquidity);
    }

    function amountsForLiquidity(uint160 p, uint160 a, uint160 b, uint128 liquidity)
        external
        pure
        returns (uint256, uint256)
    {
        return LiquidityAmounts.getAmountsForLiquidity(p, a, b, liquidity);
    }
}
