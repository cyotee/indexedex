// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";

/// @title DeploymentBase
/// @notice Shared base for Robinhood mainnet (4663) architecture Stages.
/// @dev No test tokens. No DETF instances. Anvil node flags stay in the shell.
abstract contract DeploymentBase is Script {
    string internal constant OUT_DIR = "deployments/anvil_robinhood_main";
    uint256 internal constant EXPECTED_CHAIN_ID = 4663;

    address internal constant DEFAULT_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant DEFAULT_UI_WALLET = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 internal privateKey;
    address internal deployer;
    address internal owner;
    address internal uiWallet;
    bool internal forceEnabled;

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
        return "anvil_robinhood_main";
    }

    function _parseForceEnv() internal view returns (bool) {
        try vm.envString("FORCE") returns (string memory s) {
            bytes memory b = bytes(s);
            if (b.length == 0) return false;
            bytes1 c = b[0];
            if (c == "0" || c == "f" || c == "F") return false;
            if (c == "1" || c == "t" || c == "T") return true;
            return false;
        } catch {
            return false;
        }
    }

    function _force() internal view returns (bool) {
        return forceEnabled;
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
        if (deployerEnv == address(0)) {
            try vm.envAddress("DEV_ADDRESS") returns (address dev) {
                deployerEnv = dev;
            } catch {}
        }
        deployer = deployerEnv == address(0) ? DEFAULT_DEPLOYER : deployerEnv;

        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
        } catch {
            privateKey = 0;
        }

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner == address(0) ? deployer : envOwner;
        } catch {
            owner = deployer;
        }

        try vm.envAddress("UI_WALLET") returns (address envUi) {
            uiWallet = envUi == address(0) ? DEFAULT_UI_WALLET : envUi;
        } catch {
            uiWallet = DEFAULT_UI_WALLET;
        }

        forceEnabled = _parseForceEnv();
    }

    function _requireRobinhoodChain() internal view {
        require(block.chainid == EXPECTED_CHAIN_ID, "anvil_robinhood_main: chainId must be 4663");
        require(block.chainid == ROBINHOOD_MAIN.CHAIN_ID, "anvil_robinhood_main: ROBINHOOD_MAIN.CHAIN_ID mismatch");
    }

    function _broadcast() internal {
        if (privateKey != 0) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast();
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

    function _artifactHasLiveCode(string memory file, string memory key) internal view returns (bool) {
        (address addr, bool exists) = _readAddressSafe(file, key);
        return exists && addr != address(0) && addr.code.length > 0;
    }

    function _shouldSkipStage(string memory file, string memory key) internal view returns (bool) {
        if (_force()) return false;
        return _artifactHasLiveCode(file, key);
    }

    function _shouldSkipStage(string memory file, string[] memory keys) internal view returns (bool) {
        if (_force()) return false;
        uint256 n = keys.length;
        if (n == 0) return false;
        for (uint256 i; i < n; ++i) {
            if (!_artifactHasLiveCode(file, keys[i])) return false;
        }
        return true;
    }

    function _skipKeys(string memory k0) internal pure returns (string[] memory keys) {
        keys = new string[](1);
        keys[0] = k0;
    }

    function _skipKeys(string memory k0, string memory k1) internal pure returns (string[] memory keys) {
        keys = new string[](2);
        keys[0] = k0;
        keys[1] = k1;
    }

    function _skipKeys(string memory k0, string memory k1, string memory k2)
        internal
        pure
        returns (string[] memory keys)
    {
        keys = new string[](3);
        keys[0] = k0;
        keys[1] = k1;
        keys[2] = k2;
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
