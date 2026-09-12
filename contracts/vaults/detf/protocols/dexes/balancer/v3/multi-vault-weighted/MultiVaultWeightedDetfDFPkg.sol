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
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    DETFThresholdPolicy
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";

/// @title IMultiVaultWeightedDetfDFPkg
interface IMultiVaultWeightedDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error UnregisteredVault(address vault);
    error InvalidVaultShare(uint256 index, address vault, address vaultShare);
    error InvalidPackageArguments();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet bondingFacet;
        IFacet infoFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        WeightedPoolFactory weightedPoolFactory;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDETFSYDFPkg syPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Per-instance args. Arrays must share length N in [1,7].
    /// @dev `vaultShares[i]` must be the registered SE share of `vaults[i]` (the vault diamond ERC-20).
    /// @dev `address(0)` does **not** alias to `vaults[i]`. Hostile or missing share reverts.
    /// @dev `rateProviders`/`rateAssets` zero = unrated leg.
    /// @dev `weightDetf + sum(vaultWeights) == 1e18`; each weight > 0. Zero weightDetf not allowed.
    /// @dev Every instance has mandatory price gates and uncapped fixed eight-hour expansion.
    struct PkgArgs {
        string name;
        string symbol;
        IStandardExchangeProxy[] vaults;
        IERC20[] vaultShares;
        IRateProvider[] rateProviders;
        IERC20[] rateAssets;
        uint256 weightDetf;
        uint256[] vaultWeights;
        uint256 mintThreshold; // 0 → 1.05e18
        uint256 burnThreshold; // 0 → 0.95e18
        uint256 expansionClosureRatePerSecond; // 0 → default
        address creator; // D26; 0 → feeTo owns id 2 (D21)
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        string reserveName;
        string reserveSymbol;
    }

    function deployVault(PkgArgs memory args) external returns (address vault);
}

/// @title MultiVaultWeightedDetfDFPkg
/// @notice Immutable/unowned DETF package: self + N Standard Exchange vault shares in weighted reserve.
contract MultiVaultWeightedDetfDFPkg is IMultiVaultWeightedDetfDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT =
        keccak256("vault.detf.composed.multi-vault-weighted.pkg.deploy-config");

    uint256 private constant _ONE = 1e18;
    uint256 private constant _MAX_VAULTS = 7;

    struct DeployConfig {
        uint8 vaultCount;
        IStandardExchangeProxy[7] vaults;
        IERC20[7] vaultShares;
        IRateProvider[7] rateProviders;
        IERC20[7] rateAssets;
        uint256 weightDetf;
        uint256[7] vaultWeights;
        uint256 mintThreshold;
        uint256 burnThreshold;
        uint256 expansionClosureRatePerSecond;
        address creator;
        string claimName;
        string claimSymbol;
        string bondName;
        string bondSymbol;
        string reserveName;
        string reserveSymbol;
    }

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable EXCHANGE_IN_FACET;
    IFacet immutable BONDING_FACET;
    IFacet immutable INFO_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IBalancerV3StandardExchangeRouterProxy immutable BALANCER_V3_ROUTER;
    IVault immutable BALANCER_V3_VAULT;
    WeightedPoolFactory immutable WEIGHTED_POOL_FACTORY;
    IStandardExchangeRateProviderDFPkg immutable RATE_PROVIDER_PKG;
    IDetfSelfNftInventoryDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;
    IDETFSYDFPkg immutable SY_PKG;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        BONDING_FACET = pkgInit.bondingFacet;
        INFO_FACET = pkgInit.infoFacet;
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        BALANCER_V3_ROUTER = pkgInit.balancerV3Router;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        WEIGHTED_POOL_FACTORY = pkgInit.weightedPoolFactory;
        RATE_PROVIDER_PKG = pkgInit.rateProviderPkg;
        BOND_NFT_VAULT_PKG = pkgInit.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = pkgInit.rebasingClaimTokenPkg;
        SY_PKG = pkgInit.syPkg;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function _deployConfig() internal pure returns (DeployConfig storage cfg_) {
        bytes32 slot_ = _DEPLOY_CONFIG_SLOT;
        assembly {
            cfg_.slot := slot_
        }
    }

    function deployVault(PkgArgs memory args) external returns (address vault) {
        return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    function packageName() public pure returns (string memory) {
        return type(MultiVaultWeightedDetfDFPkg).name;
    }

    function name() public pure returns (string memory) {
        return packageName();
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardExchangeIn).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs_) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration_) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](8);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(BONDING_FACET);
        facetAddresses_[7] = address(INFO_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](10);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IMultiVaultWeightedDetfBonding).interfaceId;
        interfaces_[8] = type(IMultiVaultWeightedDetfInfo).interfaceId;
        interfaces_[9] = type(IStandardExchangeOut).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](8);
        facetCuts_[0] = IDiamond.FacetCut(address(ERC20_FACET), IDiamond.FacetCutAction.Add, ERC20_FACET.facetFuncs());
        facetCuts_[1] =
            IDiamond.FacetCut(address(ERC5267_FACET), IDiamond.FacetCutAction.Add, ERC5267_FACET.facetFuncs());
        facetCuts_[2] =
            IDiamond.FacetCut(address(ERC2612_FACET), IDiamond.FacetCutAction.Add, ERC2612_FACET.facetFuncs());
        facetCuts_[3] = IDiamond.FacetCut(
            address(MULTI_ASSET_BASIC_VAULT_FACET), IDiamond.FacetCutAction.Add, MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        );
        facetCuts_[4] = IDiamond.FacetCut(
            address(MULTI_ASSET_STANDARD_VAULT_FACET),
            IDiamond.FacetCutAction.Add,
            MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        );
        facetCuts_[5] =
            IDiamond.FacetCut(address(EXCHANGE_IN_FACET), IDiamond.FacetCutAction.Add, EXCHANGE_IN_FACET.facetFuncs());
        facetCuts_[6] =
            IDiamond.FacetCut(address(BONDING_FACET), IDiamond.FacetCutAction.Add, BONDING_FACET.facetFuncs());
        facetCuts_[7] = IDiamond.FacetCut(address(INFO_FACET), IDiamond.FacetCutAction.Add, INFO_FACET.facetFuncs());
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        return keccak256(pkgArgs);
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        PkgArgs memory args = abi.decode(pkgArgs, (PkgArgs));
        if (keccak256(pkgArgs) != keccak256(abi.encode(args))) revert InvalidPackageArguments();
        uint256 n_ = args.vaults.length;
        if (args.vaultShares.length != n_) {
            revert MultiVaultWeightedDetfRepo.InvalidVaultCount(n_);
        }
        IVaultRegistryVaultQuery registry_ = IVaultRegistryVaultQuery(address(VAULT_REGISTRY_DEPLOYMENT));
        for (uint256 i; i < n_; ++i) {
            address vault_ = address(args.vaults[i]);
            address share_ = address(args.vaultShares[i]);
            if (vault_ == address(0) || !registry_.isVault(vault_)) {
                revert UnregisteredVault(vault_);
            }
            // Registered SE diamonds are their own share ERC-20. No silent address(0) alias.
            if (share_ == address(0) || share_ != vault_) {
                revert InvalidVaultShare(i, vault_, share_);
            }
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        if (keccak256(initArgs) != keccak256(abi.encode(args))) revert InvalidPackageArguments();
        uint256 n_ = args.vaults.length;
        if (n_ == 0 || n_ > _MAX_VAULTS) revert MultiVaultWeightedDetfRepo.InvalidVaultCount(n_);
        if (
            args.vaultShares.length != n_ || args.rateProviders.length != n_ || args.rateAssets.length != n_
                || args.vaultWeights.length != n_
        ) {
            revert MultiVaultWeightedDetfRepo.InvalidVaultCount(n_);
        }
        if (args.weightDetf == 0) revert MultiVaultWeightedDetfRepo.InvalidWeights();
        uint256 sum_ = args.weightDetf;
        for (uint256 i; i < n_; ++i) {
            if (args.vaultWeights[i] == 0) revert MultiVaultWeightedDetfRepo.InvalidWeights();
            if (address(args.vaults[i]) == address(0)) revert MultiVaultWeightedDetfRepo.InvalidVaultCount(n_);
            for (uint256 j = i + 1; j < n_; ++j) {
                if (address(args.vaults[i]) == address(args.vaults[j])) {
                    revert MultiVaultWeightedDetfRepo.DuplicateVault(address(args.vaults[i]));
                }
            }
            // rate config: provider XOR rateAsset consistency — both zero or both non-zero
            bool hasRp_ = address(args.rateProviders[i]) != address(0);
            bool hasRa_ = address(args.rateAssets[i]) != address(0);
            // Allow both zero (unrated). If rateAsset set without provider, deploy will create one.
            // If provider set without rateAsset, invalid.
            if (hasRp_ && !hasRa_) revert MultiVaultWeightedDetfRepo.InvalidRateConfig(i);
            sum_ += args.vaultWeights[i];
        }
        if (sum_ != _ONE) revert MultiVaultWeightedDetfRepo.InvalidWeights();

        ERC20Repo._initialize(args.name, args.symbol, 9);
        EIP712Repo._initialize(args.name, "1");
        BalancerV3StandardExchangeRouterAwareRepo._initialize(BALANCER_V3_ROUTER);
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        address[] memory contents_ = new address[](n_ + 1);
        for (uint256 i; i < n_; ++i) {
            contents_[i] = address(args.vaults[i]);
        }
        contents_[n_] = address(this);
        StandardVaultRepo._initialize(
            FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash()
        );

        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        uint256 expRate_ = DETFNaturalExpansionLib.resolveClosureRate(args.expansionClosureRatePerSecond);

        DeployConfig storage cfg = _deployConfig();
        cfg.vaultCount = uint8(n_);
        cfg.weightDetf = args.weightDetf;
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.expansionClosureRatePerSecond = expRate_;
        for (uint256 i; i < n_; ++i) {
            cfg.vaults[i] = args.vaults[i];
            cfg.vaultShares[i] = args.vaultShares[i];
            cfg.rateProviders[i] = args.rateProviders[i];
            cfg.rateAssets[i] = args.rateAssets[i];
            cfg.vaultWeights[i] = args.vaultWeights[i];
        }
        cfg.creator = args.creator;
        cfg.claimName = args.claimName;
        cfg.claimSymbol = args.claimSymbol;
        cfg.bondName = args.bondName;
        cfg.bondSymbol = args.bondSymbol;
        cfg.reserveName = args.reserveName;
        cfg.reserveSymbol = args.reserveSymbol;
    }

    function postDeploy(address expectedProxy) public returns (bool) {
        if (address(this) != expectedProxy) {
            IPostDeployAccountHook(expectedProxy).postDeploy();
            return true;
        }
        _postDeployProxyContext();
        return true;
    }

    function _postDeployProxyContext() internal {
        DeployConfig storage cfg = _deployConfig();
        _deployRateProviders(cfg);
        (address reservePool_, uint256 detfIndex_, uint256[] memory shareIndexes_) = _createWeightedReservePool(cfg);
        IDETFNFTVault bondVault_ = _deployBondNftVault(reservePool_);
        IDetfBondNFT(address(bondVault_)).initializeReservedBondNfts(address(FEE_ORACLE.feeTo()), cfg.creator);
        IStakedDETF claimToken_ = _deployRebasingClaimToken(cfg, bondVault_);
        _initBasicVaultTokens(cfg, reservePool_, address(claimToken_));
        _initFamilyRepo(cfg, reservePool_, detfIndex_, shareIndexes_, bondVault_, claimToken_);
        address[] memory routes_ = new address[](cfg.vaultCount);
        for (uint256 i; i < cfg.vaultCount; ++i) routes_[i] = address(cfg.vaultShares[i]);
        DETFSYDeploymentLib._deploy(SY_PKG, claimToken_, routes_, routes_);
    }

    function _deployRebasingClaimToken(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_
    ) private returns (IStakedDETF claimToken_) {
        address detf_ = address(this);
        claimToken_ = IStakedDETF(
            REBASING_CLAIM_TOKEN_PKG.deployToken(
                IDetf(detf_),
                bondVault_,
                FEE_ORACLE,
                DETFChildTokenMetadata.resolveClaimName(cfg.claimName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveClaimSymbol(cfg.claimSymbol, ERC20Repo._symbol())
            )
        );
    }

    function _deployRateProviders(DeployConfig storage cfg) private {
        for (uint256 i; i < cfg.vaultCount; ++i) {
            if (address(cfg.rateAssets[i]) == address(0)) continue;
            if (address(cfg.rateProviders[i]) != address(0)) continue;
            cfg.rateProviders[i] = RATE_PROVIDER_PKG.deployRateProvider(
                IStandardExchange(address(cfg.vaults[i])), cfg.vaultShares[i], cfg.rateAssets[i]
            );
        }
    }

    struct PoolBuildScratch {
        uint256 n;
        uint256 detfIndex;
        uint256[] shareIndexes;
        TokenConfig[] tokens;
        uint256[] weights;
        address[] addrs;
        uint256[] order;
    }

    function _createWeightedReservePool(DeployConfig storage cfg)
        private
        returns (address pool_, uint256 detfIndex_, uint256[] memory shareIndexes_)
    {
        PoolBuildScratch memory pb = _buildTokenConfigs(cfg);
        pool_ = _factoryCreatePool(pb.tokens, pb.weights, cfg.vaultCount);
        detfIndex_ = pb.detfIndex;
        shareIndexes_ = pb.shareIndexes;
    }

    function _buildTokenConfigs(DeployConfig storage cfg) private view returns (PoolBuildScratch memory pb) {
        pb.n = uint256(cfg.vaultCount) + 1;
        pb.tokens = new TokenConfig[](pb.n);
        pb.weights = new uint256[](pb.n);
        pb.shareIndexes = new uint256[](cfg.vaultCount);
        pb.addrs = new address[](pb.n);
        pb.addrs[0] = address(this);
        for (uint256 i; i < cfg.vaultCount; ++i) {
            pb.addrs[i + 1] = address(cfg.vaultShares[i]);
        }
        pb.order = _sortOrder(pb.addrs);
        for (uint256 sortedIdx; sortedIdx < pb.n; ++sortedIdx) {
            _fillTokenSlot(cfg, pb, sortedIdx);
        }
    }

    function _sortOrder(address[] memory addrs_) private pure returns (uint256[] memory order_) {
        uint256 n_ = addrs_.length;
        order_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            order_[i] = i;
        }
        for (uint256 i; i < n_; ++i) {
            for (uint256 j = i + 1; j < n_; ++j) {
                if (addrs_[order_[j]] < addrs_[order_[i]]) {
                    (order_[i], order_[j]) = (order_[j], order_[i]);
                }
            }
        }
    }

    function _fillTokenSlot(DeployConfig storage cfg, PoolBuildScratch memory pb, uint256 sortedIdx)
        private
        view
    {
        uint256 orig_ = pb.order[sortedIdx];
        if (orig_ == 0) {
            pb.detfIndex = sortedIdx;
            pb.tokens[sortedIdx] =
                TokenConfig(IERC20(address(this)), TokenType.STANDARD, IRateProvider(address(0)), false);
            pb.weights[sortedIdx] = cfg.weightDetf;
            return;
        }
        uint256 leg_ = orig_ - 1;
        pb.shareIndexes[leg_] = sortedIdx;
        IRateProvider rp_ = cfg.rateProviders[leg_];
        bool withRate_ = address(rp_) != address(0);
        pb.tokens[sortedIdx] = TokenConfig(
            cfg.vaultShares[leg_],
            withRate_ ? TokenType.WITH_RATE : TokenType.STANDARD,
            withRate_ ? rp_ : IRateProvider(address(0)),
            false
        );
        pb.weights[sortedIdx] = cfg.vaultWeights[leg_];
    }

    function _factoryCreatePool(TokenConfig[] memory tokens_, uint256[] memory weights_, uint8 vaultCount_)
        private
        returns (address pool_)
    {
        PoolRoleAccounts memory roles_;
        bytes32 salt_ = keccak256(abi.encode(address(this), vaultCount_, block.timestamp));
        pool_ = WEIGHTED_POOL_FACTORY.create(
            DETFChildTokenMetadata.resolveReserveName(_deployConfig().reserveName, ERC20Repo._name()),
            DETFChildTokenMetadata.resolveReserveSymbol(_deployConfig().reserveSymbol, ERC20Repo._symbol()),
            tokens_,
            weights_,
            roles_,
            0.003e18,
            address(0),
            false,
            false,
            salt_
        );
    }

    function _deployBondNftVault(address reservePool_) private returns (IDETFNFTVault bondVault_) {
        address detf_ = address(this);
        bondVault_ = IDETFNFTVault(
            BOND_NFT_VAULT_PKG.deployVault(
                DETFChildTokenMetadata.resolveBondName(_deployConfig().bondName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveBondSymbol(_deployConfig().bondSymbol, ERC20Repo._symbol()),
                IDetf(detf_),
                IERC20(reservePool_)
            )
        );
    }

    function _initBasicVaultTokens(DeployConfig storage cfg, address reservePool_, address staking_) private {
        // DETF + configured vault shares + reserve LP + funded staking token
        address[] memory vaultTokens_ = new address[](uint256(cfg.vaultCount) + 3);
        vaultTokens_[0] = address(this);
        for (uint256 i; i < cfg.vaultCount; ++i) {
            vaultTokens_[i + 1] = address(cfg.vaultShares[i]);
        }
        vaultTokens_[cfg.vaultCount + 1] = reservePool_;
        vaultTokens_[cfg.vaultCount + 2] = staking_;
        MultiAssetBasicVaultRepo._initialize(vaultTokens_);
    }

    function _initFamilyRepo(
        DeployConfig storage cfg,
        address reservePool_,
        uint256 detfIndex_,
        uint256[] memory shareIndexes_,
        IDETFNFTVault bondVault_,
        IStakedDETF claimToken_
    ) private {
        MultiVaultWeightedDetfRepo.InitParams memory p;
        p.vaultCount = cfg.vaultCount;
        p.weightDetf = cfg.weightDetf;
        p.detfIndex = detfIndex_;
        p.vaultShareIndexes = shareIndexes_;
        p.reservePool = reservePool_;
        p.mintThreshold = cfg.mintThreshold;
        p.burnThreshold = cfg.burnThreshold;
        p.feeOracle = FEE_ORACLE;
        p.bondNftVault = bondVault_;
        p.rebasingClaimToken = claimToken_;
        p.expansionClosureRatePerSecond = cfg.expansionClosureRatePerSecond;
        _copyLegsToInitParams(cfg, p);
        MultiVaultWeightedDetfRepo._initialize(p);
        // Emit once after storage write with resolved thresholds (PRD §16.4).
        emit IMultiVaultWeightedDetfInfo.ThresholdsSet(cfg.mintThreshold, cfg.burnThreshold);
    }

    function _copyLegsToInitParams(DeployConfig storage cfg, MultiVaultWeightedDetfRepo.InitParams memory p)
        private
        view
    {
        uint256 n_ = cfg.vaultCount;
        p.vaults = new IStandardExchangeProxy[](n_);
        p.shares = new IERC20[](n_);
        p.rateProviders = new IRateProvider[](n_);
        p.rateAssets = new IERC20[](n_);
        p.vaultWeights = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            p.vaults[i] = cfg.vaults[i];
            p.shares[i] = cfg.vaultShares[i];
            p.rateProviders[i] = cfg.rateProviders[i];
            p.rateAssets[i] = cfg.rateAssets[i];
            p.vaultWeights[i] = cfg.vaultWeights[i];
        }
    }
}
