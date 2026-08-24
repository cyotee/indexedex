// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";

/// @title Phase_06_Stage_01_BondNftPkg
/// @notice Bond NFT DFPkg + ERC721 + DETF NFT vault facets used only here.
library Phase_06_Stage_01_BondNftPkg {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        IFacet detfNFTVaultFacet = s.create3Factory.deployDETFNFTVaultFacet();
        IFacet erc721FacetDetf = IFacet(
            s.create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("RhMain_ERC721Facet"))
        );
        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721FacetDetf,
            s.erc4626BasicVaultFacet,
            s.erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(s.indexedexManager)),
            IVaultRegistryDeployment(address(s.indexedexManager))
        );
        s.bondNftVaultPkg =
            address(IVaultRegistryDeployment(address(s.indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit));
    }
}
