// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {WeirMathOracle} from "contracts/protocols/strategy/weir/test/oracles/WeirMathOracle.sol";
import {LiquidityAmounts} from "contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol";

contract OverflowProbe {
    function product(uint256 shares, uint256 liquidity) external pure returns (uint256) {
        return shares * liquidity;
    }

    function liquidity(uint160 price, uint160 lower, uint160 upper, uint256 amount0, uint256 amount1)
        external
        pure
        returns (uint128)
    {
        return LiquidityAmounts.getLiquidityForAmounts(price, lower, upper, amount0, amount1);
    }
}

contract WeirVaults_FuzzTest is Test {
    uint160 internal constant Q = uint160(2 ** 96);

    function test_AC47_fuzzOracleDomain(uint96 amount, uint96 liquidity) public pure {
        uint256 raw = bound(uint256(amount), 1, 1_000_000);
        uint128 liq = uint128(bound(uint256(liquidity), 1, 1_000_000));
        uint160 lower = Q / 2;
        uint160 upper = Q * 2;
        assertEq(LiquidityAmounts.getLiquidityForAmount0(lower, upper, raw), WeirMathOracle.l0(lower, upper, raw));
        assertEq(LiquidityAmounts.getLiquidityForAmount1(lower, upper, raw), WeirMathOracle.l1(lower, upper, raw));
        assertEq(LiquidityAmounts.getAmount0ForLiquidity(lower, upper, liq), WeirMathOracle.a0(lower, upper, liq));
        assertEq(LiquidityAmounts.getAmount1ForLiquidity(lower, upper, liq), WeirMathOracle.a1(lower, upper, liq));
        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(Q, lower, upper, raw, raw + 1),
            WeirMathOracle.liquidityForAmounts(Q, lower, upper, raw, raw + 1)
        );
    }

    function test_AC47_overflowBounds() public {
        uint160 lower = Q / 2;
        uint160 upper = Q * 2;
        OverflowProbe probe = new OverflowProbe();
        vm.expectRevert(bytes("liquidity overflow"));
        probe.liquidity(Q, lower, upper, 2 ** 127, 1);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        probe.product(2 ** 236, 2 ** 20);
    }
}
