// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLeg_LPSpec
 * @notice LP remove proportional scales virtualBuffer down; add unbalanced already in invariant suite.
 */
contract MixedLeg_LPSpec is TestBase_MixedLegWeightedBufferPool {
    function test_lp_removeProportional_scalesVirtualDown() public {
        // Ensure alice holds BPT from init
        uint256 bptBal = IERC20(mixedLegPool).balanceOf(alice);
        assertGt(bptBal, 0);
        uint256 vtBefore = ml().virtualBuffer(0);
        uint256 bptIn = bptBal / 10;
        assertGt(bptIn, 0);

        uint256 n = ml().tokenCount();
        uint256[] memory minOut = new uint256[](n);

        vm.startPrank(alice);
        IERC20(mixedLegPool).approve(address(router), type(uint256).max);
        router.removeLiquidityProportional(mixedLegPool, bptIn, minOut, false, bytes(""));
        vm.stopPrank();

        uint256 vtAfter = ml().virtualBuffer(0);
        assertLt(vtAfter, vtBefore);
        // Rough proportional: remaining ≈ before * (1 - bptIn/tPre)
        uint256 tPre = IERC20(mixedLegPool).totalSupply() + bptIn;
        uint256 expected = vtBefore - (bptIn * vtBefore) / tPre;
        assertApproxEqAbs(vtAfter, expected, 1, "virtual scales with BPT burn");
    }

    function test_lp_removeProportional_allLegsReceive() public {
        uint256 bptBal = IERC20(mixedLegPool).balanceOf(alice);
        uint256 bptIn = bptBal / 20;
        uint256 n = ml().tokenCount();
        uint256[] memory minOut = new uint256[](n);

        uint256[] memory beforeBal = new uint256[](n);
        (IERC20[] memory toks,, uint256[] memory rawBefore,) = bv3Vault.getPoolTokenInfo(mixedLegPool);
        // user balances before
        for (uint256 t; t < n; ++t) {
            beforeBal[t] = toks[t].balanceOf(alice);
        }

        vm.startPrank(alice);
        IERC20(mixedLegPool).approve(address(router), type(uint256).max);
        uint256[] memory amountsOut =
            router.removeLiquidityProportional(mixedLegPool, bptIn, minOut, false, bytes(""));
        vm.stopPrank();

        for (uint256 t; t < n; ++t) {
            assertGt(amountsOut[t], 0, "each leg out > 0");
            assertEq(toks[t].balanceOf(alice), beforeBal[t] + amountsOut[t]);
        }
        rawBefore; // silence
    }
}
