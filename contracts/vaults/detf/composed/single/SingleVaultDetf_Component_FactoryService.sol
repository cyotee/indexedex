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
import {ISuperChainBridgeTokenRegistry} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/ISuperChainBridgeTokenRegistry.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IBalancerV3StandardExchangeRouterPrepay} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IUniswapV4StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/claimToken/RebasingClaimTokenDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {ISingleVaultDetfDFPkg} from "contracts/vaults/detf/composed/single/SingleVaultDetfDFPkg.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

library SingleVaultDetf_Component_FactoryService {
    struct SingleVaultDetfFacets {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeInQueryFacet;
        IFacet infoFacet;
        IFacet exchangeOutFacet;
        IFacet bondingFacet;
        IFacet operableFacet;
    }

    struct SingleVaultDetfInfra {
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPermit2 permit2;
        IERC20 rateAsset;
        IBalancerVault balancerV3Vault;
        IBalancerV3StandardExchangeRouterPrepay balancerV3PrepayRouter;
        IWeightedPool8020Factory weightedPool8020Factory;
        ISuperChainBridgeTokenRegistry bridgeTokenRegistry;
        IStandardBridge standardBridge;
        ICrossDomainMessenger messenger;
        address localRelayer;
        address peerRelayer;
        IUniswapV4StandardExchangeDFPkg underlyingVaultPkg;
        IDetfSelfNftInventoryDFPkg detfNFTVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
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
            singleVaultDetfInfoFacet: facets_.infoFacet,
            singleVaultDetfExchangeOutFacet: facets_.exchangeOutFacet,
            singleVaultDetfBondingFacet: facets_.bondingFacet,
            operableFacet: facets_.operableFacet,
            feeOracle: infra_.feeOracle,
            vaultRegistryDeployment: infra_.vaultRegistryDeployment,
            permit2: infra_.permit2,
            rateAsset: infra_.rateAsset,
            balancerV3Vault: infra_.balancerV3Vault,
            balancerV3PrepayRouter: infra_.balancerV3PrepayRouter,
            weightedPool8020Factory: infra_.weightedPool8020Factory,
            bridgeTokenRegistry: infra_.bridgeTokenRegistry,
            standardBridge: infra_.standardBridge,
            messenger: infra_.messenger,
            localRelayer: infra_.localRelayer,
            peerRelayer: infra_.peerRelayer,
            underlyingVaultPkg: infra_.underlyingVaultPkg,
            detfNFTVaultPkg: infra_.detfNFTVaultPkg,
            rebasingClaimTokenPkg: infra_.rebasingClaimTokenPkg,
            rateProviderPkg: infra_.rateProviderPkg,
            diamondFactory: infra_.diamondFactory
        });
    }

    /// @notice Default Policy + 0,0 → product ±5% defaults after resolve.
    function buildPkgArgs(
        string memory name_,
        string memory symbol_,
        IERC20 pairToken_,
        uint256 pairInitialDepositAmount_,
        uint256 rateAssetInitialDepositAmount_,
        PoolKey memory underlyingPoolKey_,
        uint24 underlyingWidthMultiplier_
    ) internal pure returns (ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs_) {
        pkgArgs_ = buildPkgArgs(
            name_,
            symbol_,
            pairToken_,
            pairInitialDepositAmount_,
            rateAssetInitialDepositAmount_,
            underlyingPoolKey_,
            underlyingWidthMultiplier_,
            0,
            0,
            ThresholdMode.Policy
        );
    }

    function buildPkgArgs(
        string memory name_,
        string memory symbol_,
        IERC20 pairToken_,
        uint256 pairInitialDepositAmount_,
        uint256 rateAssetInitialDepositAmount_,
        PoolKey memory underlyingPoolKey_,
        uint24 underlyingWidthMultiplier_,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode thresholdMode_
    ) internal pure returns (ISingleVaultDetfDFPkg.PkgArgs memory pkgArgs_) {
        pkgArgs_ = ISingleVaultDetfDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            pairToken: pairToken_,
            pairInitialDepositAmount: pairInitialDepositAmount_,
            rateAssetInitialDepositAmount: rateAssetInitialDepositAmount_,
            underlyingPoolKey: underlyingPoolKey_,
            underlyingWidthMultiplier: underlyingWidthMultiplier_,
            mintThreshold: mintThreshold_,
            burnThreshold: burnThreshold_,
            thresholdMode: thresholdMode_
        });
    }
}