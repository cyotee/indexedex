// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ManifestEntry, ManifestEntryLib} from "./ManifestEntry.sol";

/// @title LocalTestingDeploymentBase
/// @notice Shared base contract for local-testing deployment stages
/// @dev Provides environment, manifest, and logging helpers for local Anvil and SuperSim flows
abstract contract LocalTestingDeploymentBase is Script {
    string internal constant OUT_DIR = "deployments/local_testing/anvil_single";

    uint256 internal privateKey;
    address internal deployer;
    address internal owner;

    function _outDir() internal view returns (string memory outDir) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory overrideDir) {
            if (bytes(overrideDir).length > 0) {
                return overrideDir;
            }
        } catch {}

        return OUT_DIR;
    }

    function _networkProfile() internal view returns (string memory profile) {
        try vm.envString("NETWORK_PROFILE") returns (string memory envProfile) {
            if (bytes(envProfile).length > 0) {
                return envProfile;
            }
        } catch {}

        return "local_testing";
    }

    function _loadConfig() internal {
        try vm.envAddress("SENDER") returns (address sender) {
            if (sender != address(0)) {
                deployer = sender;
            } else {
                deployer = tx.origin;
            }
        } catch {
            deployer = tx.origin;
        }

        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
        } catch {
            privateKey = 0;
        }

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner;
        } catch {
            owner = deployer;
        }
    }

    function _ensureOutDir() internal {
        vm.createDir(_outDir(), true);
    }

    function _artifactPath(string memory file) internal view returns (string memory) {
        return string.concat(_outDir(), "/", file);
    }

    function _readAddress(string memory file, string memory key) internal view returns (address) {
        string memory json = vm.readFile(_artifactPath(file));
        return vm.parseJsonAddress(json, string.concat(".", key));
    }

    function _readAddressSafe(string memory file, string memory key) internal view returns (address addr, bool exists) {
        try vm.readFile(_artifactPath(file)) returns (string memory json) {
            try vm.parseJsonAddress(json, string.concat(".", key)) returns (address parsed) {
                return (parsed, true);
            } catch {
                return (address(0), false);
            }
        } catch {
            return (address(0), false);
        }
    }

    function _writeJson(string memory json, string memory filename) internal {
        _ensureOutDir();
        vm.writeJson(json, _artifactPath(filename));
    }

    /// @notice Root directory for Token List fragment files emitted by deploy scripts.
    /// @dev Lives under `_outDir()/fragments/` so legacy per-category JSONs at `_outDir()/`
    ///      are not disturbed during the Phase 1 parallel-produce migration.
    function _fragmentRoot() internal view returns (string memory) {
        return string.concat(_outDir(), "/fragments");
    }

    /// @notice Write a single Token List fragment to deployments/<env>/<chain>/fragments/<typeDir>/<key>.json.
    /// @param typeDir Directory bucket (e.g. "tokens", "pools/balancerV3", "vaults/strategy").
    /// @param key    Stable identifier within the bucket (e.g. "tta", "abPool"); also the filename stem.
    /// @param entry  Fragment payload. Extensions are not written from Solidity in Phase 1.
    function _writeManifestEntry(
        string memory typeDir,
        string memory key,
        ManifestEntry memory entry
    ) internal {
        string memory dir = string.concat(_fragmentRoot(), "/", typeDir);
        vm.createDir(dir, true);

        string memory path = string.concat(dir, "/", key, ".json");
        string memory json = ManifestEntryLib.toJson(entry);
        vm.writeFile(path, json);
    }

    function _logHeader(string memory stageName) internal pure {
        console2.log("========================================");
        console2.log(stageName);
        console2.log("========================================");
    }

    function _logAddress(string memory name, address addr) internal pure {
        console2.log(name, addr);
    }

    function _logString(string memory name, string memory value) internal pure {
        console2.log(name, value);
    }

    function _logUint(string memory name, uint256 value) internal pure {
        console2.log(name, value);
    }

    function _logComplete(string memory stageName) internal pure {
        console2.log("");
        console2.log(stageName, "complete!");
        console2.log("========================================");
    }
}