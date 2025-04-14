// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {console2} from "forge-std/console2.sol";

/// @title Script_00_DebugSender
/// @notice Logs msg.sender / tx.origin behavior for forge script execution.
contract Script_00_DebugSender is DeploymentBase {
    function run() external {
        _setup();

        console2.log("msg.sender", msg.sender);
        console2.log("tx.origin", tx.origin);
        console2.log("deployer(var)", deployer);
        console2.log("owner(var)", owner);

        // Don't broadcast anything; this is just a probe.
    }
}
