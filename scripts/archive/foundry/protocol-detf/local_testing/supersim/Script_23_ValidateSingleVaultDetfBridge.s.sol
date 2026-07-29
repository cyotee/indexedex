// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {console2} from "forge-std/console2.sol";

import {Script_26_TestProtocolDetfReserveBridge} from "../../supersim/Script_26_TestProtocolDetfReserveBridge.s.sol";

import {LocalTestingSuperSimBase} from "./LocalTestingSuperSimBase.sol";

contract Script_23_ValidateSingleVaultDetfBridge is LocalTestingSuperSimBase, Script_26_TestProtocolDetfReserveBridge {
    function runLocal() external {
        _configureLocalTestingSuperSimEnv();
        _configureRemoteOutDir();

        console2.log("=== Stage 23 Local Wrapper ===");
        console2.log("Local out dir:", _currentChainOutDir());
        console2.log("Remote out dir:", _peerChainOutDir());
        console2.log("Shared out dir:", _localTestingSharedOutDir());

        run();

        console2.log("Stage 23 core validation complete; writing shared manifest...");
        _writeStage23Manifest();
        console2.log("Stage 23 shared manifest ready:", _sharedManifestPath());
    }

    function _writeStage23Manifest() internal {
        string memory outDir = _currentChainOutDir();
        string memory json = vm.readFile(string.concat(outDir, "/26_bridge_test.json"));
        _writeSharedStageJson("23_bridge_validation", json);
    }

    function _sharedManifestPath() internal view returns (string memory) {
        return string.concat(
            _localTestingSharedOutDir(), "/23_bridge_validation_", _localTestingChainRole(), ".json"
        );
    }
}