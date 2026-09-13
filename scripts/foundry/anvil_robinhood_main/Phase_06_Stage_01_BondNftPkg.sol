// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";

import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";

/// @title Phase_06_Stage_01_BondNftPkg
/// @notice Uni V4 Bond NFT DFPkg (R12a) + ERC721 + DETF NFT vault facets. Not the common Balancer NFT.
library Phase_06_Stage_01_BondNftPkg {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;

    function execute(LaunchState storage s) internal {
        IFacet detfNFTVaultFacet = s.create3Factory.deployUniswapV4DetfBondNFTVaultFacet();
        IFacet erc721FacetDetf = IFacet(
            s.create3Factory.deployFacet(ArtifactCreationCode.creationCode(s.create3Factory, "ERC721Facet.sol:ERC721Facet"), keccak256("RhMain_ERC721Facet"))
        );
        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService
            .buildUniswapV4DetfBondNFTVaultPkgInit(
            erc721FacetDetf,
            DetfFacetFactoryService.deployDETFFundedBondMetadataFacet(s.create3Factory),
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(s.indexedexManager)),
            IVaultRegistryDeployment(address(s.indexedexManager))
        );
        s.bondNftVaultPkg = address(
            IVaultRegistryDeployment(address(s.indexedexManager)).deployUniswapV4DetfBondNFTVaultDFPkg(nftPkgInit)
        );
    }
}
