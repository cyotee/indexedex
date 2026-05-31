// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    IRebasingDETFTokenDFPkg
} from "contracts/vaults/detf/composed/stable/common/RebasingDETFTokenDFPkg.sol";

library DetfComponentFactoryService {
    struct RebasingDetfTokenFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiStepOwnableFacet;
        IFacet rebasingDetfTokenFacet;
    }

    function buildProtocolNFTVaultPkgInit(
        IFacet erc721Facet,
        IFacet erc4626BasicVaultFacet,
        IFacet erc4626StandardVaultFacet,
        IFacet protocolNFTVaultFacet,
        IVaultFeeOracleQuery feeOracle,
        IVaultRegistryDeployment vaultRegistryDeployment
    ) internal pure returns (IProtocolNFTVaultDFPkg.PkgInit memory pkgInit) {
        pkgInit = IProtocolNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            protocolNFTVaultFacet: protocolNFTVaultFacet,
            feeOracle: feeOracle,
            vaultRegistryDeployment: vaultRegistryDeployment
        });
    }

    function buildRebasingDetfTokenPkgInit(
        RebasingDetfTokenFacets memory facets,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IRebasingDETFTokenDFPkg.PkgInit memory pkgInit) {
        pkgInit = IRebasingDETFTokenDFPkg.PkgInit({
            erc20Facet: facets.erc20Facet,
            erc5267Facet: facets.erc5267Facet,
            erc2612Facet: facets.erc2612Facet,
            multiStepOwnableFacet: facets.multiStepOwnableFacet,
            rebasingDetfTokenFacet: facets.rebasingDetfTokenFacet,
            diamondFactory: diamondFactory
        });
    }

    function buildRICHIRPkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet richirFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IRICHIRDFPkg.PkgInit memory pkgInit) {
        pkgInit = IRICHIRDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            richirFacet: richirFacet,
            diamondFactory: diamondFactory
        });
    }
}