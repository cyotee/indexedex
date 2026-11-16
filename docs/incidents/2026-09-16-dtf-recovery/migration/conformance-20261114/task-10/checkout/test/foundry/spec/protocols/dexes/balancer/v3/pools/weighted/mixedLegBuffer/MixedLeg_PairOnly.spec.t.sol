// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLeg_PairOnlySpec
 * @notice U=0 P=1 - pairs-only layout equivalent to multi-pair P=1 / single buffer shape.
 */
contract MixedLeg_PairOnlySpec is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 0;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 1;
    }

    function test_deploy_pairOnly() public view {
        assertEq(ml().unpairedCount(), 0);
        assertEq(ml().pairCount(), 1);
        assertEq(ml().tokenCount(), 2);
        assertEq(address(ml().bufferToken(0)), address(dai));
        assertEq(address(ml().shareToken(0)), address(seVault));
    }

    function test_swap_bufferToShares() public {
        uint256 amountIn = 10e18;
        dai.mint(alice, amountIn);
        vm.prank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 out = swapExactIn(alice, IERC20(address(dai)), IERC20(address(seVault)), amountIn);
        assertGt(out, 0);
        assertGe(ml().virtualBuffer(0), ML_INIT_BUFFER);
    }

    function test_swap_sharesToBuffer() public {
        uint256 amountIn = 5e18;
        mintSharesForPair(0, alice, amountIn * 2);
        uint256 out = swapExactIn(alice, IERC20(address(seVault)), IERC20(address(dai)), amountIn);
        assertGt(out, 0);
        assertLt(ml().virtualBuffer(0), ML_INIT_BUFFER);
    }
}
