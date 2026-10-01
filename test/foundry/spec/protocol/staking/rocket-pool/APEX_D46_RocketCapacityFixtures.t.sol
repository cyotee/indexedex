// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    HermeticRETH,
    HermeticDepositPool,
    HermeticRocketStorage,
    HermeticRocketDAOProtocolSettingsDeposit
} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";

contract APEX_D46_RocketCapacityFixtures is Test {
    HermeticRETH internal reth;
    HermeticDepositPool internal pool;
    HermeticRocketDAOProtocolSettingsDeposit internal settings;
    HermeticRocketStorage internal registry;

    function setUp() public {
        reth = new HermeticRETH();
        settings = new HermeticRocketDAOProtocolSettingsDeposit();
        pool = new HermeticDepositPool(reth, settings);
        registry = new HermeticRocketStorage(address(reth), address(pool));
        registry.register("rocketDAOProtocolSettingsDeposit", address(settings));
        settings.setMinimumDeposit(0.01 ether);
    }

    function test_APEX_D46_rocketFiniteCapacityConsumes() public {
        pool.setMaxDepositAmount(100 ether);
        pool.deposit{value: 60 ether}();
        assertEq(pool.getMaximumDepositAmount(), 40 ether);
        vm.expectRevert(abi.encodeWithSelector(HermeticDepositPool.InsufficientDepositCapacity.selector, 40 ether, 41 ether));
        pool.deposit{value: 41 ether}();
        assertEq(pool.getMaximumDepositAmount(), 40 ether);
        pool.deposit{value: 40 ether}();
        assertEq(pool.getMaximumDepositAmount(), 0);
    }

    function test_APEX_D46_rocketMinimumUsesProtocolString() public {
        settings.setMinimumDeposit(2 ether);
        vm.expectRevert(bytes("The deposited amount is less than the minimum deposit size"));
        pool.deposit{value: 1 ether}();
        pool.deposit{value: 2 ether}();
        bytes32 key = keccak256(abi.encodePacked("contract.address", "rocketDAOProtocolSettingsDeposit"));
        assertEq(registry.getAddress(key), address(settings));
    }

    function test_APEX_D46_rocketDisabledPublishesZeroWithoutDeletingHeadroom() public {
        pool.setMaxDepositAmount(50 ether);
        pool.setDepositEnabled(false);
        assertEq(pool.getMaximumDepositAmount(), 0);
        vm.expectRevert(HermeticDepositPool.DepositsDisabled.selector);
        pool.deposit{value: 1 ether}();
        pool.setDepositEnabled(true);
        assertEq(pool.getMaximumDepositAmount(), 50 ether);
    }

    function test_APEX_D46_rocketUnboundedSentinelUnchanged() public {
        pool.setMaxDepositAmount(type(uint256).max);
        pool.deposit{value: 3 ether}();
        assertEq(pool.getMaximumDepositAmount(), type(uint256).max);
    }
}
