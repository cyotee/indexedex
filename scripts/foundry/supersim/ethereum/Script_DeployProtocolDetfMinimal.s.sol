// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script_01_DeployFactories} from "../../anvil_sepolia/Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "../../anvil_sepolia/Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "../../anvil_sepolia/Script_03_DeployCoreProxies.s.sol";
import {Script_04_DeployDEXPackages_BalancerV3} from "../../anvil_sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol";
import {Script_05_DeployUniswapV2} from "../../anvil_sepolia/Script_05_DeployUniswapV2.s.sol";
import {Script_16_DeployProtocolDETF} from "../../anvil_sepolia/Script_16_DeployProtocolDETF.s.sol";

import {DeploymentBase} from "./DeploymentBase.sol";
import {SuperSimManifestLib} from "../SuperSimManifestLib.sol";

contract Script_DeployProtocolDetfMinimal is DeploymentBase, Script_16_DeployProtocolDETF {
    function run() external override {
        string memory outDir = _localOutDir();
        vm.setEnv("OUT_DIR_OVERRIDE", outDir);
        vm.setEnv("NETWORK_PROFILE", "ethereum_sepolia");

        new Script_01_DeployFactories().run();
        new Script_02_DeploySharedFacets().run();
        new Script_03_DeployCoreProxies().run();
        new Script_04_DeployDEXPackages_BalancerV3().run();
        new Script_05_DeployUniswapV2().run();

        _runProtocolDetfStage16();
        _writeChainManifest(outDir);
    }

    function _writeChainManifest(string memory outDir) internal {
        string memory json;
        json = vm.serializeString("", "environment", SuperSimManifestLib.ENVIRONMENT);
        json = vm.serializeString("", "chainRole", _chainRole());
        json = vm.serializeString("", "outDir", outDir);
        json = vm.serializeString("", "frontendDir", _frontendOutDir(_chainRole()));
        SuperSimManifestLib.writeJson(vm, outDir, "chain_manifest.json", json);
    }
}