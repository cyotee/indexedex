// SPDX-License-Identifier: BSL-1.1
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
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IRebasingDETFTokenDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol";

library DetfComponentFactoryService {
    struct RebasingDetfTokenFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiStepOwnableFacet;
        IFacet rebasingDetfTokenFacet;
    }

    function buildDETFNFTVaultPkgInit(
        IFacet erc721Facet,
        IFacet erc4626BasicVaultFacet,
        IFacet erc4626StandardVaultFacet,
        IFacet detfNFTVaultFacet,
        IVaultFeeOracleQuery feeOracle,
        IVaultRegistryDeployment vaultRegistryDeployment
    ) internal pure returns (IDETFNFTVaultDFPkg.PkgInit memory pkgInit) {
        pkgInit = IDETFNFTVaultDFPkg.PkgInit({
            erc721Facet: erc721Facet,
            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            detfNFTVaultFacet: detfNFTVaultFacet,
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

    /// @notice Build rebasing claim token package init (role-safe name; L-NAME-1).
    function buildRebasingClaimTokenPkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet rebasingClaimTokenFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IRebasingClaimTokenDFPkg.PkgInit memory pkgInit) {
        pkgInit = IRebasingClaimTokenDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            rebasingClaimTokenFacet: rebasingClaimTokenFacet,
            diamondFactory: diamondFactory
        });
    }

    /// @dev Deprecated alias — use `buildRebasingClaimTokenPkgInit`.
    function buildRICHIRPkgInit(
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet rebasingClaimTokenFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal pure returns (IRebasingClaimTokenDFPkg.PkgInit memory pkgInit) {
        return buildRebasingClaimTokenPkgInit(
            erc20Facet, erc5267Facet, erc2612Facet, rebasingClaimTokenFacet, diamondFactory
        );
    }
}