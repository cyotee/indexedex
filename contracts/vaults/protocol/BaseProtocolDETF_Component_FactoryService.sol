// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IBaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    IAerodromeStandardExchangeDFPkg
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

/**
 * @title BaseProtocolDETF_Component_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Helper structs and builder functions for Protocol DETF components.
 * @dev Split from deployment functions to avoid stack-too-deep.
 *      For deployment, use:
 *      - ProtocolDETF_Facet_FactoryService for facet deployment
 *      - ProtocolDETF_Pkg_FactoryService for package deployment
 */
library BaseProtocolDETF_Component_FactoryService {
    /* ---------------------------------------------------------------------- */
    /*                          Helper Structs                                */
    /* ---------------------------------------------------------------------- */

    /// @notice Facet inputs for buildProtocolDETFPkgInit
    struct ProtocolDETFFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet protocolDETFExchangeInFacet;
        IFacet protocolDETFExchangeInQueryFacet;
        IFacet protocolDETFExchangeOutFacet;
        IFacet protocolDETFBondingFacet;
        IFacet protocolDETFBridgeFacet;
        IFacet protocolDETFBondingQueryFacet;
        IFacet multiStepOwnableFacet;
        IFacet operableFacet;
        IFacet protocolDETFRichirRedeemFacet;
    }

    /// @notice Infrastructure inputs for buildProtocolDETFPkgInit
    struct ProtocolDETFInfra {
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IBalancerVault balancerV3Vault;
        IRouter balancerV3Router;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @notice Package inputs for buildProtocolDETFPkgInit
    struct ProtocolDETFPkgs {
        IAerodromeStandardExchangeDFPkg aerodromeStandardExchangeDFPkg;
        IProtocolNFTVaultDFPkg protocolNFTVaultPkg;
        IRICHIRDFPkg richirPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    /* ---------------------------------------------------------------------- */
    /*                          Builder Functions                             */
    /* ---------------------------------------------------------------------- */

    function buildProtocolDETFPkgInit(
        ProtocolDETFFacets memory facets,
        ProtocolDETFInfra memory infra,
        ProtocolDETFPkgs memory pkgs,
        ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig
    ) internal pure returns (IBaseProtocolDETFDFPkg.PkgInit memory pkgInit) {
        pkgInit = IBaseProtocolDETFDFPkg.PkgInit({
            erc20Facet: facets.erc20Facet,
            erc5267Facet: facets.erc5267Facet,
            erc2612Facet: facets.erc2612Facet,
            erc4626BasicVaultFacet: facets.erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: facets.erc4626StandardVaultFacet,
            protocolDETFExchangeInFacet: facets.protocolDETFExchangeInFacet,
            protocolDETFExchangeInQueryFacet: facets.protocolDETFExchangeInQueryFacet,
            protocolDETFExchangeOutFacet: facets.protocolDETFExchangeOutFacet,
            protocolDETFBondingFacet: facets.protocolDETFBondingFacet,
            protocolDETFBridgeFacet: facets.protocolDETFBridgeFacet,
            protocolDETFBondingQueryFacet: facets.protocolDETFBondingQueryFacet,
            multiStepOwnableFacet: facets.multiStepOwnableFacet,
            operableFacet: facets.operableFacet,
            protocolDETFRichirRedeemFacet: facets.protocolDETFRichirRedeemFacet,
            feeOracle: infra.feeOracle,
            vaultRegistryDeployment: infra.vaultRegistryDeployment,
            permit2: infra.permit2,
            balancerV3Vault: infra.balancerV3Vault,
            balancerV3Router: infra.balancerV3Router,
            balancerV3PrepayRouter: infra.balancerV3PrepayRouter,
            weightedPool8020Factory: infra.weightedPool8020Factory,
            diamondFactory: infra.diamondFactory,
            aerodromeStandardExchangeDFPkg: pkgs.aerodromeStandardExchangeDFPkg,
            protocolNFTVaultPkg: pkgs.protocolNFTVaultPkg,
            richirPkg: pkgs.richirPkg,
            rateProviderPkg: pkgs.rateProviderPkg,
            bridgeConfig: bridgeConfig
        });
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

    function buildProtocolDETFPkgArgs(string memory name, string memory symbol, IBaseProtocolDETFDFPkg.PkgArgs memory args)
        internal
        pure
        returns (IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs)
    {
        args.name = name;
        args.symbol = symbol;
        return args;
    }
}
