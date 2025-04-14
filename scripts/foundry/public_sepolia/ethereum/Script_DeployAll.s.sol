// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase as AnvilDeploymentBase} from "../../anvil_sepolia/DeploymentBase.sol";

import {Script_01_DeployFactories} from "../../anvil_sepolia/Script_01_DeployFactories.s.sol";
import {Script_02_DeploySharedFacets} from "../../anvil_sepolia/Script_02_DeploySharedFacets.s.sol";
import {Script_03_DeployCoreProxies} from "../../anvil_sepolia/Script_03_DeployCoreProxies.s.sol";
import {Script_04_DeployDEXPackages_BalancerV3} from "../../anvil_sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol";
import {Script_05_DeployUniswapV2} from "../../anvil_sepolia/Script_05_DeployUniswapV2.s.sol";
import {Script_07_DeployTestTokens} from "../../anvil_sepolia/Script_07_DeployTestTokens.s.sol";
import {Script_14_DeployERC4626PermitVaults} from "../../anvil_sepolia/Script_14_DeployERC4626PermitVaults.s.sol";
import {Script_15_DeploySeigniorageDETFS} from "../../anvil_sepolia/Script_15_DeploySeigniorageDETFS.s.sol";
import {Script_16_DeployProtocolDETF} from "./Script_16_DeployProtocolDETF.s.sol";

import {Script_04_NonWethUniV2PoolsAndVaults} from "./Script_04_NonWethUniV2PoolsAndVaults.s.sol";
import {Script_05_NonWethBalancerPools} from "./Script_05_NonWethBalancerPools.s.sol";
import {Script_ExportTokenlists} from "./Script_ExportTokenlists.s.sol";

contract DeploymentBase is AnvilDeploymentBase {
    function _localOutDir() internal view returns (string memory) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory value) {
            if (bytes(value).length > 0) {
                return value;
            }
        } catch {}

        revert("OUT_DIR_OVERRIDE must be set");
    }
}

contract Script_DeployAll is DeploymentBase, Script_16_DeployProtocolDETF {
    function run() external override {
        string memory outDir = _localOutDir();
        vm.setEnv("OUT_DIR_OVERRIDE", outDir);
        vm.setEnv("NETWORK_PROFILE", "ethereum_sepolia");

        new Script_01_DeployFactories().run();
        new Script_02_DeploySharedFacets().run();
        new Script_03_DeployCoreProxies().run();
        new Script_04_DeployDEXPackages_BalancerV3().run();
        new Script_05_DeployUniswapV2().run();
        new Script_07_DeployTestTokens().run();
        new Script_04_NonWethUniV2PoolsAndVaults().run();
        new Script_05_NonWethBalancerPools().run();
        new Script_14_DeployERC4626PermitVaults().run();
        new Script_15_DeploySeigniorageDETFS().run();

        _runStage16();
        new Script_ExportTokenlists().run();
    }

    function _runStage16() internal {
        _runProtocolDetfStage16();
    }
}
