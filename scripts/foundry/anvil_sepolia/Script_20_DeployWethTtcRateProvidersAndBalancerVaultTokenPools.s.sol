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

/// @title Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools
/// @notice Deploys StandardExchange rate providers and Balancer V3 vault-token pools for WETH/TTC vaults.
/// @dev Deploys 2 rate providers per vault: one targeting WETH, one targeting TTC.
///      Then deploys 2 Balancer pools per vault:
///      - (WETH, vaultToken) where vaultToken is WITH_RATE quoted in TTC
///      - (TTC, vaultToken) where vaultToken is WITH_RATE quoted in WETH
contract Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools is DeploymentBase {
    /* ---------------------------------------------------------------------- */
    /*                                  Inputs                                */
    /* ---------------------------------------------------------------------- */

    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttC;

    address private uniWethcVault;
    address private aeroWethcVault;

    /* ---------------------------------------------------------------------- */
    /*                                 Outputs                                */
    /* ---------------------------------------------------------------------- */

    // Rate providers (per vault, per rate-target)
    address private uniWethcRpWeth;
    address private uniWethcRpC;
    address private aeroWethcRpWeth;
    address private aeroWethcRpC;

    // Balancer pools
    address private balUniWethcWithWeth;
    address private balUniWethcWithC;

    address private balAeroWethcWithWeth;
    address private balAeroWethcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 20: Deploy WETH/TTC Rate Providers + Balancer Vault-Token Pools");

        vm.startBroadcast();
        _deployRateProviders();
        _deployPools();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_balancer_v3.json", "rateProviderPkg"));
        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found");

        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_balancer_v3.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");

        ttC = _readAddress("07_test_tokens.json", "testTokenC");
        require(ttC != address(0), "Test Token C not found");

        uniWethcVault = _readAddress("18_weth_ttc_vaults.json", "uniWethcVault");
        aeroWethcVault = _readAddress("18_weth_ttc_vaults.json", "aeroWethcVault");
        require(uniWethcVault != address(0) && aeroWethcVault != address(0), "WETH/TTC vaults not found");
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
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
        // UniV2
        uniWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniWethcVault), IERC20(address(weth))));
        uniWethcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniWethcVault), IERC20(ttC)));

        // Aerodrome
        aeroWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroWethcVault), IERC20(address(weth))));
        aeroWethcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(aeroWethcVault), IERC20(ttC)));

        vm.label(uniWethcRpWeth, "UniV2 WETH/TTC RateProvider (WETH)");
        vm.label(uniWethcRpC, "UniV2 WETH/TTC RateProvider (TTC)");
        vm.label(aeroWethcRpWeth, "Aerodrome WETH/TTC RateProvider (WETH)");
        vm.label(aeroWethcRpC, "Aerodrome WETH/TTC RateProvider (TTC)");
    }

    function _deployPool(address underlying, address vaultToken, address vaultTokenRateProvider) internal returns (address pool) {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(underlying);
        cfg[1] = _vaultTokenConfig(vaultToken, vaultTokenRateProvider);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployPools() internal {
        // UniV2 WETH/TTC vault-token pools
        // - (WETH, vault) where vault is WITH_RATE quoted in TTC
        balUniWethcWithWeth = _deployPool(address(weth), uniWethcVault, uniWethcRpC);
        // - (TTC, vault) where vault is WITH_RATE quoted in WETH
        balUniWethcWithC = _deployPool(ttC, uniWethcVault, uniWethcRpWeth);

        // Aerodrome WETH/TTC vault-token pools
        balAeroWethcWithWeth = _deployPool(address(weth), aeroWethcVault, aeroWethcRpC);
        balAeroWethcWithC = _deployPool(ttC, aeroWethcVault, aeroWethcRpWeth);

        vm.label(balUniWethcWithWeth, "Balancer UniV2 WETH/TTC vault + WETH");
        vm.label(balUniWethcWithC, "Balancer UniV2 WETH/TTC vault + TTC");
        vm.label(balAeroWethcWithWeth, "Balancer Aerodrome WETH/TTC vault + WETH");
        vm.label(balAeroWethcWithC, "Balancer Aerodrome WETH/TTC vault + TTC");
    }

    function _exportJson() internal {
        string memory json;

        json = vm.serializeAddress("", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("", "balancerV3ConstantProductPoolStandardVaultPkg", address(balConstProdPkg));

        json = vm.serializeAddress("", "uniWethcVault", uniWethcVault);
        json = vm.serializeAddress("", "aeroWethcVault", aeroWethcVault);

        json = vm.serializeAddress("", "uniWethcRpWeth", uniWethcRpWeth);
        json = vm.serializeAddress("", "uniWethcRpC", uniWethcRpC);
        json = vm.serializeAddress("", "aeroWethcRpWeth", aeroWethcRpWeth);
        json = vm.serializeAddress("", "aeroWethcRpC", aeroWethcRpC);

        json = vm.serializeAddress("", "balUniWethcWithWeth", balUniWethcWithWeth);
        json = vm.serializeAddress("", "balUniWethcWithC", balUniWethcWithC);
        json = vm.serializeAddress("", "balAeroWethcWithWeth", balAeroWethcWithWeth);
        json = vm.serializeAddress("", "balAeroWethcWithC", balAeroWethcWithC);

        _writeJson(json, "20_weth_ttc_balancer_vault_token_pools.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 WETH/TTC RateProvider (WETH):", uniWethcRpWeth);
        _logAddress("UniV2 WETH/TTC RateProvider (TTC):", uniWethcRpC);
        _logAddress("Aerodrome WETH/TTC RateProvider (WETH):", aeroWethcRpWeth);
        _logAddress("Aerodrome WETH/TTC RateProvider (TTC):", aeroWethcRpC);

        _logAddress("Balancer UniV2 vault-token pool (WETH):", balUniWethcWithWeth);
        _logAddress("Balancer UniV2 vault-token pool (TTC):", balUniWethcWithC);
        _logAddress("Balancer Aerodrome vault-token pool (WETH):", balAeroWethcWithWeth);
        _logAddress("Balancer Aerodrome vault-token pool (TTC):", balAeroWethcWithC);

        _logComplete("Stage 20");
    }
}
