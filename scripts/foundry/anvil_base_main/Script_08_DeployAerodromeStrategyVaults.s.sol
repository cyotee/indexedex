// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/// @title Script_08_DeployAerodromeStrategyVaults
/// @notice Deploy Aerodrome standard-exchange vaults for the stage-6 Aerodrome pools
contract Script_08_DeployAerodromeStrategyVaults is DeploymentBase {
    // Inputs
    IPool private aeroAbPool;
    IPool private aeroAcPool;
    IPool private aeroBcPool;

    // Package
    IAerodromeStandardExchangeDFPkg private aerodromePkg;

    // Deployed strategy vaults (standard exchange vaults)
    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 8: Deploy Aerodrome Strategy Vaults");

        vm.startBroadcast();
        _deployStrategyVaults();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        // Load pools (stage 6)
        aeroAbPool = IPool(_readAddress("06_pools.json", "aeroAbPool"));
        aeroAcPool = IPool(_readAddress("06_pools.json", "aeroAcPool"));
        aeroBcPool = IPool(_readAddress("06_pools.json", "aeroBcPool"));

        // Load DEX packages (stage 4)
        aerodromePkg = IAerodromeStandardExchangeDFPkg(_readAddress("04_dex_packages.json", "aerodromePkg"));
        require(address(aerodromePkg) != address(0), "Aerodrome pkg not found");
    }

    function _deployStrategyVaults() internal {
        aeroAbVault = address(aerodromePkg.deployVault(aeroAbPool));
        aeroAcVault = address(aerodromePkg.deployVault(aeroAcPool));
        aeroBcVault = address(aerodromePkg.deployVault(aeroBcPool));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "aeroAbVault", aeroAbVault);
        json = vm.serializeAddress("", "aeroAcVault", aeroAcVault);
        json = vm.serializeAddress("", "aeroBcVault", aeroBcVault);
        _writeJson(json, "08_aerodrome_strategy_vaults.json");
    }

    function _logResults() internal view {
        _logAddress("Aerodrome A-B Vault:", aeroAbVault);
        _logAddress("Aerodrome A-C Vault:", aeroAcVault);
        _logAddress("Aerodrome B-C Vault:", aeroBcVault);
        _logComplete("Stage 8");
    }
}
