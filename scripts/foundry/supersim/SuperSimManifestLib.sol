// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Vm} from "forge-std/Vm.sol";

library SuperSimManifestLib {
    string internal constant ENVIRONMENT = "supersim_sepolia";
    string internal constant DEFAULT_ROOT = "deployments/supersim_sepolia";
    string internal constant DEFAULT_ETHEREUM_DIR = "deployments/supersim_sepolia/ethereum";
    string internal constant DEFAULT_BASE_DIR = "deployments/supersim_sepolia/base";
    string internal constant DEFAULT_SHARED_DIR = "deployments/supersim_sepolia/shared";

    function envStringOr(Vm vm, string memory key, string memory fallbackValue)
        internal
        view
        returns (string memory value)
    {
        try vm.envString(key) returns (string memory envValue) {
            if (bytes(envValue).length > 0) {
                return envValue;
            }
        } catch {}

        return fallbackValue;
    }

    function rootDir(Vm vm) internal view returns (string memory) {
        return envStringOr(vm, "SUPERSIM_ROOT_OUT_DIR", DEFAULT_ROOT);
    }

    function ethereumOutDir(Vm vm) internal view returns (string memory) {
        return envStringOr(vm, "SUPERSIM_ETHEREUM_OUT_DIR", DEFAULT_ETHEREUM_DIR);
    }

    function baseOutDir(Vm vm) internal view returns (string memory) {
        return envStringOr(vm, "SUPERSIM_BASE_OUT_DIR", DEFAULT_BASE_DIR);
    }

    function sharedOutDir(Vm vm) internal view returns (string memory) {
        return envStringOr(vm, "SUPERSIM_SHARED_OUT_DIR", DEFAULT_SHARED_DIR);
    }

    function frontendOutDir(Vm vm, string memory chainRole) internal view returns (string memory) {
        return string.concat(
            envStringOr(vm, "SUPERSIM_FRONTEND_ARTIFACTS_DIR", "frontend/app/addresses/supersim_sepolia"),
            "/",
            chainRole
        );
    }

    function ensureDir(Vm vm, string memory dir) internal {
        vm.createDir(dir, true);
    }

    function writeJson(Vm vm, string memory dir, string memory fileName, string memory json) internal {
        ensureDir(vm, dir);
        vm.writeJson(json, string.concat(dir, "/", fileName));
    }

    function readFile(Vm vm, string memory dir, string memory fileName) internal view returns (string memory) {
        return vm.readFile(string.concat(dir, "/", fileName));
    }
}
