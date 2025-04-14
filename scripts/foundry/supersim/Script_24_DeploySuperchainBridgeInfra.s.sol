// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IApprovedMessageSenderRegistry} from "@crane/contracts/interfaces/IApprovedMessageSenderRegistry.sol";
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {ApprovedMessageSenderRegistryFactoryService} from "@crane/contracts/protocols/l2s/superchain/registries/message/sender/ApprovedMessageSenderRegistryFactoryService.sol";
import {SuperChainBridgeTokenRegistryFactoryService} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol";
import {TokenTransferRelayerFactoryService} from "@crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerFactoryService.sol";

import {SuperSimManifestLib} from "./SuperSimManifestLib.sol";

contract Script_24_DeploySuperchainBridgeInfra is Script {
    uint256 private privateKey;
    address private deployer;
    address private owner;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondFactory;

    ISuperChainBridgeTokenRegistry private bridgeTokenRegistry;
    IApprovedMessageSenderRegistry private approvedMessageSenderRegistry;
    ITokenTransferRelayer private tokenTransferRelayer;

    function run() external {
        _loadConfig();
        _loadFactories();

        if (privateKey != 0) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast(deployer);
        }

        bridgeTokenRegistry = _deployBridgeRegistry();
        approvedMessageSenderRegistry = _deployApprovedRegistry();
        tokenTransferRelayer = _deployRelayer(approvedMessageSenderRegistry);

        vm.stopBroadcast();

        _exportJson();
        _logResults();
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
            deployer = vm.addr(envKey);
        } catch {}

        try vm.envAddress("OWNER") returns (address envOwner) {
            owner = envOwner;
        } catch {
            owner = deployer;
        }
    }

    function _loadFactories() internal {
        string memory deploymentsDir = _outDir();
        string memory factoriesPath = string.concat(deploymentsDir, "/01_factories.json");
        string memory json = vm.readFile(factoriesPath);

        create3Factory = ICreate3FactoryProxy(vm.parseJsonAddress(json, ".create3Factory"));
        diamondFactory = IDiamondPackageCallBackFactory(vm.parseJsonAddress(json, ".diamondPackageFactory"));
    }

    function _deployApprovedRegistry() internal returns (IApprovedMessageSenderRegistry registry) {
        IFacet registryFacet = ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryFacet(create3Factory);
        IFacet ownableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet operableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IOperable).interfaceId);

        registry = ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistry(
            diamondFactory,
            ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryDFPkg(
                create3Factory,
                ownableFacet,
                operableFacet,
                registryFacet
            ),
            owner
        );
    }

    function _deployBridgeRegistry() internal returns (ISuperChainBridgeTokenRegistry registry) {
        IFacet ownableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet operableFacet = IFacetRegistry(address(create3Factory)).canonicalFacet(type(IOperable).interfaceId);

        registry = SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistry(
            diamondFactory,
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                create3Factory,
                ownableFacet,
                operableFacet,
                SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryFacet(create3Factory)
            ),
            owner
        );
    }

    function _deployRelayer(IApprovedMessageSenderRegistry registry) internal returns (ITokenTransferRelayer relayer) {
        relayer = TokenTransferRelayerFactoryService.deployTokenTransferRelayer(
            diamondFactory,
            TokenTransferRelayerFactoryService.deployTokenTransferRelayerDFPkg(
                create3Factory,
                IFacetRegistry(address(create3Factory)).canonicalFacet(type(IMultiStepOwnable).interfaceId),
                TokenTransferRelayerFactoryService.deployTokenTransferRelayerFacet(create3Factory),
                _permit2()
            ),
            owner,
            registry
        );
    }

    function _permit2() internal view returns (IPermit2 permit2_) {
        if (block.chainid == ETHEREUM_SEPOLIA.CHAIN_ID) {
            return IPermit2(ETHEREUM_SEPOLIA.PERMIT2);
        }

        if (block.chainid == BASE_SEPOLIA.CHAIN_ID) {
            return IPermit2(BASE_SEPOLIA.PERMIT2);
        }

        revert("Unsupported chain for Permit2 binding");
    }

    function _readAddress(string memory key) internal view returns (address addr) {
        string memory deploymentsDir = _outDir();
        string memory summaryPath = string.concat(deploymentsDir, "/deployment_summary.json");
        string memory summaryJson = vm.readFile(summaryPath);
        addr = vm.parseJsonAddress(summaryJson, string.concat(".", key));
    }

    function _exportJson() internal {
        string memory deploymentsDir = _outDir();

        string memory json;
        json = vm.serializeAddress("", "bridgeTokenRegistry", address(bridgeTokenRegistry));
        json = vm.serializeAddress("", "approvedMessageSenderRegistry", address(approvedMessageSenderRegistry));
        json = vm.serializeAddress("", "tokenTransferRelayer", address(tokenTransferRelayer));

        SuperSimManifestLib.writeJson(vm, deploymentsDir, "24_superchain_bridge.json", json);
    }

    function _logResults() internal view {
        console2.log("Superchain bridge infra deployed");
        console2.log("Bridge registry:", address(bridgeTokenRegistry));
        console2.log("Approved sender registry:", address(approvedMessageSenderRegistry));
        console2.log("Token transfer relayer:", address(tokenTransferRelayer));
    }

    function _outDir() internal view returns (string memory outDir) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory overrideDir) {
            if (bytes(overrideDir).length > 0) {
                return overrideDir;
            }
        } catch {}

        revert("OUT_DIR_OVERRIDE is required");
    }
}