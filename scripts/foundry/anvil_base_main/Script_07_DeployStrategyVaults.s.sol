// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

/// @title Script_07_DeployStrategyVaults
/// @notice Deploys strategy vaults for each UniV2 pool
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_07_DeployStrategyVaults.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_07_DeployStrategyVaults is DeploymentBase {
    // From previous deployments
    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;
    IUniswapV2Pair private abPool;
    IUniswapV2Pair private acPool;
    IUniswapV2Pair private bcPool;

    // Deployed vaults
    address private abVault;
    address private acVault;
    address private bcVault;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 7: Deploy Strategy Vaults");

        vm.startBroadcast();

        _deployStrategyVaults();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        // Load package
        uniV2Pkg = IUniswapV2StandardExchangeDFPkg(_readAddress("04_dex_packages.json", "uniswapV2Pkg"));
        require(address(uniV2Pkg) != address(0), "UniswapV2Pkg not found");

        // Load pools
        abPool = IUniswapV2Pair(_readAddress("06_pools.json", "abPool"));
        acPool = IUniswapV2Pair(_readAddress("06_pools.json", "acPool"));
        bcPool = IUniswapV2Pair(_readAddress("06_pools.json", "bcPool"));

        require(address(abPool) != address(0), "A-B Pool not found");
        require(address(acPool) != address(0), "A-C Pool not found");
        require(address(bcPool) != address(0), "B-C Pool not found");
    }

    function _deployStrategyVaults() internal {
        abVault = uniV2Pkg.deployVault(abPool);
        acVault = uniV2Pkg.deployVault(acPool);
        bcVault = uniV2Pkg.deployVault(bcPool);
    }

    function _exportJson() internal {
        string memory json;
        // IMPORTANT: DeploymentBase._readAddress expects top-level keys (".<key>")
        // so keep this file flat (no nested objects).
        json = vm.serializeAddress("", "abVault", abVault);
        json = vm.serializeAddress("", "acVault", acVault);
        json = vm.serializeAddress("", "bcVault", bcVault);
        _writeJson(json, "07_strategy_vaults.json");

        // Also export a combined summary file
        _exportSummary();
    }

    function _exportSummary() internal {
        string memory json;

        // Factories
        json = vm.serializeAddress("summary", "create3Factory", _readAddress("01_factories.json", "create3Factory"));
        json = vm.serializeAddress("summary", "diamondPackageFactory", _readAddress("01_factories.json", "diamondPackageFactory"));

        // Core
        json = vm.serializeAddress("summary", "feeCollector", _readAddress("03_core_proxies.json", "feeCollector"));
        json = vm.serializeAddress("summary", "indexedexManager", _readAddress("03_core_proxies.json", "indexedexManager"));

        // Packages
        json = vm.serializeAddress("summary", "uniswapV2Pkg", _readAddress("04_dex_packages.json", "uniswapV2Pkg"));
        json = vm.serializeAddress("summary", "aerodromePkg", _readAddress("04_dex_packages.json", "aerodromePkg"));
        json = vm.serializeAddress(
            "summary",
            "balancerV3StandardExchangeRouter",
            _readAddress("04_dex_packages.json", "balancerV3StandardExchangeRouter")
        );
        json = vm.serializeAddress("summary", "balancerV3Router", _readAddress("04_dex_packages.json", "balancerV3Router"));

        // Tokens
        json = vm.serializeAddress("summary", "testTokenA", _readAddress("05_test_tokens.json", "testTokenA"));
        json = vm.serializeAddress("summary", "testTokenB", _readAddress("05_test_tokens.json", "testTokenB"));
        json = vm.serializeAddress("summary", "testTokenC", _readAddress("05_test_tokens.json", "testTokenC"));

        // Pools
        json = vm.serializeAddress("summary", "abPool", address(abPool));
        json = vm.serializeAddress("summary", "acPool", address(acPool));
        json = vm.serializeAddress("summary", "bcPool", address(bcPool));

        // Vaults
        json = vm.serializeAddress("summary", "abVault", abVault);
        json = vm.serializeAddress("summary", "acVault", acVault);
        json = vm.serializeAddress("summary", "bcVault", bcVault);

        // External protocols
        json = vm.serializeAddress("summary", "permit2", address(permit2));
        json = vm.serializeAddress("summary", "weth9", address(weth));
        json = vm.serializeAddress("summary", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("summary", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("summary", "balancerV3Vault", address(balancerV3Vault));

        _writeJson(json, "deployment_summary.json");
    }

    function _logResults() internal view {
        _logAddress("A-B Vault:", abVault);
        _logAddress("A-C Vault:", acVault);
        _logAddress("B-C Vault:", bcVault);
        _logComplete("Stage 7 - Deployment Complete!");
    }
}
