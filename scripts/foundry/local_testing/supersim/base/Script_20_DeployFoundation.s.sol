// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script_DeployProtocolDetfMinimal} from "../../../supersim/base/Script_DeployProtocolDetfMinimal.s.sol";
import {SuperSimManifestLib} from "../../../supersim/SuperSimManifestLib.sol";

import {LocalTestingSuperSimBase} from "../LocalTestingSuperSimBase.sol";

contract Script_20_DeployFoundation is LocalTestingSuperSimBase, Script_DeployProtocolDetfMinimal {
    function runLocal() external {
        _configureLocalTestingSuperSimEnv();
        _configureRemoteOutDir();
        run();
        _writeFoundationManifest();
    }

    function _writeFoundationManifest() internal {
        string memory outDir = _currentChainOutDir();
        string memory detfJson = vm.readFile(string.concat(outDir, "/16_protocol_detf.json"));

        string memory json;
        json = vm.serializeString("", "environment", SuperSimManifestLib.ENVIRONMENT);
        json = vm.serializeString("", "chainRole", _chainRole());
        json = vm.serializeString("", "outDir", outDir);
        json = vm.serializeString("", "frontendDir", _frontendOutDir(_chainRole()));
        json = vm.serializeAddress("", "protocolDetf", vm.parseJsonAddress(detfJson, ".protocolDetf"));
        json = vm.serializeAddress("", "richToken", vm.parseJsonAddress(detfJson, ".richToken"));
        json = vm.serializeAddress("", "richirToken", vm.parseJsonAddress(detfJson, ".richirToken"));

        SuperSimManifestLib.writeJson(vm, outDir, "20_foundation.json", json);
    }
}