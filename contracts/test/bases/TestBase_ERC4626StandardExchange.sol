// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {
    IERC4626StandardExchangeDFPkg
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol";
import {
    ERC4626StandardExchange_Component_FactoryService
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol";

/**
 * @title TestBase_ERC4626StandardExchange
 * @notice Deploys generic ERC-4626 SE facets + DFPkg via IndexedEx registry path.
 */
contract TestBase_ERC4626StandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using ERC4626StandardExchange_Component_FactoryService for ICreate3FactoryProxy;
    using ERC4626StandardExchange_Component_FactoryService for IIndexedexManagerProxy;

    IFacet exchangeInFacet;
    IFacet exchangeOutFacet;
    IFacet markerFacet;
    IERC4626StandardExchangeDFPkg erc4626StandardExchangeDFPkg;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        exchangeInFacet = create3Factory.deployERC4626StandardExchangeInFacet();
        exchangeOutFacet = create3Factory.deployERC4626StandardExchangeOutFacet();
        markerFacet = create3Factory.deployERC4626StandardExchangeMarkerFacet();

        vm.prank(owner);
        erc4626StandardExchangeDFPkg =
            indexedexManager.deployERC4626StandardExchangeDFPkg(_buildPkgInit());
    }

    function _buildPkgInit()
        internal
        view
        returns (IERC4626StandardExchangeDFPkg.PkgInit memory)
    {
        return IERC4626StandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: exchangeInFacet,
            exchangeOutFacet: exchangeOutFacet,
            markerFacet: markerFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployERC4626SE(address protocolVault) internal returns (address vault) {
        vm.prank(owner);
        vault = erc4626StandardExchangeDFPkg.deployVault(IERC4626(protocolVault));
    }
}
