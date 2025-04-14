// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

import {SuperSimManifestLib} from "./SuperSimManifestLib.sol";

abstract contract DeploymentBase is Script {
    function _ethereumOutDir() internal view returns (string memory) {
        return SuperSimManifestLib.ethereumOutDir(vm);
    }

    function _baseOutDir() internal view returns (string memory) {
        return SuperSimManifestLib.baseOutDir(vm);
    }

    function _sharedOutDir() internal view returns (string memory) {
        return SuperSimManifestLib.sharedOutDir(vm);
    }

    function _frontendOutDir(string memory chainRole) internal view returns (string memory) {
        return SuperSimManifestLib.frontendOutDir(vm, chainRole);
    }

    function _writeSharedJson(string memory fileName, string memory json) internal {
        SuperSimManifestLib.writeJson(vm, _sharedOutDir(), fileName, json);
    }
}
