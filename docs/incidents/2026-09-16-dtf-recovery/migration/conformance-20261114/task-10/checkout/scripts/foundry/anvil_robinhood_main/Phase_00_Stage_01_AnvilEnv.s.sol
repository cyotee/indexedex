// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_00_Stage_01_AnvilEnv as AnvilEnvLib} from "./Phase_00_Stage_01_AnvilEnv.sol";

/// @title Phase_00_Stage_01_AnvilEnv
/// @notice Anvil shell only. No skip keys. Always rewrite JSON.
contract Phase_00_Stage_01_AnvilEnv is LaunchStageBase {
    function run() external {
        _start("Phase 00 Stage 01: Anvil env");
        AnvilEnvLib.execute();
        string memory json;
        json = vm.serializeUint("p0001", "chainId", block.chainid);
        json = vm.serializeUint("p0001", "blockNumber", block.number);
        json = vm.serializeAddress("p0001", "deployer", deployer);
        json = vm.serializeAddress("p0001", "owner", owner);
        json = vm.serializeAddress("p0001", "uiWallet", uiWallet);
        json = vm.serializeAddress("p0001", "dev0", AnvilEnvLib.DEV0);
        json = vm.serializeAddress("p0001", "dev1", AnvilEnvLib.DEV1);
        json = vm.serializeString("p0001", "networkProfile", _networkProfile());
        _writeJson(json, FILE_00_01);
        _logComplete("Phase 00 Stage 01");
    }
}
