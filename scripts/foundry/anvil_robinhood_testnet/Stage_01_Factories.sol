// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";

/// @title Stage_01_Factories
/// @notice CREATE3 + diamond package factory + Uni V4 hook factory + shared facets.
library Stage_01_Factories {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s, address owner_) internal {
        (s.create3Factory, s.diamondPackageFactory) = InitDevService.initEnv(owner_);
        _deploySharedFacets(s);
        _deployHookFactory(s);
    }

    function _deploySharedFacets(LaunchState storage s) private {
        s.erc20Facet = s.create3Factory.deployERC20Facet();
        s.erc2612Facet = s.create3Factory.deployERC2612Facet();
        s.erc5267Facet = s.create3Factory.deployERC5267Facet();
        s.erc4626Facet = s.create3Factory.deployERC4626Facet();
        s.erc4626BasicVaultFacet = s.create3Factory.deployERC4626BasedBasicVaultFacet();
        s.erc4626StandardVaultFacet = s.create3Factory.deployERC4626StandardVaultFacet();
        s.multiAssetBasicVaultFacet = s.create3Factory.deployMultiAssetBasicVaultFacet();
        s.multiAssetStandardVaultFacet = s.create3Factory.deployMultiAssetStandardVaultFacet();
        s.multiStepOwnableFacet = s.create3Factory.deployMultiStepOwnableFacet();
        s.operableFacet = s.create3Factory.deployOperableFacet();
        s.diamondCutFacet = s.create3Factory.deployDiamondCutFacet();
    }

    function _deployHookFactory(LaunchState storage s) private {
        s.hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(s.create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(s.create3Factory));
        s.hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            s.create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: s.hookFlagsFacet
            })
        );
    }
}
