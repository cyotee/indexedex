// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title DeploymentBase
/// @notice Shared base for Robinhood testnet (46630) launch groups.
/// @dev Same signed-broadcast path on public 46630 and on a local Anvil fork.
///      Anvil node flags (`--disable-code-size-limit`) are shell-only, not script cheats.
abstract contract DeploymentBase is Script {
    string internal constant OUT_DIR = "deployments/anvil_robinhood_testnet";
    uint256 internal constant EXPECTED_CHAIN_ID = 46630;

    address internal deployer;
    address internal owner;
    address internal uiWallet;

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
        return "anvil_robinhood_testnet";
    }

    function _force() internal view returns (bool) {
        try vm.envBool("FORCE") returns (bool f) {
            return f;
        } catch {
            return false;
        }
    }

    function _loadConfig() internal {
        address deployerEnv;
        try vm.envAddress("DEPLOYER_ADDRESS") returns (address envDeployer) {
            deployerEnv = envDeployer;
        } catch {}
        if (deployerEnv == address(0)) {
            try vm.envAddress("SENDER") returns (address sender) {
                deployerEnv = sender;
            } catch {}
        }
        require(deployerEnv != address(0), "anvil_robinhood_testnet: DEPLOYER_ADDRESS is required");
        deployer = deployerEnv;

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner == address(0) ? deployer : envOwner;
        } catch {
            owner = deployer;
        }

        try vm.envAddress("UI_WALLET") returns (address envUi) {
            uiWallet = envUi == address(0) ? deployer : envUi;
        } catch {
            uiWallet = deployer;
        }
    }

    function _requireRobinhoodTestnet() internal view {
        require(block.chainid == EXPECTED_CHAIN_ID, "anvil_robinhood_testnet: chainId must be 46630");
        require(
            block.chainid == ROBINHOOD_TESTNET.CHAIN_ID, "anvil_robinhood_testnet: ROBINHOOD_TESTNET.CHAIN_ID mismatch"
        );
    }

    /// @notice Broadcast as `--sender` / `DEPLOYER_ADDRESS`. Cast wallet signs.
    function _broadcast() internal {
        vm.startBroadcast();
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

    function _readAddressSafe(string memory file, string memory key)
        internal
        view
        returns (address addr, bool exists)
    {
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

    function _artifactValid(string memory file, string memory key) internal view returns (bool) {
        if (_force()) return false;
        (address addr, bool exists) = _readAddressSafe(file, key);
        return exists && addr != address(0) && addr.code.length > 0;
    }

    function _writeJson(string memory json, string memory filename) internal {
        _ensureOutDir();
        vm.writeJson(json, _artifactPath(filename));
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

    function _logComplete(string memory stageName) internal pure {
        console2.log("Complete:", stageName);
    }

    function _hasCode(address target) internal view returns (bool) {
        return target != address(0) && target.code.length > 0;
    }
}
