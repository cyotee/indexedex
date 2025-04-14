// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {UniswapV2_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

import {Aerodrome_Component_FactoryService} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

import {CamelotV2_Component_FactoryService} from "contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol";
import {ICamelotV2StandardExchangeDFPkg} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";

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

/// @title Script_04_DeployDEXPackages
/// @notice Deploys all DEX integration packages (UniswapV2, Aerodrome, Camelot, BalancerV3)
/// @dev Run: forge script scripts/foundry/anvil_base_main/Script_04_DeployDEXPackages.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract Script_04_DeployDEXPackages is DeploymentBase {
    using BetterEfficientHashLib for bytes;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;
    using CamelotV2_Component_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for ICreate3FactoryProxy;
    using BalancerV3StandardExchangeRouter_FactoryService for IDiamondPackageCallBackFactory;
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    // From previous deployments
    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IIndexedexManagerProxy private indexedexManager;

    // Shared facets
    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;

    // Deployed packages
    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;
    IAerodromeStandardExchangeDFPkg private aerodromePkg;
    ICamelotV2StandardExchangeDFPkg private camelotPkg;
    IBalancerV3StandardExchangeRouterDFPkg private balRouterPkg;
    IBalancerV3StandardExchangeRouterProxy private balRouter;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balancerV3ConstProdPoolPkg;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 4: Deploy DEX Packages");

        vm.startBroadcast();

        _deployUniswapV2Package();
        _deployAerodromePackage();
        _deployCamelotPackage();
        _deployBalancerV3Router();
        _deployRateProviderPackage();
        _deployBalancerV3ConstProdPoolPackage();

        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadPreviousDeployments() internal {
        // Load factories
        create3Factory = ICreate3FactoryProxy(_readAddress("01_factories.json", "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress("01_factories.json", "diamondPackageFactory"));

        // Load shared facets
        erc20Facet = IFacet(_readAddress("02_shared_facets.json", "erc20Facet"));
        erc2612Facet = IFacet(_readAddress("02_shared_facets.json", "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress("02_shared_facets.json", "erc5267Facet"));
        erc4626Facet = IFacet(_readAddress("02_shared_facets.json", "erc4626Facet"));
        erc4626BasicVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress("02_shared_facets.json", "erc4626StandardVaultFacet"));

        // Load core proxies
        indexedexManager = IIndexedexManagerProxy(_readAddress("03_core_proxies.json", "indexedexManager"));

        require(address(create3Factory) != address(0), "Create3Factory not found");
        require(address(indexedexManager) != address(0), "IndexedexManager not found");
    }

    function _deployUniswapV2Package() internal {
        IUniswapV2StandardExchangeDFPkg.PkgInit memory init = UniswapV2_Component_FactoryService
            .buildArgsUniswapV2StandardExchangePkgInit(
                erc20Facet,
                erc2612Facet,
                erc5267Facet,
                erc4626Facet,
                erc4626BasicVaultFacet,
                erc4626StandardVaultFacet,
                create3Factory.deployUniswapV2StandardExchangeInFacet(),
                create3Factory.deployUniswapV2StandardExchangeOutFacet(),
                indexedexManager,
                indexedexManager,
                permit2,
                uniswapV2Factory,
                uniswapV2Router
            );

        uniV2Pkg = UniswapV2_Component_FactoryService.deployUniswapV2StandardExchangeDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            init
        );
    }

    function _deployAerodromePackage() internal {
        aerodromePkg = Aerodrome_Component_FactoryService.deployAerodromeStandardExchangeDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            erc20Facet,
            erc2612Facet,
            erc5267Facet,
            erc4626Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            create3Factory.deployAerodromeStandardExchangeInFacet(),
            create3Factory.deployAerodromeStandardExchangeOutFacet(),
            indexedexManager,
            indexedexManager,
            permit2,
            aerodromeRouter,
            aerodromePoolFactory
        );
    }

    function _deployCamelotPackage() internal {
        if (address(camelotRouter) == address(0) || address(camelotFactory) == address(0)) {
            return; // Skip if Camelot not configured
        }
        if (address(camelotRouter).code.length == 0 || address(camelotFactory).code.length == 0) {
            return; // Skip if contracts don't exist
        }

        ICamelotV2StandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = erc20Facet;
        init.erc2612Facet = erc2612Facet;
        init.erc5267Facet = erc5267Facet;
        init.erc4626Facet = erc4626Facet;
        init.erc4626BasicVaultFacet = erc4626BasicVaultFacet;
        init.erc4626StandardVaultFacet = erc4626StandardVaultFacet;
        init.camelotV2StandardExchangeInFacet = create3Factory.deployCamelotV2StandardExchangeInFacet();
        init.camelotV2StandardExchangeOutFacet = create3Factory.deployCamelotV2StandardExchangeOutFacet();
        init.vaultFeeOracleQuery = indexedexManager;
        init.vaultRegistryDeployment = indexedexManager;
        init.permit2 = permit2;
        init.camelotV2Factory = camelotFactory;
        init.camelotV2Router = camelotRouter;

        camelotPkg = CamelotV2_Component_FactoryService.deployCamelotV2StandardExchangeDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            init
        );
    }

    function _deployBalancerV3Router() internal {
        // IFacet senderGuardFacet = create3Factory.deployFacet(
        //     type(SenderGuardFacet).creationCode,
        //     abi.encode(type(SenderGuardFacet).name)._hash()
        // );

        // IFacet exactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        // IFacet exactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        // IFacet exactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        // IFacet exactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        // IFacet batchExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        // IFacet batchExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        // IFacet prepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        // IFacet prepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        // IFacet permit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();

        // balRouterPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
        //     senderGuardFacet,
        //     exactInQueryFacet,
        //     exactOutQueryFacet,
        //     exactInSwapFacet,
        //     exactOutSwapFacet,
        //     prepayFacet,
        //     prepayHooksFacet,
        //     batchExactInFacet,
        //     batchExactOutFacet,
        //     permit2WitnessFacet,
        //     balancerV3Vault,
        //     permit2,
        //     weth
        // );

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

        balRouterPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(
            pkgInit
        );
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
        IFacet multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        IFacet multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        // Deploy required facets
        IFacet balancerV3VaultAwareFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3VaultAwareFacet(
            create3Factory
        );
        IFacet betterBalancerV3PoolTokenFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3PoolTokenFacet(
            create3Factory
        );
        IFacet balancerV3AuthenticationFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3AuthenticationFacet(
            create3Factory
        );
        IFacet balancerV3ConstProdPoolFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(
            create3Factory
        );

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
        json = vm.serializeAddress("packages", "uniswapV2Pkg", address(uniV2Pkg));
        json = vm.serializeAddress("packages", "aerodromePkg", address(aerodromePkg));
        json = vm.serializeAddress("packages", "camelotPkg", address(camelotPkg));
        json = vm.serializeAddress("packages", "balancerV3RouterPkg", address(balRouterPkg));
        json = vm.serializeAddress("packages", "balancerV3StandardExchangeRouter", address(balRouter));
        json = vm.serializeAddress("packages", "balancerV3Router", address(balancerV3Router));
        json = vm.serializeAddress("packages", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress(
            "packages",
            "balancerV3ConstantProductPoolStandardVaultPkg",
            address(balancerV3ConstProdPoolPkg)
        );
        _writeJson(json, "04_dex_packages.json");
    }

    function _logResults() internal view {
        _logAddress("UniswapV2Pkg:", address(uniV2Pkg));
        _logAddress("AerodromePkg:", address(aerodromePkg));
        _logAddress("CamelotPkg:", address(camelotPkg));
        _logAddress("BalancerV3RouterPkg:", address(balRouterPkg));
        _logAddress("BalancerV3StandardExchangeRouter:", address(balRouter));
        _logAddress("BalancerV3Router:", address(balancerV3Router));
        _logAddress("RateProviderPkg:", address(rateProviderPkg));
        _logAddress("BalancerV3ConstProdPoolPkg:", address(balancerV3ConstProdPoolPkg));
        _logComplete("Stage 4");
    }
}
