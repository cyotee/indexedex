// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {LocalTestingDeploymentBase} from "../shared/LocalTestingDeploymentBase.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {UniswapV2_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {BalancerV3ConstantProductPool_FactoryService} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {DefaultPoolInfoFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/DefaultPoolInfoFacet.sol";
import {StandardSwapFeePercentageBoundsFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardSwapFeePercentageBoundsFacet.sol";
import {StandardUnbalancedLiquidityInvariantRatioBoundsFacet} from "contracts/protocols/dexes/balancer/v3/pools/constProd/facets/StandardUnbalancedLiquidityInvariantRatioBoundsFacet.sol";

/// @title Script_05_DeployFoundationPackages
/// @notice Deploys the first local-testing package layer needed for scenario bring-up
contract Script_05_DeployFoundationPackages is LocalTestingDeploymentBase {
    using BetterEfficientHashLib for bytes;
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;
    using BalancerV3ConstantProductPool_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    string internal constant CRANE_FOUNDATION_FILE = "01_crane_foundation.json";
    string internal constant INDEXEDEX_CORE_FILE = "02_indexedex_core.json";
    string internal constant PROTOCOLS_BASE_FILE = "03_protocols_base.json";
    string internal constant ARTIFACT_FILE = "05_foundation_packages.json";

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IIndexedexManagerProxy private indexedexManager;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;
    IFacet private multiAssetBasicVaultFacet;
    IFacet private multiAssetStandardVaultFacet;

    IPermit2 private permit2;
    IUniswapV2Factory private uniswapV2Factory;
    IUniswapV2Router private uniswapV2Router;
    IVault private balancerV3Vault;

    IUniswapV2StandardExchangeDFPkg private uniswapV2StandardExchangePkg;
    IStandardExchangeRateProviderDFPkg private rateProviderPkg;
    IBalancerV3ConstantProductPoolStandardVaultPkg private balancerV3ConstantProductPoolStandardVaultPkg;

    function run() external {
        _loadConfig();
        _loadDependencies();

        _logHeader("Stage 05: Deploy Foundation Packages");

        if (_loadExistingPackages()) {
            _exportJson();
            _logResults();
            return;
        }

        vm.startBroadcast();
        _deployUniswapV2StandardExchangePkg();
        _deployRateProviderPkg();
        _deployBalancerV3ConstantProductPoolPkg();
        vm.stopBroadcast();

        _exportJson();
        _logResults();
    }

    function _loadDependencies() internal {
        create3Factory = ICreate3FactoryProxy(_readAddress(CRANE_FOUNDATION_FILE, "create3Factory"));
        diamondPackageFactory = IDiamondPackageCallBackFactory(_readAddress(CRANE_FOUNDATION_FILE, "diamondPackageFactory"));
        indexedexManager = IIndexedexManagerProxy(_readAddress(INDEXEDEX_CORE_FILE, "indexedexManager"));

        require(address(create3Factory) != address(0), "Create3Factory not found - run Script_01 first");
        require(address(indexedexManager) != address(0), "IndexedexManager not found - run Script_02 first");

        erc20Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc20Facet"));
        erc2612Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc2612Facet"));
        erc5267Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc5267Facet"));
        erc4626Facet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626Facet"));
        erc4626BasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626BasicVaultFacet"));
        erc4626StandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "erc4626StandardVaultFacet"));
        multiAssetBasicVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetBasicVaultFacet"));
        multiAssetStandardVaultFacet = IFacet(_readAddress(CRANE_FOUNDATION_FILE, "multiAssetStandardVaultFacet"));

        permit2 = IPermit2(_readAddress(PROTOCOLS_BASE_FILE, "permit2"));
        uniswapV2Factory = IUniswapV2Factory(_readAddress(PROTOCOLS_BASE_FILE, "uniswapV2Factory"));
        uniswapV2Router = IUniswapV2Router(_readAddress(PROTOCOLS_BASE_FILE, "uniswapV2Router"));
        balancerV3Vault = IVault(_readAddress(PROTOCOLS_BASE_FILE, "balancerV3Vault"));
    }

    function _loadExistingPackages() internal returns (bool) {
        (address uniPkg, bool hasUniPkg) = _readAddressSafe(ARTIFACT_FILE, "uniswapV2StandardExchangePkg");
        (address ratePkg, bool hasRatePkg) = _readAddressSafe(ARTIFACT_FILE, "rateProviderPkg");
        (address balPkg, bool hasBalPkg) = _readAddressSafe(ARTIFACT_FILE, "balancerV3ConstantProductPoolStandardVaultPkg");

        if (!hasUniPkg || !hasRatePkg || !hasBalPkg) {
            return false;
        }

        if (uniPkg.code.length == 0 || ratePkg.code.length == 0 || balPkg.code.length == 0) {
            return false;
        }

        uniswapV2StandardExchangePkg = IUniswapV2StandardExchangeDFPkg(uniPkg);
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(ratePkg);
        balancerV3ConstantProductPoolStandardVaultPkg = IBalancerV3ConstantProductPoolStandardVaultPkg(balPkg);
        return true;
    }

    function _deployUniswapV2StandardExchangePkg() internal {
        IUniswapV2StandardExchangeDFPkg.PkgInit memory pkgInit = UniswapV2_Component_FactoryService
            .buildArgsUniswapV2StandardExchangePkgInit(
                erc20Facet,
                erc2612Facet,
                erc5267Facet,
                erc4626Facet,
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                create3Factory.deployUniswapV2StandardExchangeInFacet(),
                create3Factory.deployUniswapV2StandardExchangeOutFacet(),
                indexedexManager,
                indexedexManager,
                permit2,
                uniswapV2Factory,
                uniswapV2Router
            );

        uniswapV2StandardExchangePkg = UniswapV2_Component_FactoryService.deployUniswapV2StandardExchangeDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
    }

    function _deployRateProviderPkg() internal {
        IFacet rateProviderFacet = create3Factory.deployStandardExchangeRateProviderFacet();
        rateProviderPkg = create3Factory.deployStandardExchangeRateProviderDFPkg(rateProviderFacet, diamondPackageFactory);
    }

    function _deployBalancerV3ConstantProductPoolPkg() internal {
        // IFacet multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        // IFacet multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        IFacet balancerV3VaultAwareFacet = create3Factory.deployBalancerV3VaultAwareFacet();
        IFacet balancerV3PoolTokenFacet = create3Factory.deployBalancerV3PoolTokenFacet();
        IFacet balancerV3AuthenticationFacet = create3Factory.deployBalancerV3AuthenticationFacet();
        IFacet balancerV3ConstantProductPoolFacet = create3Factory.deployBalancerV3ConstantProductPoolFacet();

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

        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory pkgInit = BalancerV3ConstantProductPool_FactoryService
            .buildBalancerV3ConstantProductPoolPkgInit(
                multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet,
                balancerV3VaultAwareFacet,
                balancerV3PoolTokenFacet,
                defaultPoolInfoFacet,
                standardSwapFeePercentageBoundsFacet,
                unbalancedLiquidityInvariantRatioBoundsFacet,
                balancerV3AuthenticationFacet,
                balancerV3ConstantProductPoolFacet,
                IVaultRegistryDeployment(address(indexedexManager)),
                indexedexManager,
                balancerV3Vault,
                diamondPackageFactory
            );

        balancerV3ConstantProductPoolStandardVaultPkg = BalancerV3ConstantProductPool_FactoryService
            .deployBalancerV3ConstantProductPoolStandardVaultPkg(
                IVaultRegistryDeployment(address(indexedexManager)),
                pkgInit
            );
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("foundationPackages", "uniswapV2StandardExchangePkg", address(uniswapV2StandardExchangePkg));
        json = vm.serializeAddress("foundationPackages", "rateProviderPkg", address(rateProviderPkg));
        json = vm.serializeAddress(
            "foundationPackages",
            "balancerV3ConstantProductPoolStandardVaultPkg",
            address(balancerV3ConstantProductPoolStandardVaultPkg)
        );
        json = vm.serializeAddress("foundationPackages", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("foundationPackages", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("foundationPackages", "balancerV3Vault", address(balancerV3Vault));
        json = vm.serializeAddress("foundationPackages", "permit2", address(permit2));
        json = vm.serializeAddress("foundationPackages", "owner", owner);
        json = vm.serializeAddress("foundationPackages", "deployer", deployer);
        json = vm.serializeUint("foundationPackages", "chainId", block.chainid);
        json = vm.serializeString("foundationPackages", "networkProfile", _networkProfile());
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logString("Artifact:", ARTIFACT_FILE);
        _logAddress("UniswapV2 Standard Exchange Pkg:", address(uniswapV2StandardExchangePkg));
        _logAddress("Standard Exchange Rate Provider Pkg:", address(rateProviderPkg));
        _logAddress(
            "Balancer ConstProd Pool Pkg:",
            address(balancerV3ConstantProductPoolStandardVaultPkg)
        );
        _logAddress("UniswapV2 Factory:", address(uniswapV2Factory));
        _logAddress("UniswapV2 Router:", address(uniswapV2Router));
        _logAddress("Balancer V3 Vault:", address(balancerV3Vault));
        _logAddress("Permit2:", address(permit2));
        _logUint("ChainId:", block.chainid);
        _logComplete("Stage 05");
    }
}