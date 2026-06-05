// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import { betterconsole as console } from "@crane/contracts/utils/vm/foundry/tools/betterconsole.sol";

import {Script_01_DeployFactories} from "../../anvil_base_main/Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "../../anvil_base_main/Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "../../anvil_base_main/Script_03_DeployCoreProxies.s.sol";
import {Script_03A_DeployUniswapV2Core} from "./Script_03A_DeployUniswapV2Core.s.sol";
import {Script_03B_DeployBalancerV3Core} from "./Script_03B_DeployBalancerV3Core.s.sol";
import {Script_03C_DeployAerodromeCore} from "./Script_03C_DeployAerodromeCore.s.sol";
import {Script_04_DeployDEXPackages} from "../../anvil_base_main/Script_04_DeployDEXPackages.s.sol";
import {Script_05_DeployTestTokens} from "../../anvil_base_main/Script_05_DeployTestTokens.s.sol";
import {Script_06_DeployPools} from "../../anvil_base_main/Script_06_DeployPools.s.sol";
import {Script_07_DeployStrategyVaults} from "../../anvil_base_main/Script_07_DeployStrategyVaults.s.sol";
import {Script_08_DeployAerodromeStrategyVaults} from "../../anvil_base_main/Script_08_DeployAerodromeStrategyVaults.s.sol";
import {Script_09_DeployBalancerConstProdPools} from "../../anvil_base_main/Script_09_DeployBalancerConstProdPools.s.sol";
import {Script_10_DepositBaseLiquidity} from "../../anvil_base_main/Script_10_DepositBaseLiquidity.s.sol";
import {Script_11_DeployStandardExchangeRateProviders} from "../../anvil_base_main/Script_11_DeployStandardExchangeRateProviders.s.sol";
import {Script_12_DeployBalancerConstProdVaultTokenPools} from "../../anvil_base_main/Script_12_DeployBalancerConstProdVaultTokenPools.s.sol";
import {Script_13_SeedBalancerVaultTokenPoolLiquidity} from "../../anvil_base_main/Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol";
import {Script_14_DeployERC4626PermitVaults} from "../../anvil_base_main/Script_14_DeployERC4626PermitVaults.s.sol";
import {Script_15_DeploySeigniorageDETFS} from "../../anvil_base_main/Script_15_DeploySeigniorageDETFS.s.sol";
import {Script_16_DeployProtocolDETF} from "../../anvil_base_main/Script_16_DeployProtocolDETF.s.sol";

import {Script_17_WethTtcPoolsAndVaults} from "./Script_17_WethTtcPoolsAndVaults.s.sol";
import {Script_18_WethTtcBalancerPools} from "./Script_18_WethTtcBalancerPools.s.sol";
import {Script_ExportTokenlists} from "./Script_ExportTokenlists.s.sol";

import {DeploymentBase} from "./DeploymentBase.sol";
import {SuperSimManifestLib} from "../SuperSimManifestLib.sol";

contract Script_DeployAll is DeploymentBase, Script_16_DeployProtocolDETF {
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
        new Script_05_DeployTestTokens().run();
        new Script_06_DeployPools().run();
        new Script_07_DeployStrategyVaults().run();
        new Script_08_DeployAerodromeStrategyVaults().run();
        new Script_09_DeployBalancerConstProdPools().run();
        new Script_10_DepositBaseLiquidity().run();
        new Script_11_DeployStandardExchangeRateProviders().run();
        new Script_12_DeployBalancerConstProdVaultTokenPools().run();
        new Script_13_SeedBalancerVaultTokenPoolLiquidity().run();
        new Script_14_DeployERC4626PermitVaults().run();

        _runStage15();
        _runStage16();
        _runStage17();
        new Script_18_WethTtcBalancerPools().run();
        new Script_ExportTokenlists().run();

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

    function _runStage15() internal {
        console.log("[BaseDeployAll] Dispatching Stage 15: Seigniorage DETFs");

        Script_15_DeploySeigniorageDETFS stage15 = new Script_15_DeploySeigniorageDETFS();
        console.log("[BaseDeployAll] Stage 15 contract instantiated");

        try stage15.run() {
            console.log("[BaseDeployAll] Stage 15 returned successfully");
        } catch (bytes memory reason) {
            console.log("[BaseDeployAll] Stage 15 reverted");
            console.log("[BaseDeployAll] Stage 15 revert bytes length", reason.length);
            _revertWith(reason);
        }
    }

    function _runStage16() internal {
        console.log("[BaseDeployAll] Dispatching Stage 16 inline: Protocol DETF (CHIR)");
        _runProtocolDetfStage16();
        console.log("[BaseDeployAll] Stage 16 returned successfully");
    }

    function _runStage17() internal {
        console.log("[BaseDeployAll] Dispatching Stage 17: WETH/TTC Pools and Vaults");

        Script_17_WethTtcPoolsAndVaults stage17 = new Script_17_WethTtcPoolsAndVaults();
        console.log("[BaseDeployAll] Stage 17 contract instantiated");

        try stage17.run() {
            console.log("[BaseDeployAll] Stage 17 returned successfully");
        } catch (bytes memory reason) {
            console.log("[BaseDeployAll] Stage 17 reverted");
            console.log("[BaseDeployAll] Stage 17 revert bytes length", reason.length);
            _revertWith(reason);
        }
    }

    function _revertWith(bytes memory reason) internal pure {
        if (reason.length == 0) {
            revert();
        }

        assembly {
            revert(add(reason, 0x20), mload(reason))
        }
    }
}
