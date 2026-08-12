// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolCommon} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolCommon.sol";

contract CommonHarness is StandardExchangeBufferPoolCommon {
    function effectiveWeights(uint256 currentRate, uint256 baselineRate_)
        external pure returns (uint256 wTta, uint256 wShares)
    {
        return _effectiveWeights(currentRate, baselineRate_);
    }
}

contract StandardExchangeBufferPoolCommonTest is Test {
    CommonHarness internal harness;

    function setUp() public {
        harness = new CommonHarness();
    }

    function test_effectiveWeights_atBaseline_are5050() public view {
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(1e18, 1e18);
        assertEq(wTta, 0.5e18);
        assertEq(wShares, 0.5e18);
    }

    function test_effectiveWeights_sumToOne_andTrackRatio() public view {
        // rate 20% above baseline: ratio = 1.2, wShares = 1.2/2.2
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(1.2e18, 1e18);
        assertEq(wShares, uint256(1.2e18) * 1e18 / 2.2e18);
        assertEq(wTta + wShares, 1e18);
        // Ratio identity: wShares/wTta == rate/baseline (to rounding)
        assertApproxEqRel(uint256(wShares) * 1e18 / wTta, 1.2e18, 1e6);
    }

    function test_effectiveWeights_nonUnitBaseline() public view {
        // Same ratio expressed with a non-1e18 baseline (e.g. decimal-offset SE rates)
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(6e8, 5e8); // ratio 1.2
        assertEq(wShares, uint256(1.2e18) * 1e18 / 2.2e18);
        assertEq(wTta + wShares, 1e18);
    }

    function test_effectiveWeights_revertsBelowMinWeight() public {
        // ratio 100 → wShares = 100/101 ≈ 9.9e17
        // wTta = 1 - wShares ≈ 9.9e15 < 1% (1e16)
        // The exact calculation through Math.mulDiv:
        // wShares = mulDiv(100e18, 1e18, 101e18) = 990099009900990099
        // wTta = 1e18 - 990099009900990099 = 9900990099009901
        uint256 expectedWShares = 990099009900990099;
        uint256 expectedWTta = 1e18 - expectedWShares;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeBufferPool.EffectiveWeightOutOfBounds.selector,
                expectedWTta,
                expectedWShares
            )
        );
        harness.effectiveWeights(100e18, 1e18);
    }

    function test_effectiveWeights_revertsBelowMinWeight_lowRatio() public {
        // ratio 1/100 → wShares = 1/101 ≈ 9.9e15 < 1% (1e16)
        // wTta = 100/101 ≈ 9.9e17
        uint256 expectedWShares = uint256(1e18) / 101;
        uint256 expectedWTta = 1e18 - expectedWShares;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeBufferPool.EffectiveWeightOutOfBounds.selector,
                expectedWTta,
                expectedWShares
            )
        );
        harness.effectiveWeights(1e18, 100e18);
    }

    function testFuzz_effectiveWeights_boundedAndNormalized(uint256 rate, uint256 base) public view {
        rate = bound(rate, 1, 1e30);
        base = bound(base, 1, 1e30);
        uint256 ratio = rate * 1e18 / base;
        vm.assume(ratio >= 0.0102e18 && ratio <= 98e18); // safely inside the 1% weight band
        (uint256 wTta, uint256 wShares) = harness.effectiveWeights(rate, base);
        assertEq(wTta + wShares, 1e18);
        assertGe(wTta, 1e16);
        assertGe(wShares, 1e16);
    }
}
