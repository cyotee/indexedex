// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// Explicit artifacts for components CREATE3-loaded by this base, including focused runs.
import {ERC20Facet} from "@crane/contracts/tokens/ERC20/ERC20Facet.sol";
import {ERC2612Facet} from "@crane/contracts/tokens/ERC2612/ERC2612Facet.sol";
import {ERC5267Facet} from "@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol";
import {ERC4626Facet} from "@crane/contracts/tokens/ERC4626/ERC4626Facet.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";
import {MultiAssetBasicVaultFacet} from "contracts/vaults/basic/MultiAssetBasicVaultFacet.sol";
import {MultiAssetStandardVaultFacet} from "contracts/vaults/standard/MultiAssetStandardVaultFacet.sol";

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
        erc5267Facet = create3Factory.deployERC5267Facet();
        erc4626Facet = create3Factory.deployERC4626Facet();
        erc4626BasicVaultFacet = create3Factory.deployERC4626BasedBasicVaultFacet();
        erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
    }
}
