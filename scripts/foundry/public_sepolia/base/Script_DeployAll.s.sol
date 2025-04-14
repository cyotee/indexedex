// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {Script_01_DeployFactories} from "../../anvil_base_main/Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "../../anvil_base_main/Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "../../anvil_base_main/Script_03_DeployCoreProxies.s.sol";
import {Script_03A_DeployUniswapV2Core} from "../../supersim/base/Script_03A_DeployUniswapV2Core.s.sol";
import {Script_03B_DeployBalancerV3Core} from "../../supersim/base/Script_03B_DeployBalancerV3Core.s.sol";
import {Script_03C_DeployAerodromeCore} from "../../supersim/base/Script_03C_DeployAerodromeCore.s.sol";
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

import {Script_ExportTokenlists} from "./Script_ExportTokenlists.s.sol";

// Use local Script_16 which only deploys packages (no WETH funding)
import {Script_16_DeployProtocolDETF} from "./Script_16_DeployProtocolDETF.s.sol";

contract Script_DeployAll is DeploymentBase, Script_16_DeployProtocolDETF {
    function run() external override {
        string memory outDir = _localOutDir();
        vm.setEnv("OUT_DIR_OVERRIDE", outDir);
        vm.setEnv("NETWORK_PROFILE", "base_sepolia");

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

        // Stage 15 - Seigniorage DETFs
        new Script_15_DeploySeigniorageDETFS().run();

        // Stage 16 - Protocol DETF (packages only, no funding)
        _runProtocolDetfStage16();

        new Script_ExportTokenlists().run();
    }
}
