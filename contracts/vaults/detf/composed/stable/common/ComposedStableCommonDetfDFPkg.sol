// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IDiamond} from '@crane/contracts/interfaces/IDiamond.sol';
import {IDiamondFactoryPackage} from '@crane/contracts/interfaces/IDiamondFactoryPackage.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IStablePool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {IBasicVault} from 'contracts/interfaces/IBasicVault.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {IRICHIR} from 'contracts/interfaces/IRICHIR.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IStandardVault} from 'contracts/interfaces/IStandardVault.sol';
import {IVaultFeeOracleQuery} from 'contracts/interfaces/IVaultFeeOracleQuery.sol';
import {IStandardVaultPkg} from 'contracts/interfaces/IStandardVaultPkg.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {VaultFeeType} from 'contracts/interfaces/VaultFeeTypes.sol';
import {VaultTypeUtils} from 'contracts/registries/vault/VaultTypeUtils.sol';
import {MultiAssetBasicVaultRepo} from 'contracts/vaults/basic/MultiAssetBasicVaultRepo.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {StandardVaultRepo} from 'contracts/vaults/standard/StandardVaultRepo.sol';

interface IComposedStableCommonDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    struct PkgInit {
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet composedStableCommonDetfBondingFacet;
        IFacet composedStableCommonDetfExchangeInFacet;
        IFacet composedStableCommonDetfExchangeOutQueryFacet;
        IFacet rebasingDetfTokenPricingFacet;
        IVaultRegistryDeployment vaultRegistryDeployment;
    }

    struct PkgArgs {
        IWeightedPool reservePool;
        IDETFNFTVault bondNftVault;
        IRICHIR rebasingDetfToken;
        IERC20 detfToken;
        IERC20 stablePoolBpt;
        IERC20 commonPoolBpt;
        IERC20 wethToken;
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
    }
}

contract ComposedStableCommonDetfDFPkg is IComposedStableCommonDetfDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable COMPOSED_STABLE_COMMON_DETF_BONDING_FACET;
    IFacet immutable COMPOSED_STABLE_COMMON_DETF_EXCHANGE_IN_FACET;
    IFacet immutable COMPOSED_STABLE_COMMON_DETF_EXCHANGE_OUT_QUERY_FACET;
    IFacet immutable REBASING_DETF_TOKEN_PRICING_FACET;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;

    constructor(PkgInit memory pkgInit) {
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        COMPOSED_STABLE_COMMON_DETF_BONDING_FACET = pkgInit.composedStableCommonDetfBondingFacet;
        COMPOSED_STABLE_COMMON_DETF_EXCHANGE_IN_FACET = pkgInit.composedStableCommonDetfExchangeInFacet;
        COMPOSED_STABLE_COMMON_DETF_EXCHANGE_OUT_QUERY_FACET = pkgInit.composedStableCommonDetfExchangeOutQueryFacet;
        REBASING_DETF_TOKEN_PRICING_FACET = pkgInit.rebasingDetfTokenPricingFacet;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
    }

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(vaultFeeTypeIds_, VaultFeeType.USAGE, type(IDETF).interfaceId);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory name_) {
        return type(ComposedStableCommonDetfDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](6);
        facetAddresses_[0] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[2] = address(COMPOSED_STABLE_COMMON_DETF_BONDING_FACET);
        facetAddresses_[3] = address(COMPOSED_STABLE_COMMON_DETF_EXCHANGE_IN_FACET);
        facetAddresses_[4] = address(COMPOSED_STABLE_COMMON_DETF_EXCHANGE_OUT_QUERY_FACET);
        facetAddresses_[5] = address(REBASING_DETF_TOKEN_PRICING_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](6);
        interfaces_[0] = type(IBasicVault).interfaceId;
        interfaces_[1] = type(IStandardVault).interfaceId;
        interfaces_[2] = type(IComposedStableCommonDetfBonding).interfaceId;
        interfaces_[3] = type(IStandardExchangeIn).interfaceId;
        interfaces_[4] = type(IStandardExchangeOut).interfaceId;
        interfaces_[5] = type(IDETF).interfaceId;
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces_, address[] memory facets_)
    {
        name_ = packageName();
        interfaces_ = facetInterfaces();
        facets_ = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](6);
        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(COMPOSED_STABLE_COMMON_DETF_BONDING_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: COMPOSED_STABLE_COMMON_DETF_BONDING_FACET.facetFuncs()
        });
        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(COMPOSED_STABLE_COMMON_DETF_EXCHANGE_IN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: COMPOSED_STABLE_COMMON_DETF_EXCHANGE_IN_FACET.facetFuncs()
        });
        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(COMPOSED_STABLE_COMMON_DETF_EXCHANGE_OUT_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: COMPOSED_STABLE_COMMON_DETF_EXCHANGE_OUT_QUERY_FACET.facetFuncs()
        });
        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(REBASING_DETF_TOKEN_PRICING_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: REBASING_DETF_TOKEN_PRICING_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        address[] memory tokens_ = new address[](3);
        tokens_[0] = address(args.detfToken);
        tokens_[1] = address(args.stablePoolBpt);
        tokens_[2] = address(args.commonPoolBpt);

        MultiAssetBasicVaultRepo._initialize(tokens_);
        StandardVaultRepo._initialize(
            IVaultFeeOracleQuery(address(VAULT_REGISTRY_DEPLOYMENT)),
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(tokens_)._hash()
        );

        ComposedStableCommonDetfRepo._initializePricing(
            args.reservePool,
            args.bondNftVault,
            args.rebasingDetfToken,
            args.detfToken,
            args.stablePoolBpt,
            args.commonPoolBpt,
            args.wethToken,
            args.stablePoolExitPricer,
            args.commonPoolExitPricer,
            args.detfIndex,
            args.stablePoolBptIndex,
            args.commonPoolBptIndex
        );
        ComposedStableCommonDetfRepo._initializeExchangeIn(
            args.permit2,
            args.balancerV3Router,
            args.stablePool,
            args.commonPool,
            args.reservePoolEntryRouter,
            IVaultFeeOracleQuery(address(VAULT_REGISTRY_DEPLOYMENT)),
            args.mintThreshold,
            args.burnThreshold,
            args.routes
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}