// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ROBINHOOD_TESTNET} from "@crane/contracts/constants/networks/ROBINHOOD_TESTNET.sol";

/// @title DeploymentBase
/// @notice Shared base for Anvil Robinhood-testnet-fork groups (chain id 46630).
abstract contract DeploymentBase is Script {
    string internal constant OUT_DIR = "deployments/anvil_robinhood_testnet";
    uint256 internal constant EXPECTED_CHAIN_ID = 46630;

    address internal constant DEFAULT_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant DEFAULT_UI_WALLET = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 internal privateKey;
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
        try vm.envAddress("SENDER") returns (address sender) {
            deployer = sender != address(0) ? sender : DEFAULT_DEPLOYER;
        } catch {
            deployer = DEFAULT_DEPLOYER;
        }

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
    }

    function _requireRobinhoodTestnet() internal view {
        require(block.chainid == EXPECTED_CHAIN_ID, "anvil_robinhood_testnet: chainId must be 46630");
        require(
            block.chainid == ROBINHOOD_TESTNET.CHAIN_ID, "anvil_robinhood_testnet: ROBINHOOD_TESTNET.CHAIN_ID mismatch"
        );
    }

    /// @notice Refuse broadcast unless RPC_URL is localhost. Simulation (no env / no broadcast) is allowed.
    function _requireLocalhostIfBroadcast() internal view {
        try vm.envString("RPC_URL") returns (string memory rpc) {
            if (bytes(rpc).length == 0) return;
            bytes memory b = bytes(rpc);
            bool local = _startsWith(b, "http://127.0.0.1") || _startsWith(b, "http://localhost")
                || _startsWith(b, "https://127.0.0.1") || _startsWith(b, "https://localhost");
            require(local, "anvil_robinhood_testnet: refuse broadcast to non-localhost RPC_URL");
        } catch {}
    }

    function _startsWith(bytes memory hay, string memory needle) private pure returns (bool) {
        bytes memory n = bytes(needle);
        if (hay.length < n.length) return false;
        for (uint256 i; i < n.length; ++i) {
            if (hay[i] != n[i]) return false;
        }
        return true;
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
