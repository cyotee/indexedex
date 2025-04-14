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

import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

/// @title Script_22_DeployWethTtcVaultVaultPool
/// @notice Deploys a Balancer V3 pool containing both WETH/TTC Standard Exchange vaults.
/// @dev Both vaults quote WETH via StandardExchangeRateProvider.
///      Pool tokens: [Aerodrome WETH/TTC Vault, UniV2 WETH/TTC Vault]
contract Script_22_DeployWethTtcVaultVaultPool is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttA;
    address private ttB;

    address private uniAbVault;
    address private uniAcVault;
    address private uniBcVault;
    address private aeroAbVault;
    address private aeroAcVault;
    address private aeroBcVault;

    address private uniWethcVault;
    address private aeroWethcVault;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    // AB pair rate providers (quote ttA)
    address private aeroAbRpA;
    address private uniAbRpA;

    // AC pair rate providers (quote ttA)
    address private aeroAcRpA;
    address private uniAcRpA;

    // BC pair rate providers (quote ttB)
    address private aeroBcRpB;
    address private uniBcRpB;

    // Rate providers (each vault quotes WETH)
    address private aeroWethcRpWeth;
    address private uniWethcRpWeth;

    // Balancer vault-vault pools
    address private balancerAbVaultVaultPool;
    address private balancerAcVaultVaultPool;
    address private balancerBcVaultVaultPool;

    // Balancer vault-vault pool
    address private balancerWethcVaultVaultPool;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 22: Deploy WETH/TTC Vault-Vault Pool");

        vm.startBroadcast();
        _deployRateProviders();
        _deployPool();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_dex_packages.json", "rateProviderPkg"));
        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found");

        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_dex_packages.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");

        ttA = _readAddress("05_test_tokens.json", "testTokenA");
        ttB = _readAddress("05_test_tokens.json", "testTokenB");
        require(ttA != address(0) && ttB != address(0), "Test tokens not found");

        uniAbVault = _readAddress("07_strategy_vaults.json", "abVault");
        uniAcVault = _readAddress("07_strategy_vaults.json", "acVault");
        uniBcVault = _readAddress("07_strategy_vaults.json", "bcVault");

        aeroAbVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAbVault");
        aeroAcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroAcVault");
        aeroBcVault = _readAddress("08_aerodrome_strategy_vaults.json", "aeroBcVault");

        require(uniAbVault != address(0) && uniAcVault != address(0) && uniBcVault != address(0), "UniV2 vaults not found");
        require(
            aeroAbVault != address(0) && aeroAcVault != address(0) && aeroBcVault != address(0),
            "Aerodrome vaults not found"
        );

        uniWethcVault = _readAddress("18_weth_ttc_vaults.json", "uniWethcVault");
        aeroWethcVault = _readAddress("18_weth_ttc_vaults.json", "aeroWethcVault");
        require(uniWethcVault != address(0) && aeroWethcVault != address(0), "WETH/TTC vaults not found");
    }

    function _vaultTokenConfig(address vaultToken, address rp) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(vaultToken),
            tokenType: TokenType.WITH_RATE,
            rateProvider: IRateProvider(rp),
            paysYieldFees: false
        });
    }

    function _deployRateProviders() internal {
        // AB vault pair quoted in ttA
        aeroAbRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroAbVault), IERC20(ttA)));
        uniAbRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniAbVault), IERC20(ttA)));

        // AC vault pair quoted in ttA
        aeroAcRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroAcVault), IERC20(ttA)));
        uniAcRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniAcVault), IERC20(ttA)));

        // BC vault pair quoted in ttB
        aeroBcRpB = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroBcVault), IERC20(ttB)));
        uniBcRpB = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniBcVault), IERC20(ttB)));

        // Both vaults quote WETH
        aeroWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroWethcVault), IERC20(address(weth))));
        uniWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniWethcVault), IERC20(address(weth))));

        vm.label(aeroAbRpA, "Aerodrome AB RateProvider (ttA)");
        vm.label(uniAbRpA, "UniV2 AB RateProvider (ttA)");
        vm.label(aeroAcRpA, "Aerodrome AC RateProvider (ttA)");
        vm.label(uniAcRpA, "UniV2 AC RateProvider (ttA)");
        vm.label(aeroBcRpB, "Aerodrome BC RateProvider (ttB)");
        vm.label(uniBcRpB, "UniV2 BC RateProvider (ttB)");
        vm.label(aeroWethcRpWeth, "Aerodrome WETH/TTC RateProvider (WETH)");
        vm.label(uniWethcRpWeth, "UniV2 WETH/TTC RateProvider (WETH)");
    }

    function _deployVaultVaultPool(address leftVault, address leftRp, address rightVault, address rightRp)
        internal
        returns (address pool)
    {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _vaultTokenConfig(leftVault, leftRp);
        cfg[1] = _vaultTokenConfig(rightVault, rightRp);

        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployPool() internal {
        // AB vault-vault pool
        balancerAbVaultVaultPool = _deployVaultVaultPool(aeroAbVault, aeroAbRpA, uniAbVault, uniAbRpA);

        // AC vault-vault pool
        balancerAcVaultVaultPool = _deployVaultVaultPool(aeroAcVault, aeroAcRpA, uniAcVault, uniAcRpA);

        // BC vault-vault pool
        balancerBcVaultVaultPool = _deployVaultVaultPool(aeroBcVault, aeroBcRpB, uniBcVault, uniBcRpB);

        // WETH/TTC vault-vault pool
        balancerWethcVaultVaultPool =
            _deployVaultVaultPool(aeroWethcVault, aeroWethcRpWeth, uniWethcVault, uniWethcRpWeth);

        vm.label(balancerAbVaultVaultPool, "Balancer V3 AB Vault-Vault ConstProd");
        vm.label(balancerAcVaultVaultPool, "Balancer V3 AC Vault-Vault ConstProd");
        vm.label(balancerBcVaultVaultPool, "Balancer V3 BC Vault-Vault ConstProd");
        vm.label(balancerWethcVaultVaultPool, "Balancer V3 WETH/TTC Vault-Vault ConstProd");
    }

    function _exportJson() internal {
        string memory json;

        json = vm.serializeAddress("", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("", "balancerV3ConstantProductPoolStandardVaultPkg", address(balConstProdPkg));

        json = vm.serializeAddress("", "aeroAbVault", aeroAbVault);
        json = vm.serializeAddress("", "uniAbVault", uniAbVault);
        json = vm.serializeAddress("", "aeroAcVault", aeroAcVault);
        json = vm.serializeAddress("", "uniAcVault", uniAcVault);
        json = vm.serializeAddress("", "aeroBcVault", aeroBcVault);
        json = vm.serializeAddress("", "uniBcVault", uniBcVault);

        json = vm.serializeAddress("", "uniWethcVault", uniWethcVault);
        json = vm.serializeAddress("", "aeroWethcVault", aeroWethcVault);

        json = vm.serializeAddress("", "aeroAbRpA", aeroAbRpA);
        json = vm.serializeAddress("", "uniAbRpA", uniAbRpA);
        json = vm.serializeAddress("", "aeroAcRpA", aeroAcRpA);
        json = vm.serializeAddress("", "uniAcRpA", uniAcRpA);
        json = vm.serializeAddress("", "aeroBcRpB", aeroBcRpB);
        json = vm.serializeAddress("", "uniBcRpB", uniBcRpB);

        json = vm.serializeAddress("", "aeroWethcRpWeth", aeroWethcRpWeth);
        json = vm.serializeAddress("", "uniWethcRpWeth", uniWethcRpWeth);

        json = vm.serializeAddress("", "balancerAbVaultVaultPool", balancerAbVaultVaultPool);
        json = vm.serializeAddress("", "balancerAcVaultVaultPool", balancerAcVaultVaultPool);
        json = vm.serializeAddress("", "balancerBcVaultVaultPool", balancerBcVaultVaultPool);

        json = vm.serializeAddress("", "balancerWethcVaultVaultPool", balancerWethcVaultVaultPool);

        _writeJson(json, "22_weth_ttc_vault_vault_pool.json");
    }

    function _logResults() internal view {
        _logAddress("Balancer V3 AB Vault-Vault Pool:", balancerAbVaultVaultPool);
        _logAddress("Balancer V3 AC Vault-Vault Pool:", balancerAcVaultVaultPool);
        _logAddress("Balancer V3 BC Vault-Vault Pool:", balancerBcVaultVaultPool);
        _logAddress("Aerodrome WETH/TTC RateProvider (WETH):", aeroWethcRpWeth);
        _logAddress("UniV2 WETH/TTC RateProvider (WETH):", uniWethcRpWeth);
        _logAddress("Balancer V3 WETH/TTC Vault-Vault Pool:", balancerWethcVaultVaultPool);
        _logComplete("Stage 22");
    }
}
