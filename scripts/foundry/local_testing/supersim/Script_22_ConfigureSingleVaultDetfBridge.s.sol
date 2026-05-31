// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script_25_ConfigureProtocolDetfBridge} from "../../supersim/Script_25_ConfigureProtocolDetfBridge.s.sol";

import {LocalTestingSuperSimBase} from "./LocalTestingSuperSimBase.sol";

contract Script_22_ConfigureSingleVaultDetfBridge is LocalTestingSuperSimBase, Script_25_ConfigureProtocolDetfBridge {
    function runLocal() external {
        _configureLocalTestingSuperSimEnv();
        _configureRemoteOutDir();
        run();
        _writeStage22Manifest();
    }

    function _writeStage22Manifest() internal {
        string memory outDir = _currentChainOutDir();
        string memory json = vm.readFile(string.concat(outDir, "/25_superchain_bridge_config.json"));
        _writeSharedStageJson("22_bridge_config", json);
    }
}