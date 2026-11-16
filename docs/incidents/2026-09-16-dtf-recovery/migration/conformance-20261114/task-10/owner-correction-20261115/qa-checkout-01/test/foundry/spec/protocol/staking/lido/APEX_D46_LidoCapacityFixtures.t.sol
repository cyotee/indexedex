// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HermeticStETH} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";

contract APEX_D46_LidoCapacityFixtures is Test {
    HermeticStETH internal steth;

    function setUp() public {
        steth = new HermeticStETH();
    }

    function test_APEX_D46_lidoFiniteCapacityConsumes() public {
        steth.setStakeLimit(100 ether);
        steth.submit{value: 60 ether}(address(0));
        assertEq(steth.getCurrentStakeLimit(), 40 ether);
        vm.expectRevert(bytes("STAKE_LIMIT"));
        steth.submit{value: 41 ether}(address(0));
        assertEq(steth.getCurrentStakeLimit(), 40 ether);
        steth.submit{value: 40 ether}(address(0));
        assertEq(steth.getCurrentStakeLimit(), 0);
    }

    function test_APEX_D46_lidoPausedReportsZeroWithoutDeletingHeadroom() public {
        steth.setStakeLimit(80 ether);
        steth.setStakingPaused(true);
        assertEq(steth.getCurrentStakeLimit(), 0);
        assertTrue(steth.isStakingPaused());
        vm.expectRevert(bytes("STAKING_PAUSED"));
        steth.submit{value: 1 ether}(address(0));
        steth.setStakingPaused(false);
        assertEq(steth.getCurrentStakeLimit(), 80 ether);
        steth.submit{value: 1 ether}(address(0));
        assertEq(steth.getCurrentStakeLimit(), 79 ether);
    }

    function test_APEX_D46_lidoUnboundedSentinelUnchanged() public {
        assertEq(steth.getCurrentStakeLimit(), type(uint256).max);
        steth.submit{value: 5 ether}(address(0));
        assertEq(steth.getCurrentStakeLimit(), type(uint256).max);
    }
}
