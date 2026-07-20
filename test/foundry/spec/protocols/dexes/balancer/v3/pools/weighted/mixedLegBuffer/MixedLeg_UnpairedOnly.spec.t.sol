// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLeg_UnpairedOnlySpec
 * @notice U=2 P=0 — pure unpaired weighted pool (no SE buffer I/O; physical balances only).
 */
contract MixedLeg_UnpairedOnlySpec is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 2;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 0;
    }

    function test_deploy_unpairedOnly() public view {
        assertEq(ml().unpairedCount(), 2);
        assertEq(ml().pairCount(), 0);
        assertEq(ml().tokenCount(), 2);
        assertEq(address(ml().unpairedToken(0)), address(usdc));
        assertEq(address(ml().unpairedToken(1)), address(weth));
    }

    function test_swap_unpairedExactIn() public {
        uint256 amountIn = 10e18;
        usdc.mint(alice, amountIn);
        vm.prank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        uint256 out = swapExactIn(alice, IERC20(address(usdc)), IERC20(address(weth)), amountIn);
        assertGt(out, 0);
    }
}
