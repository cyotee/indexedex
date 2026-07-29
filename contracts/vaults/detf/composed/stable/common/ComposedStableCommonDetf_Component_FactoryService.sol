// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IDiamondPackageCallBackFactory} from '@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IStablePool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';

import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IProtocolDETF} from 'contracts/interfaces/IProtocolDETF.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {
    IComposedStableCommonDetfBondNFTVaultDFPkg
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol';
import {
    ComposedStableCommonDetfDFPkg,
    IComposedStableCommonDetfDFPkg
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfDFPkg.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {IRebasingDETFTokenDFPkg} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenDFPkg.sol';
import {ThresholdMode} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';

library ComposedStableCommonDetf_Component_FactoryService {
    struct ComposedStableCommonDetfFacets {
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet bondingFacet;
        IFacet exchangeInFacet;
        IFacet exchangeOutQueryFacet;
        IFacet pricingFacet;
    }

    struct ComposedStableCommonDetfInfra {
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct ComposedStableCommonDetfPricingConfig {
        IWeightedPool reservePool;
        IDETFNFTVault bondNftVault;
        IRebasingClaimToken rebasingDetfToken;
        IERC20 detfToken;
        IERC20 stablePoolBpt;
        IERC20 commonPoolBpt;
        IERC20 rateAsset;
        IStandardExchangeIn stablePoolExitPricer;
        IStandardExchangeIn commonPoolExitPricer;
        IPermit2 permit2;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IStablePool stablePool;
        IStablePool commonPool;
        IStandardExchangeIn reservePoolEntryRouter;
        uint256 detfIndex;
        uint256 stablePoolBptIndex;
        uint256 commonPoolBptIndex;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ComposedStableCommonDetfRepo.RouteConfig[] routes;
        ThresholdMode thresholdMode;
    }

    struct RebasingDetfTokenFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiStepOwnableFacet;
        IFacet rebasingDetfTokenFacet;
    }

    struct BondNFTVaultFacets {
        IFacet erc721Facet;
        IFacet erc4626BasicVaultFacet;
        IFacet erc4626StandardVaultFacet;
        IFacet bondNFTVaultFacet;
        IFacet multiStepOwnableFacet;
    }

    struct BondNFTVaultConfig {
        string name;
        string symbol;
        IProtocolDETF protocolDETF;
        IERC20 lpToken;
        IERC20 rewardToken;
        uint8 decimalOffset;
        address owner;
    }

    function buildPkgInit(ComposedStableCommonDetfFacets memory facets_, ComposedStableCommonDetfInfra memory infra_)
        internal
        pure
        returns (IComposedStableCommonDetfDFPkg.PkgInit memory pkgInit_)
    {
        pkgInit_ = IComposedStableCommonDetfDFPkg.PkgInit({
            multiAssetBasicVaultFacet: facets_.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: facets_.multiAssetStandardVaultFacet,
            composedStableCommonDetfBondingFacet: facets_.bondingFacet,
            composedStableCommonDetfExchangeInFacet: facets_.exchangeInFacet,
            composedStableCommonDetfExchangeOutQueryFacet: facets_.exchangeOutQueryFacet,
            rebasingDetfTokenPricingFacet: facets_.pricingFacet,
            vaultRegistryDeployment: infra_.vaultRegistryDeployment
        });
    }

    function buildPkgArgs(ComposedStableCommonDetfPricingConfig memory config_)
        internal
        pure
        returns (IComposedStableCommonDetfDFPkg.PkgArgs memory pkgArgs_)
    {
        pkgArgs_ = IComposedStableCommonDetfDFPkg.PkgArgs({
            reservePool: config_.reservePool,
            bondNftVault: config_.bondNftVault,
            rebasingDetfToken: config_.rebasingDetfToken,
            detfToken: config_.detfToken,
            stablePoolBpt: config_.stablePoolBpt,
            commonPoolBpt: config_.commonPoolBpt,
            rateAsset: config_.rateAsset,
            stablePoolExitPricer: config_.stablePoolExitPricer,
            commonPoolExitPricer: config_.commonPoolExitPricer,
            permit2: config_.permit2,
            balancerV3Router: config_.balancerV3Router,
            stablePool: config_.stablePool,
            commonPool: config_.commonPool,
            reservePoolEntryRouter: config_.reservePoolEntryRouter,
            detfIndex: config_.detfIndex,
            stablePoolBptIndex: config_.stablePoolBptIndex,
            commonPoolBptIndex: config_.commonPoolBptIndex,
            mintThreshold: config_.mintThreshold,
            burnThreshold: config_.burnThreshold,
            routes: config_.routes,
            thresholdMode: config_.thresholdMode
        });
    }

    function buildRebasingDetfTokenPkgInit(
        RebasingDetfTokenFacets memory facets_,
        IDiamondPackageCallBackFactory diamondFactory_
    ) internal pure returns (IRebasingDETFTokenDFPkg.PkgInit memory pkgInit_) {
        pkgInit_ = IRebasingDETFTokenDFPkg.PkgInit({
            erc20Facet: facets_.erc20Facet,
            erc5267Facet: facets_.erc5267Facet,
            erc2612Facet: facets_.erc2612Facet,
            multiStepOwnableFacet: facets_.multiStepOwnableFacet,
            rebasingDetfTokenFacet: facets_.rebasingDetfTokenFacet,
            diamondFactory: diamondFactory_
        });
    }

    function buildBondNFTVaultPkgInit(BondNFTVaultFacets memory facets_, ComposedStableCommonDetfInfra memory infra_)
        internal
        pure
        returns (IComposedStableCommonDetfBondNFTVaultDFPkg.PkgInit memory pkgInit_)
    {
        pkgInit_ = IComposedStableCommonDetfBondNFTVaultDFPkg.PkgInit({
            erc721Facet: facets_.erc721Facet,
            erc4626BasicVaultFacet: facets_.erc4626BasicVaultFacet,
            erc4626StandardVaultFacet: facets_.erc4626StandardVaultFacet,
            bondNFTVaultFacet: facets_.bondNFTVaultFacet,
            multiStepOwnableFacet: facets_.multiStepOwnableFacet,
            feeOracle: IVaultFeeOracleQuery(address(infra_.vaultRegistryDeployment)),
            vaultRegistryDeployment: infra_.vaultRegistryDeployment
        });
    }

    function buildBondNFTVaultPkgArgs(BondNFTVaultConfig memory config_)
        internal
        pure
        returns (IComposedStableCommonDetfBondNFTVaultDFPkg.PkgArgs memory pkgArgs_)
    {
        pkgArgs_ = IComposedStableCommonDetfBondNFTVaultDFPkg.PkgArgs({
            name: config_.name,
            symbol: config_.symbol,
            protocolDETF: config_.protocolDETF,
            lpToken: config_.lpToken,
            rewardToken: config_.rewardToken,
            decimalOffset: config_.decimalOffset,
            owner: config_.owner
        });
    }
}