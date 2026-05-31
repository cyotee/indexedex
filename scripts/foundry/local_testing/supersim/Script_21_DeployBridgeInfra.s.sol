// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script_24_DeploySuperchainBridgeInfra} from "../../supersim/Script_24_DeploySuperchainBridgeInfra.s.sol";

import {LocalTestingSuperSimBase} from "./LocalTestingSuperSimBase.sol";

contract Script_21_DeployBridgeInfra is LocalTestingSuperSimBase, Script_24_DeploySuperchainBridgeInfra {
    function runLocal() external {
        _configureLocalTestingSuperSimEnv();
        run();
        _writeStage21Manifest();
    }

    function _writeStage21Manifest() internal {
        string memory outDir = _currentChainOutDir();
        string memory json = vm.readFile(string.concat(outDir, "/24_superchain_bridge.json"));
        _writeSharedStageJson("21_bridge_infra", json);
    }
}