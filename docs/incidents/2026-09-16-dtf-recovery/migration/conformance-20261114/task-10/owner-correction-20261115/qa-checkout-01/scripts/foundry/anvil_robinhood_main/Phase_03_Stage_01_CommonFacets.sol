// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {AccessFacetFactoryService} from "@crane/contracts/access/AccessFacetFactoryService.sol";
import {IntrospectionFacetFactoryService} from "@crane/contracts/introspection/IntrospectionFacetFactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

/// @title Phase_03_Stage_01_CommonFacets
/// @notice One Stage: ERC20, ERC2612, ERC5267, ERC4626, vault facets, MultiStepOwnable, Operable, DiamondCut.
library Phase_03_Stage_01_CommonFacets {
    using AccessFacetFactoryService for ICreate3FactoryProxy;
    using IntrospectionFacetFactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
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
}
