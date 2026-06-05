// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IRouter as IAerodromeRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";
import {IPoolFactory as IAerodromePoolFactory} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPoolFactory.sol";

import {Pool as AerodromePool} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Pool.sol";
import {PoolFactory as AerodromePoolFactory} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/PoolFactory.sol";
import {FactoryRegistry as AerodromeFactoryRegistry} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/factories/FactoryRegistry.sol";
import {Router as AerodromeRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/stubs/Router.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {Aerodrome_Component_FactoryService} from "contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol";
import {IAerodromeStandardExchangeDFPkg} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";

contract Script_06_DeployAerodrome is DeploymentBase {
    using Aerodrome_Component_FactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IIndexedexManagerProxy private indexedexManager;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;

    IAerodromePoolFactory private aerodromeFactory;
    IAerodromeStandardExchangeDFPkg private aerodromePkg;
    AerodromeFactoryRegistry private aerodromeFactoryRegistry;
    AerodromePool private aerodromePoolImplementation;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 6: Deploy OUR OWN Aerodrome (deployed fresh for Sepolia)");

        vm.startBroadcast();

        _deployAerodromeFactory();
        _deployAerodromeRouter();
        _deployAerodromePackage();

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

    function _deployAerodromeFactory() internal {
        // Deploy Pool implementation first (the contract that pools clone from)
        aerodromePoolImplementation = new AerodromePool();
        
        // Deploy PoolFactory with the pool implementation address
        aerodromeFactory = IAerodromePoolFactory(address(new AerodromePoolFactory(address(aerodromePoolImplementation))));
    }

    function _deployAerodromeRouter() internal {
        // Deploy FactoryRegistry - approves the pool factory on construction
        // Parameters: fallbackPoolFactory, fallbackVotingRewardsFactory, fallbackGaugeFactory, managedRewardsFactory
        // Note: managedRewardsFactory cannot be address(0) or it will revert in constructor
        aerodromeFactoryRegistry = new AerodromeFactoryRegistry(
            address(aerodromeFactory),  // fallbackPoolFactory
            address(aerodromeFactory),  // fallbackVotingRewardsFactory (can be same as pool factory)
            address(aerodromeFactory),  // fallbackGaugeFactory (can be same as pool factory)
            address(deployer)          // managedRewardsFactory (must be non-zero)
        );

        // Deploy Router - needs factoryRegistry, factory, voter, weth
        aerodromeRouter = IAerodromeRouter(address(new AerodromeRouter(
            address(0),                           // _forwarder
            address(aerodromeFactoryRegistry),    // _factoryRegistry
            address(aerodromeFactory),            // _factory (defaultFactory)
            address(0),                           // _voter (not needed for testing)
            address(weth)                         // _weth
        )));
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
            IAerodromePoolFactory(address(aerodromeFactory))
        );

        _setOurAerodrome(address(aerodromeRouter), address(aerodromeFactory));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("aerodrome", "aerodromePoolImplementation", address(aerodromePoolImplementation));
        json = vm.serializeAddress("aerodrome", "aerodromeFactory", address(aerodromeFactory));
        json = vm.serializeAddress("aerodrome", "aerodromeFactoryRegistry", address(aerodromeFactoryRegistry));
        json = vm.serializeAddress("aerodrome", "aerodromeRouter", address(aerodromeRouter));
        json = vm.serializeAddress("aerodrome", "aerodromePkg", address(aerodromePkg));
        json = vm.serializeAddress("aerodrome", "weth", address(weth));
        _writeJson(json, "06_aerodrome.json");
    }

    function _logResults() internal view {
        _logAddress("AerodromePoolImplementation:", address(aerodromePoolImplementation));
        _logAddress("AerodromeFactory (OUR DEPLOYMENT):", address(aerodromeFactory));
        _logAddress("AerodromeFactoryRegistry:", address(aerodromeFactoryRegistry));
        _logAddress("AerodromeRouter (OUR DEPLOYMENT):", address(aerodromeRouter));
        _logAddress("AerodromePkg:", address(aerodromePkg));
        _logAddress("Using WETH (Balancer's):", address(weth));
        _logComplete("Stage 6");
    }
}
