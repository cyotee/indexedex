// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IPool as IAerodromePool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

/// @title Script_18_DeployWethTtcVaults
/// @notice Deploys UniV2 + Aerodrome Standard Exchange vaults for the WETH/TTC pools.
contract Script_18_DeployWethTtcVaults is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;
    IAerodromeStandardExchangeDFPkg private aerodromePkg;

    IUniswapV2Pair private uniWethcPool;
    IAerodromePool private aeroWethcPool;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    address private uniWethcVault;
    address private aeroWethcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 18: Deploy WETH/TTC Strategy Vaults");

        vm.startBroadcast();
        _deployVaults();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        uniV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress("04_dex_packages.json", "uniswapV2Pkg"));
        require(address(uniV2Pkg) != address(0), "UniswapV2Pkg not found");

        aerodromePkg = IAerodromeStandardExchangeDFPkg(_readAddress("04_dex_packages.json", "aerodromePkg"));
        require(address(aerodromePkg) != address(0), "AerodromePkg not found");

        uniWethcPool = IUniswapV2Pair(_readAddress("17_weth_ttc_pools.json", "uniWethcPool"));
        aeroWethcPool = IAerodromePool(_readAddress("17_weth_ttc_pools.json", "aeroWethcPool"));

        require(address(uniWethcPool) != address(0), "UniV2 WETH/TTC pool not found");
        require(address(aeroWethcPool) != address(0), "Aerodrome WETH/TTC pool not found");
    }

    function _deployVaults() internal {
        uniWethcVault = uniV2Pkg.deployVault(uniWethcPool);
        aeroWethcVault = aerodromePkg.deployVault(aeroWethcPool);

        vm.label(uniWethcVault, "UniV2 WETH/TTC Strategy Vault");
        vm.label(aeroWethcVault, "Aerodrome WETH/TTC Strategy Vault");
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("", "uniWethcVault", uniWethcVault);
        json = vm.serializeAddress("", "aeroWethcVault", aeroWethcVault);
        _writeJson(json, "18_weth_ttc_vaults.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 WETH/TTC Vault:", uniWethcVault);
        _logAddress("Aerodrome WETH/TTC Vault:", aeroWethcVault);
        _logComplete("Stage 18");
    }
}
