// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    PoolRoleAccounts, TokenConfig, TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/DETFSYDFPkg.sol";
import {DETFSYDeploymentLib} from "contracts/vaults/detf/common/sy/DETFSYDeploymentLib.sol";
import {DETFChildTokenMetadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouterAwareRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";
import {IComposedStableCommonDetfInfo} from "./IComposedStableCommonDetfInfo.sol";
import {ComposedStableCommonDetfRepo as Repo} from "./ComposedStableCommonDetfRepo.sol";
import {IStablePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";
import {IWeightedPool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {
    DETFThresholdPolicy
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";

interface IComposedStableCommonDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error InvalidPackageArguments();
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet composedStableCommonDetfBondingFacet;
        IFacet composedStableCommonDetfExchangeInFacet;
        IFacet composedStableCommonDetfExchangeOutQueryFacet;
        IFacet rebasingDetfTokenPricingFacet;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery feeOracle;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        WeightedPoolFactory weightedPoolFactory;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDETFSYDFPkg syPkg;
    }
    struct PkgArgs {
        string name;
        string symbol;
        IStablePool stablePool;
        IStablePool commonPool;
        IERC20 rateAsset;
        IStandardExchangeIn stablePoolExitPricer;
        IStandardExchangeIn commonPoolExitPricer;
        uint256[3] reserveWeights; // DETF, stable BPT, common BPT; retain the configured host weights.
        // Whole stable/common BPT per whole purchased DETF, each scaled by 1e18.
        uint256[2] openingDetfPrices;
        // Proportional native seed amounts: DETF (9), stable BPT (18), common BPT (18).
        uint256[3] reserveSeedAmounts;
        uint256 reserveSwapFeePercentage;
        uint256 mintThreshold;
        uint256 burnThreshold;
        uint256 expansionClosureRatePerSecond;
        Repo.RouteConfig[] routes;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        string reserveName;
        string reserveSymbol;
    }
    function deployVault(PkgArgs memory args) external returns (address);
}
contract ComposedStableCommonDetfDFPkg is IComposedStableCommonDetfDFPkg {
    using BetterEfficientHashLib for bytes;
    bytes32 private constant DEPLOY_SLOT = keccak256("detf.composed.stable.common.pkg.pending-deployment");
    struct Deployment { bytes args; }
    function _deployment() private pure returns (Deployment storage d_) { bytes32 slot_ = DEPLOY_SLOT; assembly { d_.slot := slot_ } }
    IFacet private immutable F0;
    IFacet private immutable F1;
    IFacet private immutable F2;
    IFacet private immutable F3;
    IFacet private immutable F4;
    IFacet private immutable F5;
    IFacet private immutable F6;
    IFacet private immutable F7;
    IFacet private immutable F8;
    IVaultRegistryDeployment private immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery private immutable FEE_ORACLE;
    IBalancerV3StandardExchangeRouterProxy private immutable BALANCER_V3_ROUTER;
    IVault private immutable BALANCER_V3_VAULT;
    WeightedPoolFactory private immutable WEIGHTED_POOL_FACTORY;
    IDetfSelfNftInventoryDFPkg private immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg private immutable REBASING_CLAIM_TOKEN_PKG;
    IDETFSYDFPkg private immutable SY_PKG;
    constructor(PkgInit memory p_) {
        F0 = p_.erc20Facet;
        F1 = p_.erc5267Facet;
        F2 = p_.erc2612Facet;
        F3 = p_.multiAssetBasicVaultFacet;
        F4 = p_.multiAssetStandardVaultFacet;
        F5 = p_.composedStableCommonDetfBondingFacet;
        F6 = p_.composedStableCommonDetfExchangeInFacet;
        F7 = p_.composedStableCommonDetfExchangeOutQueryFacet;
        F8 = p_.rebasingDetfTokenPricingFacet;
        VAULT_REGISTRY_DEPLOYMENT = p_.vaultRegistryDeployment;
        FEE_ORACLE = p_.feeOracle;
        BALANCER_V3_ROUTER = p_.balancerV3Router;
        BALANCER_V3_VAULT = p_.balancerV3Vault;
        WEIGHTED_POOL_FACTORY = p_.weightedPoolFactory;
        BOND_NFT_VAULT_PKG = p_.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = p_.rebasingClaimTokenPkg;
        SY_PKG = p_.syPkg;
    }
    function packageName() public pure returns (string memory) { return type(ComposedStableCommonDetfDFPkg).name; }
    function name() public pure returns (string memory) { return packageName(); }
    function vaultFeeTypeIds() public pure returns (bytes32 ids_) { return VaultTypeUtils._insertFeeTypeId(ids_, VaultFeeType.USAGE, type(IDetf).interfaceId); }
    function vaultTypes() public pure returns (bytes4[] memory) { return facetInterfaces(); }
    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory) { return VaultPkgDeclaration(name(), vaultFeeTypeIds(), vaultTypes()); }
    function facetAddresses() public view returns (address[] memory a_) {
        a_ = new address[](9);
        a_[0] = address(F0);
        a_[1] = address(F1);
        a_[2] = address(F2);
        a_[3] = address(F3);
        a_[4] = address(F4);
        a_[5] = address(F5);
        a_[6] = address(F6);
        a_[7] = address(F7);
        a_[8] = address(F8);
    }
    function facetInterfaces() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](9);
        a_[0] = type(IERC20Metadata).interfaceId; a_[1] = type(IERC20Permit).interfaceId; a_[2] = type(IERC5267).interfaceId;
        a_[3] = type(IBasicVault).interfaceId; a_[4] = type(IStandardVault).interfaceId;
        a_[5] = type(IStandardExchangeIn).interfaceId; a_[6] = type(IStandardExchangeOut).interfaceId;
        a_[7] = type(IComposedStableCommonDetfBonding).interfaceId; a_[8] = type(IComposedStableCommonDetfInfo).interfaceId;
    }
    function packageMetadata() public view returns (string memory, bytes4[] memory, address[] memory) { return (packageName(), facetInterfaces(), facetAddresses()); }
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        address[] memory facets_ = facetAddresses(); cuts_ = new IDiamond.FacetCut[](facets_.length);
        for (uint256 i_; i_ < facets_.length; ++i_) cuts_[i_] = IDiamond.FacetCut(facets_[i_], IDiamond.FacetCutAction.Add, IFacet(facets_[i_]).facetFuncs());
    }
    function diamondConfig() public view returns (DiamondConfig memory) { return DiamondConfig(facetCuts(), facetInterfaces()); }
    function calcSalt(bytes memory args_) public pure returns (bytes32) { return abi.encode(args_)._hash(); }
    function updatePkg(address, bytes memory) public pure returns (bool) { return true; }
    function deployVault(PkgArgs memory args_) external returns (address) { return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args_)); }
    function processArgs(bytes memory args_) public view returns (bytes memory) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) revert NotCalledByRegistry(msg.sender);
        PkgArgs memory p_ = abi.decode(args_, (PkgArgs));
        if (keccak256(args_) != keccak256(abi.encode(p_))) revert InvalidPackageArguments();
        _validate(p_); return args_;
    }
    function _validate(PkgArgs memory p_) private view {
        if (address(p_.stablePool) == address(p_.commonPool) || address(p_.rateAsset) == address(0)
            || address(p_.stablePoolExitPricer).code.length == 0 || address(p_.commonPoolExitPricer).code.length == 0) revert InvalidPackageArguments();
        if (p_.openingDetfPrices[0] == 0 || p_.openingDetfPrices[1] == 0) revert InvalidPackageArguments();
        for (uint256 i_; i_ < 3; ++i_) if (p_.reserveSeedAmounts[i_] == 0) revert InvalidPackageArguments();
        uint256 sum_;
        for (uint256 i_; i_ < 3; ++i_) { if (p_.reserveWeights[i_] == 0) revert InvalidPackageArguments(); sum_ += p_.reserveWeights[i_]; }
        if (sum_ != 1e18) revert InvalidPackageArguments();
        (IERC20[] memory stable_,,,) = BALANCER_V3_VAULT.getPoolTokenInfo(address(p_.stablePool));
        (IERC20[] memory common_,,,) = BALANCER_V3_VAULT.getPoolTokenInfo(address(p_.commonPool));
        for (uint256 i_; i_ < p_.routes.length; ++i_) {
            Repo.RouteConfig memory route_ = p_.routes[i_];
            if (address(route_.baseToken) == address(0) || address(route_.underlyingVault) != address(route_.vaultToken)
                || !IVaultRegistryVaultQuery(address(VAULT_REGISTRY_DEPLOYMENT)).isVault(address(route_.underlyingVault))
                || route_.stablePoolTokenIndex >= stable_.length || route_.commonPoolTokenIndex >= common_.length
                || address(stable_[route_.stablePoolTokenIndex]) != address(route_.vaultToken) || address(common_[route_.commonPoolTokenIndex]) != address(route_.vaultToken)
                || address(route_.stablePoolRouter) != address(p_.stablePoolExitPricer) || address(route_.commonPoolRouter) != address(p_.commonPoolExitPricer)) revert InvalidPackageArguments();
        }
    }
    function initAccount(bytes memory args_) public {
        PkgArgs memory p_ = abi.decode(args_, (PkgArgs));
        if (keccak256(args_) != keccak256(abi.encode(p_))) revert InvalidPackageArguments();
        _validate(p_);
        ERC20Repo._initialize(p_.name, p_.symbol, 9); EIP712Repo._initialize(p_.name, "1");
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        BalancerV3StandardExchangeRouterAwareRepo._initialize(BALANCER_V3_ROUTER);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(p_.stablePool, p_.commonPool, p_.routes)._hash());
        Repo.Storage storage s_ = Repo._layoutStruct();
        s_.stablePool = p_.stablePool; s_.commonPool = p_.commonPool; s_.rateAsset = p_.rateAsset;
        s_.openingDetfPrices = p_.openingDetfPrices; s_.reserveSeedAmounts = p_.reserveSeedAmounts;
        s_.stablePoolExitPricer = p_.stablePoolExitPricer; s_.commonPoolExitPricer = p_.commonPoolExitPricer;
        s_.balancerV3Router = BALANCER_V3_ROUTER; s_.feeOracle = FEE_ORACLE;
        (s_.mintThreshold, s_.burnThreshold) = DETFThresholdPolicy.resolveAndRequireValidThresholds(p_.mintThreshold, p_.burnThreshold);
        s_.expansionClosureRatePerSecond = DETFNaturalExpansionLib.resolveClosureRate(p_.expansionClosureRatePerSecond);
        for (uint256 i_; i_ < p_.routes.length; ++i_) s_.routes.push(p_.routes[i_]);
        _deployment().args = args_;
        emit IComposedStableCommonDetfInfo.ThresholdsSet(s_.mintThreshold, s_.burnThreshold);
    }
    function postDeploy(address expected_) external returns (bool) {
        if (address(this) != expected_) { IPostDeployAccountHook(expected_).postDeploy(); return true; }
        PkgArgs memory p_ = abi.decode(_deployment().args, (PkgArgs));
        Repo.Storage storage s_ = Repo._layoutStruct();
        s_.reservePool = IWeightedPool(_createPool(p_));
        s_.bondNftVault = IDETFNFTVault(BOND_NFT_VAULT_PKG.deployVault(
            DETFChildTokenMetadata.resolveBondName(p_.bondName, ERC20Repo._name()),
            DETFChildTokenMetadata.resolveBondSymbol(p_.bondSymbol, ERC20Repo._symbol()), IDetf(address(this)), IERC20(address(s_.reservePool))
        ));
        IDetfBondNFT(address(s_.bondNftVault)).initializeReservedBondNfts(address(FEE_ORACLE.feeTo()), p_.creator);
        s_.rebasingDetfToken = IStakedDETF(REBASING_CLAIM_TOKEN_PKG.deployToken(
            IDetf(address(this)), s_.bondNftVault, FEE_ORACLE,
            DETFChildTokenMetadata.resolveClaimName(p_.claimName, ERC20Repo._name()),
            DETFChildTokenMetadata.resolveClaimSymbol(p_.claimSymbol, ERC20Repo._symbol())
        ));
        _initTokensAndSY(s_);
        delete _deployment().args;
        return true;
    }
    function _createPool(PkgArgs memory p_) private returns (address) {
        TokenConfig[] memory tokens_ = new TokenConfig[](3); uint256[] memory weights_ = new uint256[](3);
        IERC20[3] memory logical_ = [IERC20(address(this)), IERC20(address(p_.stablePool)), IERC20(address(p_.commonPool))];
        for (uint256 i_; i_ < 3; ++i_) { tokens_[i_] = TokenConfig(logical_[i_], TokenType.STANDARD, IRateProvider(address(0)), false); weights_[i_] = p_.reserveWeights[i_]; }
        for (uint256 i_; i_ < 3; ++i_) for (uint256 j_ = i_ + 1; j_ < 3; ++j_) if (address(tokens_[j_].token) < address(tokens_[i_].token)) {
            (tokens_[i_], tokens_[j_]) = (tokens_[j_], tokens_[i_]); (weights_[i_], weights_[j_]) = (weights_[j_], weights_[i_]);
        }
        Repo.Storage storage s_ = Repo._layoutStruct();
        for (uint256 i_; i_ < 3; ++i_) {
            if (tokens_[i_].token == logical_[0]) s_.detfIndex = i_;
            else if (tokens_[i_].token == logical_[1]) s_.stablePoolBptIndex = i_; else s_.commonPoolBptIndex = i_;
        }
        return _factoryCreate(p_, tokens_, weights_);
    }
    function _factoryCreate(PkgArgs memory p_, TokenConfig[] memory tokens_, uint256[] memory weights_) private returns (address) {
        PoolRoleAccounts memory roles_;
        bytes32 salt_ = keccak256(abi.encode(address(this), p_.reserveWeights));
        return WEIGHTED_POOL_FACTORY.create(
            DETFChildTokenMetadata.resolveReserveName(p_.reserveName, ERC20Repo._name()), DETFChildTokenMetadata.resolveReserveSymbol(p_.reserveSymbol, ERC20Repo._symbol()),
            tokens_, weights_, roles_, p_.reserveSwapFeePercentage == 0 ? 0.003e18 : p_.reserveSwapFeePercentage,
            address(0), false, false, salt_
        );
    }
    function _initTokensAndSY(Repo.Storage storage s_) private {
        address[] memory inputs_ = IComposedStableCommonDetfInfo(address(this)).tokensIn();
        address[] memory outputs_ = IComposedStableCommonDetfInfo(address(this)).tokensOut();
        address[] memory contents_ = new address[](outputs_.length + 3);
        for (uint256 i_; i_ < outputs_.length; ++i_) contents_[i_] = outputs_[i_];
        contents_[outputs_.length] = address(this); contents_[outputs_.length + 1] = address(s_.rebasingDetfToken); contents_[outputs_.length + 2] = address(s_.reservePool);
        MultiAssetBasicVaultRepo._initialize(contents_);
        DETFSYDeploymentLib._deploy(SY_PKG, s_.rebasingDetfToken, inputs_, outputs_);
    }
}
