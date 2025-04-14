// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Script_01_DeployFactories} from "../../anvil_base_main/Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "../../anvil_base_main/Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "../../anvil_base_main/Script_03_DeployCoreProxies.s.sol";
import {Script_04_DeployDEXPackages} from "../../anvil_base_main/Script_04_DeployDEXPackages.s.sol";
import {Script_16_DeployProtocolDETF} from "../../anvil_base_main/Script_16_DeployProtocolDETF.s.sol";

import {Script_03A_DeployUniswapV2Core} from "./Script_03A_DeployUniswapV2Core.s.sol";
import {Script_03B_DeployBalancerV3Core} from "./Script_03B_DeployBalancerV3Core.s.sol";
import {Script_03C_DeployAerodromeCore} from "./Script_03C_DeployAerodromeCore.s.sol";

import {DeploymentBase} from "./DeploymentBase.sol";
import {SuperSimManifestLib} from "../SuperSimManifestLib.sol";

contract Script_DeployProtocolDetfMinimal is DeploymentBase, Script_16_DeployProtocolDETF {
    function validateEnvironment() external view {
        _requireSupportedBaseSepoliaDeps();
    }

    function run() external override {
        string memory outDir = _localOutDir();
        vm.setEnv("OUT_DIR_OVERRIDE", outDir);
        vm.setEnv("NETWORK_PROFILE", "base_sepolia");

        _requireSupportedBaseSepoliaDeps();

        new Script_01_DeployFactories().run();
        new Script_02_DeploySharedFacets().run();
        new Script_03_DeployCoreProxies().run();
        new Script_03A_DeployUniswapV2Core().run();
        new Script_03B_DeployBalancerV3Core().run();
        new Script_03C_DeployAerodromeCore().run();
        new Script_04_DeployDEXPackages().run();

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

    function _requireSupportedBaseSepoliaDeps() internal pure {
    }
}