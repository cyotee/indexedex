// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";

contract TestBase_VaultComponents is IndexedexTest {
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IFacet erc20Facet;
    IFacet erc5267Facet;
    IFacet erc2612Facet;
    IFacet erc4626Facet;
    IFacet erc4626BasicVaultFacet;
    IFacet erc4626StandardVaultFacet;
    IFacet multiAssetBasicVaultFacet;
    IFacet multiAssetStandardVaultFacet;
    function setUp() public virtual override(IndexedexTest) {
        IndexedexTest.setUp();
        erc20Facet = create3Factory.deployERC20Facet();
        erc2612Facet = create3Factory.deployERC2612Facet();
        erc5267Facet = create3Factory.deployERCC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
    }
}
