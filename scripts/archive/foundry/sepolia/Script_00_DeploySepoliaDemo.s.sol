// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script_01_DeployFactories} from "./Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "./Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "./Script_03_DeployCoreProxies.s.sol";
import {Script_04_DeployDEXPackages_BalancerV3} from "./Script_04_DeployDEXPackages_BalancerV3.s.sol";
import {Script_05_DeployUniswapV2} from "./Script_05_DeployUniswapV2.s.sol";
import {Script_06_DeployAerodrome} from "./Script_06_DeployAerodrome.s.sol";
import {Script_07_DeployTestTokens} from "./Script_07_DeployTestTokens.s.sol";
import {Script_08_DeployPools} from "./Script_08_DeployPools.s.sol";
import {Script_09_DeployStrategyVaults} from "./Script_09_DeployStrategyVaults.s.sol";
import {Script_10_DepositBaseLiquidity} from "./Script_10_DepositBaseLiquidity.s.sol";
import {Script_11_DeployStandardExchangeRateProviders} from "./Script_11_DeployStandardExchangeRateProviders.s.sol";
import {Script_12_DeployBalancerConstProdVaultTokenPools} from "./Script_12_DeployBalancerConstProdVaultTokenPools.s.sol";
import {Script_13_SeedBalancerVaultTokenPoolLiquidity} from "./Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol";
import {Script_14_DeployERC4626PermitVaults} from "./Script_14_DeployERC4626PermitVaults.s.sol";
import {Script_15_DeploySeigniorageDETFS} from "./Script_15_DeploySeigniorageDETFS.s.sol";
import {Script_ExportTokenlists} from "./Script_ExportTokenlists.s.sol";

contract Script_00_DeploySepoliaDemo {
    function run() external {
        new Script_01_DeployFactories().run();
        new Script_02_DeploySharedFacets().run();
        new Script_03_DeployCoreProxies().run();
        new Script_04_DeployDEXPackages_BalancerV3().run();
        new Script_05_DeployUniswapV2().run();
        new Script_06_DeployAerodrome().run();
        new Script_07_DeployTestTokens().run();
        new Script_08_DeployPools().run();
        new Script_09_DeployStrategyVaults().run();
        new Script_10_DepositBaseLiquidity().run();
        new Script_11_DeployStandardExchangeRateProviders().run();
        new Script_12_DeployBalancerConstProdVaultTokenPools().run();
        new Script_13_SeedBalancerVaultTokenPoolLiquidity().run();
        new Script_14_DeployERC4626PermitVaults().run();
        new Script_15_DeploySeigniorageDETFS().run();
        new Script_ExportTokenlists().run();
    }
}