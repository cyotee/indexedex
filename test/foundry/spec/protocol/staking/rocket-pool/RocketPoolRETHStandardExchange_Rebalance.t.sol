// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";

/**
 * @title RocketPoolRETHStandardExchange_Rebalance_Test
 * @notice Stake excess / burn deficit with capacity and collateral no-ops.
 */
contract RocketPoolRETHStandardExchange_Rebalance_Test is TestBase_RocketPoolRETHStandardExchange {
    function test_RB1_liquidHigh_capacityOpen_stakes() public {
        // Capacity 0 first so mint leaves all liquid, then open capacity and rebalance
        hermeticPool.setMaxDepositAmount(0);
        _seedVaultInventory(100 ether, 0);
        assertEq(rocketPoolSe.liquidReserveEth(), 100 ether);
        hermeticPool.setMaxDepositAmount(type(uint256).max);

        uint256 liquidBefore = rocketPoolSe.liquidReserveEth();
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        seRebalance.rebalance();
        assertLt(rocketPoolSe.liquidReserveEth(), liquidBefore);
        assertGt(hermeticReth.balanceOf(seVault), rethBefore);
    }

    function test_RB2_liquidHigh_capacity0_noop() public {
        hermeticPool.setMaxDepositAmount(0);
        _seedVaultInventory(50 ether, 0);
        uint256 liquidBefore = rocketPoolSe.liquidReserveEth();
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        seRebalance.rebalance();
        assertEq(rocketPoolSe.liquidReserveEth(), liquidBefore);
        assertEq(hermeticReth.balanceOf(seVault), rethBefore);
    }

    function test_RB3_liquidLow_collateralOpen_burns() public {
        // Seed locked rETH, fund tiny sleeve via donation then force liquid low
        _seedVaultInventory(0, 50 ether);
        // liquid is 0 already - band around target (20% of 50 = 10) so liquid + band < target → burn
        _enableBurn(20 ether);
        uint256 liquidBefore = rocketPoolSe.liquidReserveEth();
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        seRebalance.rebalance();
        assertGt(rocketPoolSe.liquidReserveEth(), liquidBefore);
        assertLt(hermeticReth.balanceOf(seVault), rethBefore);
    }

    function test_RB4_liquidLow_collateral0_noop() public {
        _seedVaultInventory(0, 50 ether);
        uint256 liquidBefore = rocketPoolSe.liquidReserveEth();
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        seRebalance.rebalance();
        assertEq(rocketPoolSe.liquidReserveEth(), liquidBefore);
        assertEq(hermeticReth.balanceOf(seVault), rethBefore);
    }

    function test_RB6_rebalance_neverRevertsOnDry() public {
        hermeticPool.setMaxDepositAmount(0);
        _seedVaultInventory(10 ether, 10 ether);
        // Both capacity and collateral dry for any further action
        seRebalance.rebalance(); // must not revert
    }
}
