// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { VmSafe } from "forge-std/Vm.sol";

/// @notice Sweep sender ETH to DEV0, leaving 0.1 ETH behind.
/// @dev Intended for Anvil's default unlocked accounts.
///
/// Run example:
/// `forge script scripts/foundry/anvil_sepolia/Script_00_SweepEthToDev0.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <DEV1..DEV9>`
contract Script_00_SweepEthToDev0 is Script {
    // Default Anvil account(0)
    address internal constant DEFAULT_DEV0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Leave 0.1 ETH in the sender
    uint256 internal constant RESERVE_WEI = 0.1 ether;

    function run() external {
        address dev0 = vm.envOr("DEV0_ADDRESS", DEFAULT_DEV0);

        vm.startBroadcast();

        // When broadcasting, Foundry sets the callers to the active broadcast address.
        (, address from,) = vm.readCallers();

        if (from == dev0) {
            vm.stopBroadcast();
            return;
        }

        uint256 bal = from.balance;
        if (bal <= RESERVE_WEI) {
            vm.stopBroadcast();
            return;
        }

        uint256 amount = bal - RESERVE_WEI;
        (bool ok,) = payable(dev0).call{ value: amount }("");
        require(ok, "ETH_TRANSFER_FAILED");

        vm.stopBroadcast();
    }
}
