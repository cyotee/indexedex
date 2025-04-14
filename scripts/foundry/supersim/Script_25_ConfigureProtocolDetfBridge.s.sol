// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {IApprovedMessageSenderRegistry} from "@crane/contracts/interfaces/IApprovedMessageSenderRegistry.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

import {SuperSimManifestLib} from "./SuperSimManifestLib.sol";

contract Script_25_ConfigureProtocolDetfBridge is Script {
    uint32 internal constant BRIDGE_MIN_GAS_LIMIT = 250_000;

    function run() external {
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

        bytes memory initData = _buildBridgeInitData(
            localConfig.bridgeTokenRegistry,
            chainConfig.standardBridge,
            chainConfig.messenger,
            localConfig.localRelayer,
            chainConfig.peerChainId,
            remoteConfig.peerRelayer
        );

        if (privateKey != 0) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast(deployer);
        }

        localConfig.bridgeTokenRegistry.setRemoteToken(
            chainConfig.peerChainId,
            IERC20(localConfig.protocolDetf),
            IERC20(remoteConfig.protocolDetf),
            0
        );
        localConfig.bridgeTokenRegistry.setRemoteToken(
            chainConfig.peerChainId,
            IERC20(localConfig.richToken),
            IERC20(remoteConfig.richToken),
            BRIDGE_MIN_GAS_LIMIT
        );
        localConfig.approvedRegistry.approveSender(localConfig.protocolDetf, remoteConfig.protocolDetf);

        (bool success,) = localConfig.protocolDetf.call(abi.encodeWithSignature("initBridge(bytes)", initData));
        require(success, "initBridge failed");

        vm.stopBroadcast();

        _exportJson(localDir, localConfig, remoteConfig, chainConfig);
        _logResults(localConfig, remoteConfig, chainConfig);
    }

    struct LocalConfig {
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IApprovedMessageSenderRegistry approvedRegistry;
        address localRelayer;
        address protocolDetf;
        address richToken;
    }

    struct RemoteConfig {
        address peerRelayer;
        address protocolDetf;
        address richToken;
    }

    struct ChainBridgeConfig {
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        uint256 peerChainId;
    }

    function _readLocalConfig(string memory localDir) internal view returns (LocalConfig memory config) {
        string memory bridgeJson = vm.readFile(string.concat(localDir, "/24_superchain_bridge.json"));
        string memory detfJson = vm.readFile(string.concat(localDir, "/16_protocol_detf.json"));

        config.bridgeTokenRegistry = ISuperChainBridgeTokenRegistry(vm.parseJsonAddress(bridgeJson, ".bridgeTokenRegistry"));
        config.approvedRegistry =
            IApprovedMessageSenderRegistry(vm.parseJsonAddress(bridgeJson, ".approvedMessageSenderRegistry"));
        config.localRelayer = vm.parseJsonAddress(bridgeJson, ".tokenTransferRelayer");
        config.protocolDetf = vm.parseJsonAddress(detfJson, ".protocolDetf");
        config.richToken = vm.parseJsonAddress(detfJson, ".richToken");
    }

    function _readRemoteConfig(string memory remoteDir) internal view returns (RemoteConfig memory config) {
        string memory bridgeJson = vm.readFile(string.concat(remoteDir, "/24_superchain_bridge.json"));
        string memory detfJson = vm.readFile(string.concat(remoteDir, "/16_protocol_detf.json"));

        config.peerRelayer = vm.parseJsonAddress(bridgeJson, ".tokenTransferRelayer");
        config.protocolDetf = vm.parseJsonAddress(detfJson, ".protocolDetf");
        config.richToken = vm.parseJsonAddress(detfJson, ".richToken");
    }

    function _chainBridgeConfig() internal view returns (ChainBridgeConfig memory config) {
        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return ChainBridgeConfig({
                standardBridge: IStandardBridge(payable(ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE)),
                messenger: ICrossDomainMessenger(ETHEREUM_SEPOLIA.BASE_L1_CROSS_DOMAIN_MESSENGER),
                peerChainId: BASE_SEPOLIA.CHAIN_ID
            });
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return ChainBridgeConfig({
                standardBridge: IStandardBridge(payable(BASE_SEPOLIA.L2_STANDARD_BRIDGE)),
                messenger: ICrossDomainMessenger(BASE_SEPOLIA.L2_CROSSDOMAIN_MESSENGER),
                peerChainId: ETHEREUM_SEPOLIA.CHAIN_ID
            });
        }

        revert("Unsupported chain for SuperSim bridge bootstrap");
    }

    function _buildBridgeInitData(
        ISuperChainBridgeTokenRegistry registry,
        IStandardBridge standardBridge,
        ICrossDomainMessenger messenger,
        address localRelayer,
        uint256 peerChainId,
        address peerRelayer
    ) internal pure returns (bytes memory initData) {
        uint256[] memory peerChainIds = new uint256[](1);
        address[] memory peerRelayers = new address[](1);

        peerChainIds[0] = peerChainId;
        peerRelayers[0] = peerRelayer;

        initData = abi.encode(
            ProtocolDETFSuperchainBridgeRepo.InitData({
                bridgeTokenRegistry: registry,
                standardBridge: standardBridge,
                messenger: messenger,
                localRelayer: localRelayer,
                peerChainIds: peerChainIds,
                peerRelayers: peerRelayers
            })
        );
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
        json = vm.serializeAddress("", "protocolDetf", localConfig.protocolDetf);
        json = vm.serializeAddress("", "peerProtocolDetf", remoteConfig.protocolDetf);

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
        console2.log("Local DETF:", localConfig.protocolDetf);
        console2.log("Peer DETF:", remoteConfig.protocolDetf);
    }

    function _requiredEnvString(string memory key) internal view returns (string memory value) {
        value = vm.envString(key);
        require(bytes(value).length > 0, "Missing required env string");
    }
}