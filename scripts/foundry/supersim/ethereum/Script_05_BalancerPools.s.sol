// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "../../anvil_sepolia/DeploymentBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

contract Script_05_BalancerPools is DeploymentBase {
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balConstProdPkg;

    address private ttA;
    address private ttB;
    address private ttC;

    address private abVault;
    address private acVault;
    address private bcVault;
    address private uniWethcVault;

    address private uniAbRpA;
    address private uniAbRpB;
    address private uniAcRpA;
    address private uniAcRpC;
    address private uniBcRpB;
    address private uniBcRpC;
    address private uniWethcRpWeth;
    address private uniWethcRpC;

    address private balancerAbPool;
    address private balancerAcPool;
    address private balancerBcPool;
    address private balancerWethcPool;
    address private balUniAbWithA;
    address private balUniAbWithB;
    address private balUniAcWithA;
    address private balUniAcWithC;
    address private balUniBcWithB;
    address private balUniBcWithC;
    address private balUniWethcWithWeth;
    address private balUniWethcWithC;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Ethereum Stage 5: Balancer Pools");

        vm.startBroadcast();
        _deployRateProviders();
        _deployTokenOnlyPools();
        _deployVaultTokenPools();
        vm.stopBroadcast();

        _exportRateProvidersJson();
        _exportBalancerPoolsJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(_readAddress("04_balancer_v3.json", "rateProviderPkg"));
        balConstProdPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(
            _readAddress("04_balancer_v3.json", "balancerV3ConstantProductPoolStandardVaultPkg")
        );

        ttA = _readAddress("07_test_tokens.json", "testTokenA");
        ttB = _readAddress("07_test_tokens.json", "testTokenB");
        ttC = _readAddress("07_test_tokens.json", "testTokenC");

        abVault = _readAddress("09_strategy_vaults.json", "abVault");
        acVault = _readAddress("09_strategy_vaults.json", "acVault");
        bcVault = _readAddress("09_strategy_vaults.json", "bcVault");
        uniWethcVault = _readAddress("09_strategy_vaults.json", "uniWethcVault");

        require(address(rateProviderPkg) != address(0), "Rate provider pkg not found");
        require(address(balConstProdPkg) != address(0), "Balancer const-prod pkg not found");
        require(ttA != address(0) && ttB != address(0) && ttC != address(0), "Test tokens not found");
        require(
            abVault != address(0) && acVault != address(0) && bcVault != address(0) && uniWethcVault != address(0),
            "UniV2 vaults not found"
        );
    }

    function _deployRateProviders() internal {
        uniAbRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(abVault), IERC20(ttA)));
        uniAbRpB = address(rateProviderPkg.deployRateProvider(IStandardExchange(abVault), IERC20(ttB)));
        uniAcRpA = address(rateProviderPkg.deployRateProvider(IStandardExchange(acVault), IERC20(ttA)));
        uniAcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(acVault), IERC20(ttC)));
        uniBcRpB = address(rateProviderPkg.deployRateProvider(IStandardExchange(bcVault), IERC20(ttB)));
        uniBcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(bcVault), IERC20(ttC)));
        uniWethcRpWeth = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniWethcVault), IERC20(address(weth))));
        uniWethcRpC = address(rateProviderPkg.deployRateProvider(IStandardExchange(uniWethcVault), IERC20(ttC)));
    }

    function _standardTokenConfig(address token) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(token),
            tokenType: TokenType.STANDARD,
            rateProvider: IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    function _vaultTokenConfig(address vaultToken, address rateProvider) internal pure returns (TokenConfig memory cfg) {
        cfg = TokenConfig({
            token: IERC20(vaultToken),
            tokenType: TokenType.WITH_RATE,
            rateProvider: IRateProvider(rateProvider),
            paysYieldFees: false
        });
    }

    function _deployTokenOnlyPool(address token0, address token1) internal returns (address pool) {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(token0);
        cfg[1] = _standardTokenConfig(token1);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployVaultTokenPool(address underlyingToken, address vaultToken, address vaultTokenRateProvider)
        internal
        returns (address pool)
    {
        TokenConfig[] memory cfg = new TokenConfig[](2);
        cfg[0] = _standardTokenConfig(underlyingToken);
        cfg[1] = _vaultTokenConfig(vaultToken, vaultTokenRateProvider);
        pool = balConstProdPkg.deployVault(cfg, address(0));
    }

    function _deployTokenOnlyPools() internal {
        balancerAbPool = _deployTokenOnlyPool(ttA, ttB);
        balancerAcPool = _deployTokenOnlyPool(ttA, ttC);
        balancerBcPool = _deployTokenOnlyPool(ttB, ttC);
        balancerWethcPool = _deployTokenOnlyPool(address(weth), ttC);
    }

    function _deployVaultTokenPools() internal {
        balUniAbWithA = _deployVaultTokenPool(ttA, abVault, uniAbRpB);
        balUniAbWithB = _deployVaultTokenPool(ttB, abVault, uniAbRpA);
        balUniAcWithA = _deployVaultTokenPool(ttA, acVault, uniAcRpC);
        balUniAcWithC = _deployVaultTokenPool(ttC, acVault, uniAcRpA);
        balUniBcWithB = _deployVaultTokenPool(ttB, bcVault, uniBcRpC);
        balUniBcWithC = _deployVaultTokenPool(ttC, bcVault, uniBcRpB);
        balUniWethcWithWeth = _deployVaultTokenPool(address(weth), uniWethcVault, uniWethcRpC);
        balUniWethcWithC = _deployVaultTokenPool(ttC, uniWethcVault, uniWethcRpWeth);
    }

    function _exportRateProvidersJson() internal {
        string memory json;
        json = vm.serializeAddress("", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("", "uniAbRpA", uniAbRpA);
        json = vm.serializeAddress("", "uniAbRpB", uniAbRpB);
        json = vm.serializeAddress("", "uniAcRpA", uniAcRpA);
        json = vm.serializeAddress("", "uniAcRpC", uniAcRpC);
        json = vm.serializeAddress("", "uniBcRpB", uniBcRpB);
        json = vm.serializeAddress("", "uniBcRpC", uniBcRpC);
        json = vm.serializeAddress("", "uniWethcRpWeth", uniWethcRpWeth);
        json = vm.serializeAddress("", "uniWethcRpC", uniWethcRpC);
        _writeJson(json, "11_standard_exchange_rate_providers.json");
    }

    function _exportBalancerPoolsJson() internal {
        string memory json;
        json = vm.serializeAddress("", "balancerV3ConstantProductPoolStandardVaultPkg", address(balConstProdPkg));
        json = vm.serializeAddress("", "balancerAbPool", balancerAbPool);
        json = vm.serializeAddress("", "balancerAcPool", balancerAcPool);
        json = vm.serializeAddress("", "balancerBcPool", balancerBcPool);
        json = vm.serializeAddress("", "balancerWethcPool", balancerWethcPool);
        json = vm.serializeAddress("", "balUniAbWithA", balUniAbWithA);
        json = vm.serializeAddress("", "balUniAbWithB", balUniAbWithB);
        json = vm.serializeAddress("", "balUniAcWithA", balUniAcWithA);
        json = vm.serializeAddress("", "balUniAcWithC", balUniAcWithC);
        json = vm.serializeAddress("", "balUniBcWithB", balUniBcWithB);
        json = vm.serializeAddress("", "balUniBcWithC", balUniBcWithC);
        json = vm.serializeAddress("", "balUniWethcWithWeth", balUniWethcWithWeth);
        json = vm.serializeAddress("", "balUniWethcWithC", balUniWethcWithC);
        _writeJson(json, "12_balancer_const_prod_vault_token_pools.json");
    }

    function _logResults() internal view {
        _logAddress("UniV2 AB RateProvider (A):", uniAbRpA);
        _logAddress("UniV2 AC RateProvider (A):", uniAcRpA);
        _logAddress("UniV2 BC RateProvider (B):", uniBcRpB);
        _logAddress("UniV2 WETH/TTC RateProvider (WETH):", uniWethcRpWeth);
        _logAddress("Balancer AB ConstProd Pool:", balancerAbPool);
        _logAddress("Balancer AC ConstProd Pool:", balancerAcPool);
        _logAddress("Balancer BC ConstProd Pool:", balancerBcPool);
        _logAddress("Balancer WETH/TTC ConstProd Pool:", balancerWethcPool);
        _logComplete("Ethereum Stage 5");
    }
}