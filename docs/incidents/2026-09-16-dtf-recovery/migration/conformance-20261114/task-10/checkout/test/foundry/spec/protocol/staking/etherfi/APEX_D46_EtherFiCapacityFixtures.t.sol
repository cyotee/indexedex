// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    HermeticEETH,
    HermeticLiquidityPool,
    HermeticBlacklister
} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";

contract APEX_D46_EtherFiCapacityFixtures is Test {
    HermeticEETH internal eeth;
    HermeticLiquidityPool internal pool;

    function setUp() public {
        eeth = new HermeticEETH();
        pool = new HermeticLiquidityPool(eeth);
    }

    function test_APEX_D46_etherFiPausedRevertsBothDeposits() public {
        pool.setPaused(true);
        assertTrue(pool.paused());
        vm.expectRevert(HermeticLiquidityPool.ContractPaused.selector);
        pool.deposit{value: 1 ether}();
        vm.expectRevert(HermeticLiquidityPool.ContractPaused.selector);
        pool.deposit{value: 1 ether}(address(this));
        pool.setPaused(false);
        pool.deposit{value: 1 ether}();
        assertEq(eeth.balanceOf(address(this)), 1 ether);
    }

    function test_APEX_D46_etherFiTimedPause() public {
        pool.setPausedUntil(block.timestamp + 100);
        vm.expectRevert(abi.encodeWithSelector(HermeticLiquidityPool.ContractPausedUntil.selector, block.timestamp + 100));
        pool.deposit{value: 1 ether}();
        pool.setPausedUntil(0);
        pool.deposit{value: 1 ether}();
    }

    function test_APEX_D46_etherFiBlacklist() public {
        HermeticBlacklister bl = pool.blacklister();
        bl.setBlacklistedUntil(address(this), block.timestamp + 1);
        vm.expectRevert(abi.encodeWithSelector(HermeticBlacklister.BlacklistedUser.selector, address(this)));
        pool.deposit{value: 1 ether}();
        bl.setBlacklistedUntil(address(this), 0);
        pool.deposit{value: 1 ether}();
    }
}
