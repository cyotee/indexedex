// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {BalancerV3StandardExchangeRouter_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {IBalancerV3StandardExchangeRouterDFPkg} from
    "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {IBalancerV3StandardExchangeRouterProxy} from
    "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

import {StandardExchangeRateProvider_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProvider_FactoryService.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";

import {BalancerV3ConstantProductPool_FactoryService} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";

import {DefaultPoolInfoFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol";
import {StandardSwapFeePercentageBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol";
import {StandardUnbalancedLiquidityInvariantRatioBoundsFacet} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol";

contract Script_04_DeployDEXPackages_BalancerV3 is DeploymentBase {
    using BetterEfficientHashLib for bytes;
    using BalancerV3StandardExchangeRouter_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for IDiamondPackageCallBackFactory;
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IIndexedexManagerProxy private indexedexManager;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;

    IBalancerV3StandardExchangeRouterDFPkg private balRouterPkg;
    IBalancerV3StandardExchangeRouterProxy private balRouter;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balancerV3ConstProdPoolPkg;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 4: Deploy Balancer V3 Integration (use existing Sepolia)");

        vm.startBroadcast();

        _deployBalancerV3Router();
        _deployRateProviderPackage();
        _deployBalancerV3ConstProdPoolPackage();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        erc4626Facet = IFacet(_readAddress("02_shared_facets.json", "erc4626Facet"));
        erc4626BasicVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626StandardVaultFacet"));

        indexedexManager = IIndexedexManagerProxy(_readAddress("03_core_proxies.json", "indexedexManager"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(indexedexManager) != address(0), "IndexedexManager not found");
    }

    function _deployBalancerV3Router() internal {
        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        {
            pkgInit.senderGuardFacet = create3Factory.deployFacet(
                type(SenderGuardFacet).creationCode,
                abi.encode(type(SenderGuardFacet).name)._hash()
            );
            pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
            pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
            pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
            pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
            pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
            pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
            pkgInit.balancerV3StandardExchangeRouterPrepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
            pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
            pkgInit.balancerV3StandardExchangePermit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();
            pkgInit.balancerV3Vault = balancerV3Vault;
            pkgInit.permit2 = permit2;
            pkgInit.weth = weth;
        }

        balRouterPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        balRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(balRouterPkg);
    }

    function _deployRateProviderPackage() internal {
        IFacet rateProviderFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        rateProviderPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(
            rateProviderFacet,
            diamondPackageFactory
        );
    }

    function _deployBalancerV3ConstProdPoolPackage() internal {
        IFacet balancerV3VaultAwareFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3VaultAwareFacet(create3Factory);
        IFacet multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        IFacet betterBalancerV3PoolTokenFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3PoolTokenFacet(create3Factory);
        IFacet balancerV3AuthenticationFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3AuthenticationFacet(create3Factory);
        IFacet balancerV3ConstProdPoolFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);

        IFacet defaultPoolInfoFacet = create3Factory.deployFacet(
            type(DefaultPoolInfoFacet).creationCode,
            abi.encode(type(DefaultPoolInfoFacet).name)._hash()
        );

        IFacet standardSwapFeePercentageBoundsFacet = create3Factory.deployFacet(
            type(StandardSwapFeePercentageBoundsFacet).creationCode,
            abi.encode(type(StandardSwapFeePercentageBoundsFacet).name)._hash()
        );

        IFacet unbalancedLiquidityInvariantRatioBoundsFacet = create3Factory.deployFacet(
            type(StandardUnbalancedLiquidityInvariantRatioBoundsFacet).creationCode,
            abi.encode(type(StandardUnbalancedLiquidityInvariantRatioBoundsFacet).name)._hash()
        );

        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit =
        BalancerV3ConstantProductPool_FactoryService.buildBalancerV3ConstantProductPoolPkgInit(
            multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet,
            balancerV3VaultAwareFacet,
            betterBalancerV3PoolTokenFacet,
            defaultPoolInfoFacet,
            standardSwapFeePercentageBoundsFacet,
            unbalancedLiquidityInvariantRatioBoundsFacet,
            balancerV3AuthenticationFacet,
            balancerV3ConstProdPoolFacet,
            IVaultRegistryDeployment(address(indexedexManager)),
            indexedexManager,
            balancerV3Vault,
            diamondPackageFactory
        );

        balancerV3ConstProdPoolPkg = BalancerV3ConstantProductPool_FactoryService
            .deployBalancerV3ConstantProductPoolStandardVaultPkg(
                IVaultRegistryDeployment(address(indexedexManager)),
                pkgInit
            );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("balancer", "balancerV3RouterPkg", address(balRouterPkg));
        json = vm.serializeAddress("balancer", "balancerV3StandardExchangeRouter", address(balRouter));
        json = vm.serializeAddress("balancer", "balancerV3Vault", ETHEREUM_SEPOLIA.BALANCER_V3_VAULT);
        json = vm.serializeAddress("balancer", "balancerV3Router", ETHEREUM_SEPOLIA.BALANCER_V3_ROUTER);
        json = vm.serializeAddress("balancer", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress("balancer", "balancerV3ConstantProductPoolStandardVaultPkg", address(balancerV3ConstProdPoolPkg));
        json = vm.serializeAddress("balancer", "weth", address(weth));
        _writeJson(json, "04_balancer_v3.json");
    }

    function _logResults() internal view {
        _logAddress("BalancerV3RouterPkg:", address(balRouterPkg));
        _logAddress("BalancerV3StandardExchangeRouter:", address(balRouter));
        _logAddress("BalancerV3Vault (Sepolia):", ETHEREUM_SEPOLIA.BALANCER_V3_VAULT);
        _logAddress("RateProviderPkg:", address(rateProviderPkg));
        _logAddress("BalancerV3ConstProdPoolPkg:", address(balancerV3ConstProdPoolPkg));
        _logAddress("WETH (Balancer's):", address(weth));
        _logComplete("Stage 4");
    }
}
