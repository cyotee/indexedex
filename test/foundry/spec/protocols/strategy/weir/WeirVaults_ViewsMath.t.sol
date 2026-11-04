// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {LiquidityAmounts} from "contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol";

contract Exposure {
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

contract WeirVaults_ViewsMathTest is Test {
    uint256 internal constant Q = 2 ** 96;

    function test_oracleAgreesWithCanonicalFullMath() public pure {
        uint256[4] memory xs = [uint256(1), 20, 2 ** 20, 2 ** 128 - 1];
        uint256[4] memory ds = [uint256(1), 3, 2 ** 20, 2 ** 96];
        for (uint256 i; i < xs.length; i++) {
            for (uint256 j; j < xs.length; j++) {
                for (uint256 k; k < ds.length; k++) {
                    uint256 expected = FullMath.mulDiv(xs[i], xs[j], ds[k]);
                    assertEq(WeirMathOracle.md(xs[i], xs[j], ds[k]), expected);
                }
            }
        }
        assertEq(WeirMathOracle.md(2 ** 200, 2 ** 50, 2 ** 20), FullMath.mulDiv(2 ** 200, 2 ** 50, 2 ** 20));
    }

    function test_AC42_boundsOrderedAndReversed() public {
        Exposure exposure = new Exposure();
        uint160 a = uint160(Q);
        uint160 b = uint160(Q * 2);
        assertEq(exposure.liquidityForAmount0(a, b, 3), 6);
        assertEq(exposure.liquidityForAmount1(a, b, 3), 3);
        assertEq(exposure.liquidityForAmount0(b, a, 3), 6);
        assertEq(exposure.liquidityForAmount1(b, a, 3), 3);
        assertEq(exposure.amount0ForLiquidity(a, b, 7), 3);
        assertEq(exposure.amount1ForLiquidity(a, b, 7), 7);
        assertEq(WeirMathOracle.l0(a, b, 3), 6);
        assertEq(WeirMathOracle.l1(a, b, 3), 3);
        assertEq(WeirMathOracle.a0(a, b, 7), 3);
        assertEq(WeirMathOracle.a1(a, b, 7), 7);
    }

    function test_AC43_interiorMin() public {
        Exposure exposure = new Exposure();
        uint160 lower = uint160(Q / 2);
        uint160 upper = uint160(Q * 2);
        uint160 price = uint160(Q);
        assertEq(exposure.liquidityForAmounts(price, lower, upper, 3, 4), 6);
        (uint256 amount0, uint256 amount1) = exposure.amountsForLiquidity(price, lower, upper, 7);
        assertEq(amount0, 3);
        assertEq(amount1, 3);
        assertEq(WeirMathOracle.liquidityForAmounts(price, lower, upper, 3, 4), 6);
        assertEq(exposure.liquidityForAmounts(lower, lower, upper, 3, 4), WeirMathOracle.l0(lower, upper, 3));
        assertEq(exposure.liquidityForAmounts(upper, lower, upper, 3, 4), WeirMathOracle.l1(lower, upper, 4));
    }

    function test_AC44_overflowBranch() public {
        Exposure exposure = new Exposure();
        uint160 price = uint160(Q);
        uint160 lower = uint160(Q / 2);
        uint160 upper = uint160(Q * 2);
        vm.expectRevert(bytes("liquidity overflow"));
        exposure.liquidityForAmounts(price, lower, upper, 2 ** 127, 1);
        vm.expectRevert(bytes("liquidity overflow"));
        exposure.liquidityForAmounts(price, lower, upper, 1, 2 ** 127);
    }

    function test_AC45_equalBoundsAndDivByZero() public {
        Exposure exposure = new Exposure();
        vm.expectRevert(bytes(""));
        exposure.liquidityForAmount0(uint160(Q), uint160(Q), 1);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x12));
        exposure.amount0ForLiquidity(0, uint160(Q), 1);
    }
}
