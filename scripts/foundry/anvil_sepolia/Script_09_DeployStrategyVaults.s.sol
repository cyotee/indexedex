// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

contract Script_09_DeployStrategyVaults is DeploymentBase {
    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;
    IAerodromeStandardExchangeDFPkg private aerodromePkg;
    
    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;

    IPool private aeroAbPool;
    IPool private aeroAcPool;
    IPool private aeroBcPool;

    address private abVault;
    address private acVault;
    address private bcVault;

    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 9: Deploy Strategy Vaults");

        vm.startBroadcast();

        _deployStrategyVaults();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        // Load packages
        uniV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress("05_uniswap_v2.json", "uniswapV2Pkg"));
        require(address(uniV2Pkg) != address(0), "UniswapV2Pkg not found");
        
        aerodromePkg = IAerodromeStandardExchangeDFPkg(_readAddress("06_aerodrome.json", "aerodromePkg"));
        require(address(aerodromePkg) != address(0), "AerodromePkg not found");

        // Load UniV2 pools
        abPool = IUniswapV2Pair(_readAddress("08_pools.json", "abPool"));
        acPool = IUniswapV2Pair(_readAddress("08_pools.json", "acPool"));
        bcPool = IUniswapV2Pair(_readAddress("08_pools.json", "bcPool"));

        require(address(abPool) != address(0), "A-B Pool not found");
        require(address(acPool) != address(0), "A-C Pool not found");
        require(address(bcPool) != address(0), "B-C Pool not found");
        
        // Load Aerodrome pools
        aeroAbPool = IPool(_readAddress("08_pools.json", "aeroAbPool"));
        aeroAcPool = IPool(_readAddress("08_pools.json", "aeroAcPool"));
        aeroBcPool = IPool(_readAddress("08_pools.json", "aeroBcPool"));

        require(address(aeroAbPool) != address(0), "Aero AB Pool not found");
        require(address(aeroAcPool) != address(0), "Aero AC Pool not found");
        require(address(aeroBcPool) != address(0), "Aero BC Pool not found");
    }

    function _deployStrategyVaults() internal {
        // Deploy UniV2 vaults
        abVault = uniV2Pkg.deployVault(abPool);
        acVault = uniV2Pkg.deployVault(acPool);
        bcVault = uniV2Pkg.deployVault(bcPool);
        
        // Deploy Aerodrome vaults
        aeroAbVault = address(aerodromePkg.deployVault(aeroAbPool));
        aeroAcVault = address(aerodromePkg.deployVault(aeroAcPool));
        aeroBcVault = address(aerodromePkg.deployVault(aeroBcPool));
    }

    function _exportJson() internal {
        string memory json;
        // UniV2 vaults
        json = vm.serializeAddress("", "abVault", abVault);
        json = vm.serializeAddress("", "acVault", acVault);
        json = vm.serializeAddress("", "bcVault", bcVault);
        // Aerodrome vaults
        json = vm.serializeAddress("", "aeroAbVault", aeroAbVault);
        json = vm.serializeAddress("", "aeroAcVault", aeroAcVault);
        json = vm.serializeAddress("", "aeroBcVault", aeroBcVault);
        _writeJson(json, "09_strategy_vaults.json");
        _exportSummary();
    }

    function _exportSummary() internal {
        string memory json;
        json = vm.serializeAddress("summary", "create3Factory", _readAddress("01_factories.json", "create3Factory"));
        json = vm.serializeAddress("summary", "diamondPackageFactory", _readAddress("01_factories.json", "diamondPackageFactory"));
        json = vm.serializeAddress("summary", "feeCollector", _readAddress("03_core_proxies.json", "feeCollector"));
        json = vm.serializeAddress("summary", "indexedexManager", _readAddress("03_core_proxies.json", "indexedexManager"));
        json = vm.serializeAddress("summary", "uniswapV2Pkg", _readAddress("05_uniswap_v2.json", "uniswapV2Pkg"));
        json = vm.serializeAddress("summary", "aerodromePkg", _readAddress("06_aerodrome.json", "aerodromePkg"));
        json = vm.serializeAddress("summary", "balancerV3StandardExchangeRouter", _readAddress("04_balancer_v3.json", "balancerV3StandardExchangeRouter"));
        json = vm.serializeAddress("summary", "testTokenA", _readAddress("07_test_tokens.json", "testTokenA"));
        json = vm.serializeAddress("summary", "testTokenB", _readAddress("07_test_tokens.json", "testTokenB"));
        json = vm.serializeAddress("summary", "testTokenC", _readAddress("07_test_tokens.json", "testTokenC"));
        json = vm.serializeAddress("summary", "abPool", address(abPool));
        json = vm.serializeAddress("summary", "acPool", address(acPool));
        json = vm.serializeAddress("summary", "bcPool", address(bcPool));
        json = vm.serializeAddress("summary", "abVault", abVault);
        json = vm.serializeAddress("summary", "acVault", acVault);
        json = vm.serializeAddress("summary", "bcVault", bcVault);
        json = vm.serializeAddress("summary", "permit2", address(permit2));
        json = vm.serializeAddress("summary", "weth9", address(weth));
        json = vm.serializeAddress("summary", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("summary", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("summary", "balancerV3Vault", address(balancerV3Vault));
        _writeJson(json, "deployment_summary.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 A-B Vault:", abVault);
        _logAddress("UniV2 A-C Vault:", acVault);
        _logAddress("UniV2 B-C Vault:", bcVault);
        _logAddress("Aerodrome A-B Vault:", aeroAbVault);
        _logAddress("Aerodrome A-C Vault:", aeroAcVault);
        _logAddress("Aerodrome B-C Vault:", aeroBcVault);
        _logComplete("Stage 9");
    }
}
