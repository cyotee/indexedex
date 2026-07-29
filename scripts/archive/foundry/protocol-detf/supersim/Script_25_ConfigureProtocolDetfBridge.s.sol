// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {IApprovedMessageSenderRegistry} from "@crane/contracts/interfaces/IApprovedMessageSenderRegistry.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

import {SuperSimManifestLib} from "./SuperSimManifestLib.sol";

contract Script_25_ConfigureProtocolDetfBridge is Script {
    uint32 internal constant BRIDGE_MIN_GAS_LIMIT = 250_000;

    function run() public {
        string memory localDir = _requiredEnvString("OUT_DIR_OVERRIDE");
        string memory remoteDir = _requiredEnvString("REMOTE_OUT_DIR");

        address deployer;
        try vm.envAddress("SENDER") returns (address sender) {
            if (sender != address(0)) {
                deployer = sender;
            } else {
                deployer = msg.sender;
            }
        } catch {
            deployer = msg.sender;
        }
        uint256 privateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 envKey) {
            privateKey = envKey;
            deployer = vm.addr(envKey);
        } catch {}

        LocalConfig memory localConfig = _readLocalConfig(localDir);
        RemoteConfig memory remoteConfig = _readRemoteConfig(remoteDir);
        ChainBridgeConfig memory chainConfig = _chainBridgeConfig();

        if (privateKey != 0) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast(deployer);
        }

        localConfig.bridgeTokenRegistry.setRemoteToken(
            chainConfig.peerChainId,
            IERC20(localConfig.inventoryDetf),
            IERC20(remoteConfig.inventoryDetf),
            0
        );
        localConfig.bridgeTokenRegistry.setRemoteToken(
            chainConfig.peerChainId,
            IERC20(localConfig.pairToken),
            IERC20(remoteConfig.pairToken),
            BRIDGE_MIN_GAS_LIMIT
        );
        localConfig.approvedRegistry.approveSender(localConfig.inventoryDetf, remoteConfig.inventoryDetf);

        vm.stopBroadcast();

        _exportJson(localDir, localConfig, remoteConfig, chainConfig);
        _logResults(localConfig, remoteConfig, chainConfig);
    }

    struct LocalConfig {
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IApprovedMessageSenderRegistry approvedRegistry;
        address localRelayer;
        address inventoryDetf;
        address pairToken;
    }

    struct RemoteConfig {
        address peerRelayer;
        address inventoryDetf;
        address pairToken;
    }

    struct ChainBridgeConfig {
        uint256 peerChainId;
    }

    function _readLocalConfig(string memory localDir) internal view returns (LocalConfig memory config) {
        string memory bridgeJson = vm.readFile(string.concat(localDir, "/24_superchain_bridge.json"));
        string memory detfJson = vm.readFile(string.concat(localDir, "/16_protocol_detf.json"));

        config.bridgeTokenRegistry = ISuperChainBridgeTokenRegistry(vm.parseJsonAddress(bridgeJson, ".bridgeTokenRegistry"));
        config.approvedRegistry =
            IApprovedMessageSenderRegistry(vm.parseJsonAddress(bridgeJson, ".approvedMessageSenderRegistry"));
        config.localRelayer = vm.parseJsonAddress(bridgeJson, ".tokenTransferRelayer");
        config.inventoryDetf = vm.parseJsonAddress(detfJson, ".inventoryDetf");
        config.pairToken = vm.parseJsonAddress(detfJson, ".pairToken");
    }

    function _readRemoteConfig(string memory remoteDir) internal view returns (RemoteConfig memory config) {
        string memory bridgeJson = vm.readFile(string.concat(remoteDir, "/24_superchain_bridge.json"));
        string memory detfJson = vm.readFile(string.concat(remoteDir, "/16_protocol_detf.json"));

        config.peerRelayer = vm.parseJsonAddress(bridgeJson, ".tokenTransferRelayer");
        config.inventoryDetf = vm.parseJsonAddress(detfJson, ".inventoryDetf");
        config.pairToken = vm.parseJsonAddress(detfJson, ".pairToken");
    }

    function _chainBridgeConfig() internal view returns (ChainBridgeConfig memory config) {
        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return ChainBridgeConfig({peerChainId: BASE_SEPOLIA.CHAIN_ID});
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return ChainBridgeConfig({peerChainId: ETHEREUM_SEPOLIA.CHAIN_ID});
        }

        revert("Unsupported chain for SuperSim bridge bootstrap");
    }

    function _exportJson(
        string memory localDir,
        LocalConfig memory localConfig,
        RemoteConfig memory remoteConfig,
        ChainBridgeConfig memory chainConfig
    ) internal {
        string memory json;
        json = vm.serializeUint("", "localChainId", block.chainid);
        json = vm.serializeUint("", "peerChainId", chainConfig.peerChainId);
        json = vm.serializeAddress("", "bridgeTokenRegistry", address(localConfig.bridgeTokenRegistry));
        json = vm.serializeAddress("", "approvedMessageSenderRegistry", address(localConfig.approvedRegistry));
        json = vm.serializeAddress("", "localRelayer", localConfig.localRelayer);
        json = vm.serializeAddress("", "peerRelayer", remoteConfig.peerRelayer);
        json = vm.serializeAddress("", "inventoryDetf", localConfig.inventoryDetf);
        json = vm.serializeAddress("", "peerProtocolDetf", remoteConfig.inventoryDetf);

        SuperSimManifestLib.writeJson(vm, localDir, "25_superchain_bridge_config.json", json);
    }

    function _logResults(
        LocalConfig memory localConfig,
        RemoteConfig memory remoteConfig,
        ChainBridgeConfig memory chainConfig
    ) internal view {
        console2.log("Configured Protocol DETF bridge");
        console2.log("Local chain:", block.chainid);
        console2.log("Peer chain:", chainConfig.peerChainId);
        console2.log("Local DETF:", localConfig.inventoryDetf);
        console2.log("Peer DETF:", remoteConfig.inventoryDetf);
    }

    function _requiredEnvString(string memory key) internal view returns (string memory value) {
        value = vm.envString(key);
        require(bytes(value).length > 0, "Missing required env string");
    }
}