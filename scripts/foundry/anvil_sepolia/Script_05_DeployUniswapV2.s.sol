// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Router.sol";
import {UniV2Factory} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Factory.sol";
import {UniV2Router02} from "@crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Router02.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

import {UniswapV2_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";

contract Script_05_DeployUniswapV2 is DeploymentBase {
    using UniswapV2_Component_FactoryService for ICreate3FactoryProxy;

    ICreate3FactoryProxy private create3Factory;
    IDiamondPackageCallBackFactory private diamondPackageFactory;
    IIndexedexManagerProxy private indexedexManager;

    IFacet private erc20Facet;
    IFacet private erc2612Facet;
    IFacet private erc5267Facet;
    IFacet private erc4626Facet;
    IFacet private erc4626BasicVaultFacet;
    IFacet private erc4626StandardVaultFacet;

    IUniswapV2StandardExchangeDFPkg private uniV2Pkg;

    function run() external {
        _setup();
        _loadPreviousDeployments();

        _logHeader("Stage 5: Deploy OUR OWN Uniswap V2 (using Balancer V3 WETH)");

        vm.startBroadcast();

        _deployUniswapV2Factory();
        _deployUniswapV2Router();
        _deployUniswapV2Package();

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

    function _deployUniswapV2Factory() internal {
        uniswapV2Factory = new UniV2Factory(owner);
    }

    function _deployUniswapV2Router() internal {
        uniswapV2Router = new UniV2Router02(address(uniswapV2Factory), address(weth));
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

        _setOurUniswapV2(address(uniswapV2Router), address(uniswapV2Factory));
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("uniswapV2", "uniswapV2Factory", address(uniswapV2Factory));
        json = vm.serializeAddress("uniswapV2", "uniswapV2Router", address(uniswapV2Router));
        json = vm.serializeAddress("uniswapV2", "uniswapV2Pkg", address(uniV2Pkg));
        json = vm.serializeAddress("uniswapV2", "weth", address(weth));
        _writeJson(json, "05_uniswap_v2.json");
    }

    function _logResults() internal view {
        _logAddress("UniswapV2Factory (OUR DEPLOYMENT):", address(uniswapV2Factory));
        _logAddress("UniswapV2Router (OUR DEPLOYMENT):", address(uniswapV2Router));
        _logAddress("UniswapV2Pkg:", address(uniV2Pkg));
        _logAddress("Using WETH (Balancer's):", address(weth));
        _logComplete("Stage 5");
    }
}
