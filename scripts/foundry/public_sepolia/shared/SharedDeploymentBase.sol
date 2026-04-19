// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

abstract contract SharedDeploymentBase is Script {
    string internal constant DEFAULT_ETHEREUM_OUT_DIR = "deployments/public_sepolia/ethereum";
    string internal constant DEFAULT_BASE_OUT_DIR = "deployments/public_sepolia/base";
    string internal constant DEFAULT_SHARED_OUT_DIR = "deployments/public_sepolia/shared";

    address internal deployer;

    function _setupShared() internal {
        try vm.envAddress("SENDER") returns (address sender) {
            deployer = sender == address(0) ? tx.origin : sender;
        } catch {
            deployer = tx.origin;
        }
    }

    function _ethereumOutDir() internal view returns (string memory) {
        try vm.envString("PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR") returns (string memory value) {
            if (bytes(value).length > 0) {
                return value;
            }
        } catch {}

        return DEFAULT_ETHEREUM_OUT_DIR;
    }

    function _baseOutDir() internal view returns (string memory) {
        try vm.envString("PUBLIC_SEPOLIA_BASE_OUT_DIR") returns (string memory value) {
            if (bytes(value).length > 0) {
                return value;
            }
        } catch {}

        return DEFAULT_BASE_OUT_DIR;
    }

    function _sharedOutDir() internal view returns (string memory) {
        try vm.envString("PUBLIC_SEPOLIA_SHARED_OUT_DIR") returns (string memory value) {
            if (bytes(value).length > 0) {
                return value;
            }
        } catch {}

        return DEFAULT_SHARED_OUT_DIR;
    }

    function _readAddressFrom(string memory dir, string memory file, string memory key) internal view returns (address) {
        string memory path = string.concat(dir, "/", file);
        string memory json = vm.readFile(path);
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    function _readAddressFromSafe(string memory dir, string memory file, string memory key)
        internal
        view
        returns (address addr, bool exists)
    {
        string memory path = string.concat(dir, "/", file);
        try vm.readFile(path) returns (string memory json) {
            try vm.parseJsonAddress(json, string.concat(".", key)) returns (address parsed) {
                return (parsed, true);
            } catch {
                return (address(0), false);
            }
        } catch {
            return (address(0), false);
        }
    }

    function _ensureDir(string memory dir) internal {
        vm.createDir(dir, true);
    }

    function _writeJsonTo(string memory dir, string memory filename, string memory json) internal {
        _ensureDir(dir);
        vm.writeJson(json, string.concat(dir, "/", filename));
    }
}