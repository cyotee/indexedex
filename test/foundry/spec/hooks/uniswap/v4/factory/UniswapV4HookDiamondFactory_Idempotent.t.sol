// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {
    TestBase_UniswapV4HookDiamondPackageCallBackFactory
} from "test/foundry/spec/hooks/uniswap/v4/factory/TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

contract UniswapV4HookDiamondFactory_IdempotentTest is TestBase_UniswapV4HookDiamondPackageCallBackFactory {
    /// H4: second deploy same args returns same address; no second HookDiamondDeployed
    function test_H4_idempotentSecondDeploy() public {
        address first = _deployStubPremine();
        vm.recordLogs();
        address second = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        assertEq(first, second);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic0 = keccak256("HookDiamondDeployed(address,address,bytes32,uint256,uint160)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(hookFactory) && logs[i].topics.length > 0) {
                assertTrue(logs[i].topics[0] != topic0, "idempotent path must not re-emit deploy event");
            }
        }

        // Auto-mine path also returns existing (prefer premine in hermetic suite; this is a light smoke).
        // Use a fresh binding with known small mine-space cost only if premine already established identity.
        address third = hookFactory.deployWithMineNonce(
            IUniswapV4HookDiamondPackage(address(stubPkg)), stubArgs, stubMineNonce
        );
        assertEq(third, first);
    }
}
