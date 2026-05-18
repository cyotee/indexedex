// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IVault as IBalancerVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    IWeightedPool8020Factory
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool8020Factory.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {IRICHIRDFPkg} from "contracts/vaults/protocol/RICHIRDFPkg.sol";
import {IProtocolNFTVaultDFPkg} from "contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {ISingleVaultDetfDFPkg} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

library SingleVaultDetf_Component_FactoryService {
    struct SingleVaultDetfFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeInQueryFacet;
        IFacet exchangeOutFacet;
        IFacet bondingFacet;
        IFacet operableFacet;
    }

    struct SingleVaultDetfInfra {
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IERC20 wethToken;
        IBalancerVault balancerV3Vault;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;
        ProtocolDETFSuperchainBridgeRepo.BridgeConfig bridgeConfig;
        IUniswapV4StandardExchangeDFPkg wethRichVaultPkg;
        IProtocolNFTVaultDFPkg protocolNFTVaultPkg;
        IRICHIRDFPkg richirPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    function buildPkgInit(SingleVaultDetfFacets memory facets_, SingleVaultDetfInfra memory infra_)
        internal
        pure
        returns (ISingleVaultDetfDFPkg.PkgInit memory pkgInit_)
    {
        pkgInit_ = ISingleVaultDetfDFPkg.PkgInit({
            erc20Facet: facets_.erc20Facet,
            erc5267Facet: facets_.erc5267Facet,
            erc2612Facet: facets_.erc2612Facet,
            multiAssetBasicVaultFacet: facets_.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: facets_.multiAssetStandardVaultFacet,
            singleVaultDetfExchangeInFacet: facets_.exchangeInFacet,
            singleVaultDetfExchangeInQueryFacet: facets_.exchangeInQueryFacet,
            singleVaultDetfExchangeOutFacet: facets_.exchangeOutFacet,
            singleVaultDetfBondingFacet: facets_.bondingFacet,
            operableFacet: facets_.operableFacet,
            feeOracle: infra_.feeOracle,
            vaultRegistryDeployment: infra_.vaultRegistryDeployment,
            permit2: infra_.permit2,
            wethToken: infra_.wethToken,
            balancerV3Vault: infra_.balancerV3Vault,
            balancerV3PrepayRouter: infra_.balancerV3PrepayRouter,
            weightedPool8020Factory: infra_.weightedPool8020Factory,
            bridgeConfig: infra_.bridgeConfig,
            wethRichVaultPkg: infra_.wethRichVaultPkg,
            protocolNFTVaultPkg: infra_.protocolNFTVaultPkg,
            richirPkg: infra_.richirPkg,
            rateProviderPkg: infra_.rateProviderPkg,
            diamondFactory: infra_.diamondFactory
        });
    }

    function buildPkgArgs(
        string memory name_,
        string memory symbol_,
        IERC20 richToken_,
        uint256 richInitialDepositAmount_,
        uint256 wethInitialDepositAmount_,
        PoolKey memory wethRichPoolKey_,
        uint24 wethRichWidthMultiplier_
    ) internal pure returns (ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs_) {
        pkgArgs_ = ISingleVaultDetfDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            richToken: richToken_,
            richInitialDepositAmount: richInitialDepositAmount_,
            wethInitialDepositAmount: wethInitialDepositAmount_,
            wethRichPoolKey: wethRichPoolKey_,
            wethRichWidthMultiplier: wethRichWidthMultiplier_
        });
    }
}