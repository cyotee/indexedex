// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

import {SuperSimManifestLib} from "../../supersim/SuperSimManifestLib.sol";

abstract contract LocalTestingSuperSimBase is Script {
    string internal constant DEFAULT_ROOT = "deployments/local_testing/supersim";
    string internal constant DEFAULT_ETHEREUM_DIR = "deployments/local_testing/supersim/ethereum";
    string internal constant DEFAULT_BASE_DIR = "deployments/local_testing/supersim/base";
    string internal constant DEFAULT_SHARED_DIR = "deployments/local_testing/supersim/shared";
    string internal constant DEFAULT_FRONTEND_DIR = "frontend/packages/protocol/src/addresses/local_testing_supersim";

    function _configureLocalTestingSuperSimEnv() internal {
        _setEnvIfMissing("SUPERSIM_ROOT_OUT_DIR", DEFAULT_ROOT);
        _setEnvIfMissing("SUPERSIM_ETHEREUM_OUT_DIR", DEFAULT_ETHEREUM_DIR);
        _setEnvIfMissing("SUPERSIM_BASE_OUT_DIR", DEFAULT_BASE_DIR);
        _setEnvIfMissing("SUPERSIM_SHARED_OUT_DIR", DEFAULT_SHARED_DIR);
        _setEnvIfMissing("SUPERSIM_FRONTEND_ARTIFACTS_DIR", DEFAULT_FRONTEND_DIR);
        _setEnvIfMissing("OUT_DIR_OVERRIDE", _currentChainOutDir());
    }

    function _configureRemoteOutDir() internal {
        _setEnvIfMissing("REMOTE_OUT_DIR", _peerChainOutDir());
    }

    function _currentChainOutDir() internal view returns (string memory outDir) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory overrideDir) {
            if (bytes(overrideDir).length != 0) {
                return overrideDir;
            }
        } catch {}

        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return _localTestingEthereumOutDir();
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return _localTestingBaseOutDir();
        }

        revert("Unsupported chain for local SuperSim out dir");
    }

    function _peerChainOutDir() internal view returns (string memory outDir) {
        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return _localTestingBaseOutDir();
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return _localTestingEthereumOutDir();
        }

        revert("Unsupported chain for local SuperSim peer out dir");
    }

    function _localTestingEthereumOutDir() internal view returns (string memory) {
        return _envStringOr("SUPERSIM_ETHEREUM_OUT_DIR", DEFAULT_ETHEREUM_DIR);
    }

    function _localTestingBaseOutDir() internal view returns (string memory) {
        return _envStringOr("SUPERSIM_BASE_OUT_DIR", DEFAULT_BASE_DIR);
    }

    function _localTestingSharedOutDir() internal view returns (string memory) {
        return _envStringOr("SUPERSIM_SHARED_OUT_DIR", DEFAULT_SHARED_DIR);
    }

    function _localTestingFrontendOutDir(string memory chainRole) internal view returns (string memory) {
        return string.concat(_envStringOr("SUPERSIM_FRONTEND_ARTIFACTS_DIR", DEFAULT_FRONTEND_DIR), "/", chainRole);
    }

    function _localTestingChainRole() internal view returns (string memory role) {
        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return "ethereum";
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return "base";
        }

        revert("Unsupported chain for local SuperSim role");
    }

    function _writeSharedStageJson(string memory filePrefix, string memory json) internal {
        SuperSimManifestLib.writeJson(
            vm,
            _localTestingSharedOutDir(),
            string.concat(filePrefix, "_", _localTestingChainRole(), ".json"),
            json
        );
    }

    function _setEnvIfMissing(string memory key, string memory value) internal {
        try vm.envString(key) returns (string memory existingValue) {
            if (bytes(existingValue).length == 0) {
                vm.setEnv(key, value);
            }
        } catch {
            vm.setEnv(key, value);
        }
    }

    function _envStringOr(string memory key, string memory fallbackValue) internal view returns (string memory value) {
        try vm.envString(key) returns (string memory envValue) {
            if (bytes(envValue).length != 0) {
                return envValue;
            }
        } catch {}

        return fallbackValue;
    }
}