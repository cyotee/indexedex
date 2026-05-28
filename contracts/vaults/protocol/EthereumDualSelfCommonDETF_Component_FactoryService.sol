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
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IEthereumDualSelfCommonDETFDFPkg} from "contracts/vaults/protocol/EthereumDualSelfCommonDETFDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {
    IUniswapV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {DualSelfCommonDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/DualSelfCommonDETFSuperchainBridgeRepo.sol";

/**
 * @title EthereumDualSelfCommonDETF_Component_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Helper structs and builder functions for Ethereum Protocol DETF components.
 */
library EthereumDualSelfCommonDETF_Component_FactoryService {
    struct EthereumDualSelfCommonDETFFacets {
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
    }

    struct EthereumDualSelfCommonDETFInfra {
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IBalancerVault balancerV3Vault;
        IRouter balancerV3Router;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct EthereumDualSelfCommonDETFPkgs {
        IUniswapV2StandardExchangeDFPkg uniswapV2StandardExchangeDFPkg;
        IDetfSelfNftInventoryDFPkg protocolNFTVaultPkg;
        IRICHIRDFPkg richirPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    function buildEthereumDualSelfCommonDETFPkgInit(
        EthereumDualSelfCommonDETFFacets memory facets,
        EthereumDualSelfCommonDETFInfra memory infra,
        EthereumDualSelfCommonDETFPkgs memory pkgs,
        DualSelfCommonDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig
    ) internal pure returns (IEthereumDualSelfCommonDETFDFPkg.PkgInit memory pkgInit) {
        pkgInit = IEthereumDualSelfCommonDETFDFPkg.PkgInit({
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
            feeOracle: infra.feeOracle,
            vaultRegistryDeployment: infra.vaultRegistryDeployment,
            permit2: infra.permit2,
            balancerV3Vault: infra.balancerV3Vault,
            balancerV3Router: infra.balancerV3Router,
            balancerV3PrepayRouter: infra.balancerV3PrepayRouter,
            weightedPool8020Factory: infra.weightedPool8020Factory,
            diamondFactory: infra.diamondFactory,
            uniswapV2StandardExchangeDFPkg: pkgs.uniswapV2StandardExchangeDFPkg,
            protocolNFTVaultPkg: pkgs.protocolNFTVaultPkg,
            richirPkg: pkgs.richirPkg,
            rateProviderPkg: pkgs.rateProviderPkg,
            bridgeConfig: bridgeConfig
        });
    }
}