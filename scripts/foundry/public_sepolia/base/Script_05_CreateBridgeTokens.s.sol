// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";

import {BridgeTokenPlanning} from "../shared/BridgeTokenPlanning.sol";
import {SharedDeploymentBase} from "../shared/SharedDeploymentBase.sol";

interface IOptimismMintableERC20Factory {
    function createOptimismMintableERC20(address remoteToken, string memory name, string memory symbol)
        external
        returns (address);
}

contract Script_05_CreateBridgeTokens is SharedDeploymentBase {
    address private ttaL1;
    address private ttbL1;
    address private ttcL1;
    address private demoWethL1;
    address private richL1;

    address private ttaL2;
    address private ttbL2;
    address private ttcL2;
    address private demoWethL2;
    address private richL2;

    function run() external {
        _setupShared();
        _loadL1SourceTokens();

        vm.startBroadcast();
        _createBridgeTokens();
        vm.stopBroadcast();

        _exportBaseArtifact();
        _exportSharedManifest();
    }

    function _loadL1SourceTokens() internal {
        string memory ethereumOutDir = _ethereumOutDir();
        ttaL1 = _readAddressFrom(ethereumOutDir, "07_test_tokens.json", "testTokenA");
        ttbL1 = _readAddressFrom(ethereumOutDir, "07_test_tokens.json", "testTokenB");
        ttcL1 = _readAddressFrom(ethereumOutDir, "07_test_tokens.json", "testTokenC");
        demoWethL1 = _readAddressFrom(ethereumOutDir, "07_test_tokens.json", "demoWeth");
        richL1 = _readAddressFrom(ethereumOutDir, "07_test_tokens.json", "richToken");
    }

    function _createBridgeTokens() internal {
        ttaL2 = _createOrReuseToken(
            "05_bridge_tokens.json",
            "testTokenA",
            ttaL1,
            BridgeTokenPlanning.wrappedName("Test Token A"),
            BridgeTokenPlanning.wrappedSymbol("TTA")
        );
        ttbL2 = _createOrReuseToken(
            "05_bridge_tokens.json",
            "testTokenB",
            ttbL1,
            BridgeTokenPlanning.wrappedName("Test Token B"),
            BridgeTokenPlanning.wrappedSymbol("TTB")
        );
        ttcL2 = _createOrReuseToken(
            "05_bridge_tokens.json",
            "testTokenC",
            ttcL1,
            BridgeTokenPlanning.wrappedName("Test Token C"),
            BridgeTokenPlanning.wrappedSymbol("TTC")
        );
        demoWethL2 = _createOrReuseToken(
            "05_bridge_tokens.json",
            "demoWeth",
            demoWethL1,
            BridgeTokenPlanning.wrappedName("DemoWETH"),
            BridgeTokenPlanning.wrappedSymbol("DemoWETH")
        );
        richL2 = _createOrReuseToken(
            "05_bridge_tokens.json",
            "richToken",
            richL1,
            BridgeTokenPlanning.wrappedName("Rich Token"),
            BridgeTokenPlanning.wrappedSymbol("RICH")
        );
    }

    function _createOrReuseToken(
        string memory artifact,
        string memory key,
        address remoteToken,
        string memory name,
        string memory symbol
    ) internal returns (address token) {
        (address existing, bool exists) = _readAddressFromSafe(_baseOutDir(), artifact, key);
        if (exists && existing != address(0) && existing.code.length > 0) {
            return existing;
        }

        return IOptimismMintableERC20Factory(BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY).createOptimismMintableERC20(
            remoteToken, name, symbol
        );
    }

    function _exportBaseArtifact() internal {
        string memory json;
        json = vm.serializeAddress("bridgeTokens", "testTokenA", ttaL2);
        json = vm.serializeAddress("bridgeTokens", "testTokenB", ttbL2);
        json = vm.serializeAddress("bridgeTokens", "testTokenC", ttcL2);
        json = vm.serializeAddress("bridgeTokens", "demoWeth", demoWethL2);
        json = vm.serializeAddress("bridgeTokens", "richToken", richL2);
        json = vm.serializeAddress("bridgeTokens", "l2StandardBridge", BASE_SEPOLIA.L2_STANDARD_BRIDGE);
        json = vm.serializeAddress("bridgeTokens", "optimismMintableErc20Factory", BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY);
        _writeJsonTo(_baseOutDir(), "05_bridge_tokens.json", json);
    }

    function _exportSharedManifest() internal {
        string memory json;
        json = vm.serializeUint("bridgeManifest", "sourceChainId", BridgeTokenPlanning.SOURCE_CHAIN_ID);
        json = vm.serializeUint("bridgeManifest", "destinationChainId", BridgeTokenPlanning.DESTINATION_CHAIN_ID);
        json = vm.serializeAddress("bridgeManifest", "l1StandardBridge", 0xfd0Bf71F60660E2f608ed56e1659C450eB113120);
        json = vm.serializeAddress("bridgeManifest", "l2StandardBridge", BASE_SEPOLIA.L2_STANDARD_BRIDGE);
        json = vm.serializeAddress("bridgeManifest", "optimismMintableErc20Factory", BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY);
        json = vm.serializeAddress("bridgeManifest", "ttaL1Token", ttaL1);
        json = vm.serializeAddress("bridgeManifest", "ttaL2Token", ttaL2);
        json = vm.serializeAddress("bridgeManifest", "ttbL1Token", ttbL1);
        json = vm.serializeAddress("bridgeManifest", "ttbL2Token", ttbL2);
        json = vm.serializeAddress("bridgeManifest", "ttcL1Token", ttcL1);
        json = vm.serializeAddress("bridgeManifest", "ttcL2Token", ttcL2);
        json = vm.serializeAddress("bridgeManifest", "demoWethL1Token", demoWethL1);
        json = vm.serializeAddress("bridgeManifest", "demoWethL2Token", demoWethL2);
        json = vm.serializeAddress("bridgeManifest", "richL1Token", richL1);
        json = vm.serializeAddress("bridgeManifest", "richL2Token", richL2);
        _writeJsonTo(_sharedOutDir(), "bridge_token_manifest.json", json);
    }
}