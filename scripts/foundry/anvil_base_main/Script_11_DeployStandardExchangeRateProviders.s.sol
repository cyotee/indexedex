// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";

/* -------------------------------------------------------------------------- */
/*                                OpenZeppelin                                */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

/// @title Script_11_DeployStandardExchangeRateProviders
/// @notice Deploys StandardExchangeRateProvider instances for each Standard Exchange vault.
/// @dev Deploys 2 rate providers per vault (one per underlying pool token as the rate target).
contract Script_11_DeployStandardExchangeRateProviders is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeRateProviderDFPkg private rateProviderPkg;

    address private ttA;
    address private ttB;
    address private ttC;

    // UniV2 Standard Exchange vaults
    address private abVault;
    address private acVault;
    address private bcVault;

    // Aerodrome Standard Exchange vaults
    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    // UniV2 vault rate providers
    address private uniAbRpA;
    address private uniAbRpB;
    address private uniAcRpA;
    address private uniAcRpC;
    address private uniBcRpB;
    address private uniBcRpC;

    // Aerodrome vault rate providers
    address private aeroAbRpA;
    address private aeroAbRpB;
    address private aeroAcRpA;
    address private aeroAcRpC;
    address private aeroBcRpB;
    address private aeroBcRpC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 11: Deploy Standard Exchange Rate Providers");

        vm.startBroadcast();
        _deployRateProviders();
        vm.stopBroadcast();

        _exportJson();
        _exportSummary();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_dex_packages.json", "rateProviderPkg"));
        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found");

        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        ttC = _readAddress("05_test_tokens.json", "testTokenC");
        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens not found");

        abVault = _readAddress("07_strategy_vaults.json", "abVault");
        acVault = _readAddress("07_strategy_vaults.json", "acVault");
        bcVault = _readAddress("07_strategy_vaults.json", "bcVault");
        require(abVault != address(0) && acVault != address(0) && bcVault != address(0), "UniV2 vaults not found");

        aeroAbVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault");
        aeroAcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault");
        aeroBcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault");
        require(
            aeroAbVault != address(0) && aeroAcVault != address(0) && aeroBcVault != address(0),
            "Aerodrome vaults not found"
        );
    }

    function _deployForVault(address vault, address token0, address token1)
        internal
        returns (address rp0, address rp1)
    {
        rp0 = address(rateProviderPkg.deployRateProvider(IStandardExchange(vault), IERC20(token0)));
        rp1 = address(rateProviderPkg.deployRateProvider(IStandardExchange(vault), IERC20(token1)));
    }

    function _deployRateProviders() internal {
        (uniAbRpA, uniAbRpB) = _deployForVault(abVault, ttA, ttB);
        (uniAcRpA, uniAcRpC) = _deployForVault(acVault, ttA, ttC);
        (uniBcRpB, uniBcRpC) = _deployForVault(bcVault, ttB, ttC);

        (aeroAbRpA, aeroAbRpB) = _deployForVault(aeroAbVault, ttA, ttB);
        (aeroAcRpA, aeroAcRpC) = _deployForVault(aeroAcVault, ttA, ttC);
        (aeroBcRpB, aeroBcRpC) = _deployForVault(aeroBcVault, ttB, ttC);

        vm.label(uniAbRpA, "UniV2 AB RateProvider (A)");
        vm.label(uniAbRpB, "UniV2 AB RateProvider (B)");
        vm.label(uniAcRpA, "UniV2 AC RateProvider (A)");
        vm.label(uniAcRpC, "UniV2 AC RateProvider (C)");
        vm.label(uniBcRpB, "UniV2 BC RateProvider (B)");
        vm.label(uniBcRpC, "UniV2 BC RateProvider (C)");

        vm.label(aeroAbRpA, "Aerodrome AB RateProvider (A)");
        vm.label(aeroAbRpB, "Aerodrome AB RateProvider (B)");
        vm.label(aeroAcRpA, "Aerodrome AC RateProvider (A)");
        vm.label(aeroAcRpC, "Aerodrome AC RateProvider (C)");
        vm.label(aeroBcRpB, "Aerodrome BC RateProvider (B)");
        vm.label(aeroBcRpC, "Aerodrome BC RateProvider (C)");
    }

    function _exportJson() internal {
        string memory json;

        json = vm.serializeAddress("", "rateProviderPkg", address(rateProviderPkg));

        // UniV2 vault rate providers
        json = vm.serializeAddress("", "uniAbRpA", uniAbRpA);
        json = vm.serializeAddress("", "uniAbRpB", uniAbRpB);
        json = vm.serializeAddress("", "uniAcRpA", uniAcRpA);
        json = vm.serializeAddress("", "uniAcRpC", uniAcRpC);
        json = vm.serializeAddress("", "uniBcRpB", uniBcRpB);
        json = vm.serializeAddress("", "uniBcRpC", uniBcRpC);

        // Aerodrome vault rate providers
        json = vm.serializeAddress("", "aeroAbRpA", aeroAbRpA);
        json = vm.serializeAddress("", "aeroAbRpB", aeroAbRpB);
        json = vm.serializeAddress("", "aeroAcRpA", aeroAcRpA);
        json = vm.serializeAddress("", "aeroAcRpC", aeroAcRpC);
        json = vm.serializeAddress("", "aeroBcRpB", aeroBcRpB);
        json = vm.serializeAddress("", "aeroBcRpC", aeroBcRpC);

        _writeJson(json, "11_standard_exchange_rate_providers.json");
    }

    function _exportSummary() internal {
        string memory json;

        // Factories
        json = vm.serializeAddress("summary", "create3Factory", _readAddress("01_factories.json", "create3Factory"));
        json = vm.serializeAddress(
            "summary",
            "diamondPackageFactory",
            _readAddress("01_factories.json", "diamondPackageFactory")
        );

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
        json = vm.serializeAddress("summary", "rateProviderPkg", address(rateProviderPkg));

        // Tokens
        json = vm.serializeAddress("summary", "testTokenA", ttA);
        json = vm.serializeAddress("summary", "testTokenB", ttB);
        json = vm.serializeAddress("summary", "testTokenC", ttC);

        // UniV2 pools + vaults
        json = vm.serializeAddress("summary", "abPool", _readAddress("06_pools.json", "abPool"));
        json = vm.serializeAddress("summary", "acPool", _readAddress("06_pools.json", "acPool"));
        json = vm.serializeAddress("summary", "bcPool", _readAddress("06_pools.json", "bcPool"));

        json = vm.serializeAddress("summary", "abVault", abVault);
        json = vm.serializeAddress("summary", "acVault", acVault);
        json = vm.serializeAddress("summary", "bcVault", bcVault);

        // Aerodrome pools + vaults
        json = vm.serializeAddress("summary", "aeroAbPool", _readAddress("06_pools.json", "aeroAbPool"));
        json = vm.serializeAddress("summary", "aeroAcPool", _readAddress("06_pools.json", "aeroAcPool"));
        json = vm.serializeAddress("summary", "aeroBcPool", _readAddress("06_pools.json", "aeroBcPool"));

        json = vm.serializeAddress("summary", "aeroAbVault", aeroAbVault);
        json = vm.serializeAddress("summary", "aeroAcVault", aeroAcVault);
        json = vm.serializeAddress("summary", "aeroBcVault", aeroBcVault);

        // Balancer const-prod pools (optional, in case Stage 9 ran)
        (address tmp, bool ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerAbPool");
        if (ok) json = vm.serializeAddress("summary", "balancerAbPool", tmp);
        (tmp, ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerAcPool");
        if (ok) json = vm.serializeAddress("summary", "balancerAcPool", tmp);
        (tmp, ok) = _readAddressSafe("09_balancer_const_prod_pools.json", "balancerBcPool");
        if (ok) json = vm.serializeAddress("summary", "balancerBcPool", tmp);

        // Rate providers (12 total)
        json = vm.serializeAddress("summary", "uniAbRpA", uniAbRpA);
        json = vm.serializeAddress("summary", "uniAbRpB", uniAbRpB);
        json = vm.serializeAddress("summary", "uniAcRpA", uniAcRpA);
        json = vm.serializeAddress("summary", "uniAcRpC", uniAcRpC);
        json = vm.serializeAddress("summary", "uniBcRpB", uniBcRpB);
        json = vm.serializeAddress("summary", "uniBcRpC", uniBcRpC);

        json = vm.serializeAddress("summary", "aeroAbRpA", aeroAbRpA);
        json = vm.serializeAddress("summary", "aeroAbRpB", aeroAbRpB);
        json = vm.serializeAddress("summary", "aeroAcRpA", aeroAcRpA);
        json = vm.serializeAddress("summary", "aeroAcRpC", aeroAcRpC);
        json = vm.serializeAddress("summary", "aeroBcRpB", aeroBcRpB);
        json = vm.serializeAddress("summary", "aeroBcRpC", aeroBcRpC);

        // External protocols
        json = vm.serializeAddress("summary", "permit2", address(permit2));
        json = vm.serializeAddress("summary", "weth9", address(weth));
        json = vm.serializeAddress("summary", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("summary", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("summary", "balancerV3Vault", address(balancerV3Vault));

        _writeJson(json, "deployment_summary.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 AB RateProvider (A):", uniAbRpA);
        _logAddress("UniV2 AB RateProvider (B):", uniAbRpB);
        _logAddress("UniV2 AC RateProvider (A):", uniAcRpA);
        _logAddress("UniV2 AC RateProvider (C):", uniAcRpC);
        _logAddress("UniV2 BC RateProvider (B):", uniBcRpB);
        _logAddress("UniV2 BC RateProvider (C):", uniBcRpC);

        _logAddress("Aerodrome AB RateProvider (A):", aeroAbRpA);
        _logAddress("Aerodrome AB RateProvider (B):", aeroAbRpB);
        _logAddress("Aerodrome AC RateProvider (A):", aeroAcRpA);
        _logAddress("Aerodrome AC RateProvider (C):", aeroAcRpC);
        _logAddress("Aerodrome BC RateProvider (B):", aeroBcRpB);
        _logAddress("Aerodrome BC RateProvider (C):", aeroBcRpC);

        _logComplete("Stage 11");
    }
}
