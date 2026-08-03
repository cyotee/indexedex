// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    UniV4DetfListingOracleLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/UniV4DetfListingOracleLib.sol";

/// @dev Thin harness so library storage lives on a contract under test.
contract ListingOracleHarness {
    function initialize(int24 tick_) external {
        UniV4DetfListingOracleLib._initialize(tick_);
    }

    function poke(int24 tick_) external returns (bool) {
        return UniV4DetfListingOracleLib._poke(tick_);
    }

    function twapReady(uint32 secs_) external view returns (bool) {
        return UniV4DetfListingOracleLib._twapReady(secs_);
    }

    function consultTwapTick(uint32 secs_) external view returns (int24) {
        return UniV4DetfListingOracleLib._consultTwapTick(secs_);
    }

    function lastBlock() external view returns (uint256) {
        return UniV4DetfListingOracleLib._layout().lastObservationBlock;
    }

    function cardinality() external view returns (uint16) {
        return UniV4DetfListingOracleLib._layout().cardinality;
    }
}

contract UniV4DetfListingOracleLibTest is Test {
    ListingOracleHarness internal harness;

    function setUp() public {
        harness = new ListingOracleHarness();
        // Avoid timestamp 0 edge cases.
        vm.warp(1_000_000);
        vm.roll(100);
        harness.initialize(0);
    }

    function test_initialize_setsCardinality32() public view {
        assertEq(harness.cardinality(), 32);
    }

    function test_sameBlockPoke_isNoOp() public {
        bool wrote = harness.poke(10);
        // First poke after init is same block as initialize → no-op.
        assertFalse(wrote);
        vm.roll(block.number + 1);
        wrote = harness.poke(10);
        assertTrue(wrote);
        // Same block again.
        wrote = harness.poke(20);
        assertFalse(wrote);
    }

    function test_twapReady_falseUntilWindow() public {
        assertFalse(harness.twapReady(1800));

        // Sparse pokes over 10 minutes — still incomplete.
        for (uint256 i; i < 10; ++i) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 60);
            harness.poke(int24(int256(i)));
        }
        assertFalse(harness.twapReady(1800));

        // Advance past 1800s with more pokes.
        for (uint256 i; i < 30; ++i) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 60);
            harness.poke(100);
        }
        assertTrue(harness.twapReady(1800));
    }

    function test_priceDetfPerPair_creationAtOneToOne_18dec() public pure {
        // tick 0 → sqrtPrice = 2^96 → price1Per0 = 1
        uint160 sqrtP = TickMath.getSqrtPriceAtTick(0);
        uint256 r = UniV4DetfListingOracleLib._priceDetfPerPairWad(sqrtP, true, 18);
        // Allow 1 bps relative tolerance for Q64.96 rounding.
        assertApproxEqRel(r, 1e18, 1e14);
    }

    function test_synthetic_atCreationIsOne() public pure {
        uint256 synth = UniV4DetfListingOracleLib._syntheticPrice(false, 2e18, 1e18);
        assertEq(synth, 1e18);
        synth = UniV4DetfListingOracleLib._syntheticPrice(true, 2e18, 1e18);
        assertEq(synth, 2e18);
    }

    function test_detfFromPairNotional() public pure {
        uint256 gross = UniV4DetfListingOracleLib._detfFromPairNotional(100e18, 2e18);
        assertEq(gross, 200e18);
    }

    function test_marketMarkUsable_requiresAll() public pure {
        assertFalse(UniV4DetfListingOracleLib._isMarketMarkUsable(true, true, 0));
        assertFalse(UniV4DetfListingOracleLib._isMarketMarkUsable(true, false, 1));
        assertFalse(UniV4DetfListingOracleLib._isMarketMarkUsable(false, true, 1));
        assertTrue(UniV4DetfListingOracleLib._isMarketMarkUsable(true, true, 1));
    }
}
