// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ISingleStandardExchangeDETDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETDFPkg.sol";

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
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {IWeightedPool} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
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
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
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
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/IRebasingClaimTokenDFPkg.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {DETFChildTokenMetadata} from "contracts/vaults/detf/common/DETFChildTokenMetadata.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";
import {ISingleStandardExchangeDETFBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol";
import {ISingleStandardExchangeDETFInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";
import {
    DETFThresholdPolicy
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {DETFSYDeploymentLib} from "contracts/vaults/detf/common/sy/DETFSYDeploymentLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";



/// @title SingleStandardExchangeDETDFPkg
/// @notice Immutable/unowned DETF package: self + one Standard Exchange vault share in 80/20 reserve.
contract SingleStandardExchangeDETDFPkg is ISingleStandardExchangeDETDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT =
        keccak256("vault.detf.standardExchange.single.pkg.deploy-config");

    uint256 private constant _EIGHTY = 80e16;
    uint256 private constant _TWENTY = 20e16;

    struct DeployConfig {
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 rateTarget;
        uint256 detfWeight;
        uint256 vaultShareWeight;
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
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IBalancerV3StandardExchangeRouterProxy immutable BALANCER_V3_ROUTER;
    IVault immutable BALANCER_V3_VAULT;
    IWeightedPoolFactory immutable WEIGHTED_POOL_FACTORY;
    IStandardExchangeRateProviderDFPkg immutable RATE_PROVIDER_PKG;
    IDetfSelfNftInventoryDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;
    IDETFSYDFPkg immutable SY_PKG;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        if (address(pkgInit.rebasingClaimTokenPkg) == address(0) || address(pkgInit.syPkg) == address(0)) {
            revert ZeroAddress();
        }
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        BONDING_FACET = pkgInit.bondingFacet;
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
        return type(SingleStandardExchangeDETDFPkg).name;
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
        facetAddresses_ = new address[](7);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(BONDING_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](12);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(ISingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[8] = type(ISingleStandardExchangeDETFInfo).interfaceId;
        interfaces_[9] = type(IDETFFundedRewards).interfaceId;
        interfaces_[10] = type(IDETFStandardizedYield).interfaceId;
        interfaces_[11] = type(IDETFStakingPreview).interfaceId;
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
        facetCuts_ = new IDiamond.FacetCut[](7);
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
        facetCuts_[6] = IDiamond.FacetCut(address(BONDING_FACET), IDiamond.FacetCutAction.Add, BONDING_FACET.facetFuncs());
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
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        if (keccak256(initArgs) != keccak256(abi.encode(args))) revert InvalidPackageArguments();
        ERC20Repo._initialize(args.name, args.symbol, 9);
        EIP712Repo._initialize(args.name, "1");
        BalancerV3StandardExchangeRouterAwareRepo._initialize(BALANCER_V3_ROUTER);
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
        address[] memory contents_ = new address[](2);
        contents_[0] = address(args.standardExchangeVault);
        contents_[1] = address(args.rateTarget);
        StandardVaultRepo._initialize(
            FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash()
        );

        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        uint256 expRate_ = DETFNaturalExpansionLib.resolveClosureRate(args.expansionClosureRatePerSecond);

        DeployConfig storage cfg = _deployConfig();
        cfg.standardExchangeVault = args.standardExchangeVault;
        cfg.standardExchangeVaultShare = address(args.standardExchangeVaultShare) == address(0)
            ? IERC20(address(args.standardExchangeVault))
            : args.standardExchangeVaultShare;
        cfg.rateTarget = args.rateTarget;
        cfg.detfWeight = args.detfWeight == 0 ? _EIGHTY : args.detfWeight;
        cfg.vaultShareWeight = args.vaultShareWeight == 0 ? _TWENTY : args.vaultShareWeight;
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.expansionClosureRatePerSecond = expRate_;
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

    struct PoolBuild {
        address reservePool;
        uint256 detfIndex;
        uint256 shareIndex;
        IRateProvider rateProvider;
        IERC20 seShare;
    }

    function _postDeployProxyContext() internal {
        DeployConfig storage cfg = _deployConfig();
        PoolBuild memory pb_ = _createRateProviderAndPool(cfg);
        IDETFNFTVault bondVault_ = _deployBondNftVault(pb_.reservePool);
        // Bond vault initializeDETFNFT() before claim init so detfNFTId is known.
        _tryInitDetfNft(bondVault_);
        IRebasingClaimToken claimToken_ = _deployRebasingClaimToken(cfg, bondVault_);
        _initBasicVaultTokens(address(pb_.seShare), pb_.reservePool, address(claimToken_));
        _initFamilyRepo(cfg, pb_, bondVault_, claimToken_);
        address[] memory routes_ = ISingleStandardExchangeDETFBonding(address(this)).acceptedBondTokens();
        DETFSYDeploymentLib._deploy(SY_PKG, IStakedDETF(address(claimToken_)), routes_, routes_);
    }

    function _deployRebasingClaimToken(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_
    ) private returns (IRebasingClaimToken claimToken_) {
        address detf_ = address(this);
        claimToken_ = IRebasingClaimToken(
            REBASING_CLAIM_TOKEN_PKG.deployToken(
                IDetf(detf_),
                bondVault_,
                FEE_ORACLE,
                DETFChildTokenMetadata.resolveClaimName(cfg.claimName, ERC20Repo._name()),
                DETFChildTokenMetadata.resolveClaimSymbol(cfg.claimSymbol, ERC20Repo._symbol())
            )
        );
        if (address(claimToken_) == address(0)) {
            revert ClaimTokenNotDeployed();
        }
        if (claimToken_.detf() != detf_) revert ClaimTokenNotDeployed();
    }

    function _createRateProviderAndPool(DeployConfig storage cfg) private returns (PoolBuild memory pb_) {
        pb_.seShare = cfg.standardExchangeVaultShare;
        // rateTarget == address(0): abstract 1:1 share units (STANDARD/STANDARD) for nested DETFs
        // whose SE burn path cannot be quoted by the standard exchange rate provider.
        if (address(cfg.rateTarget) != address(0)) {
            pb_.rateProvider = RATE_PROVIDER_PKG.deployRateProvider(
                IStandardExchange(address(cfg.standardExchangeVault)), pb_.seShare, cfg.rateTarget
            );
        }
        (pb_.reservePool, pb_.detfIndex, pb_.shareIndex) =
            _createWeightedReservePool(pb_.seShare, pb_.rateProvider, cfg.detfWeight, cfg.vaultShareWeight);
    }

    function _createWeightedReservePool(
        IERC20 seShare_,
        IRateProvider rateProvider_,
        uint256 detfWeight_,
        uint256 vaultShareWeight_
    ) private returns (address pool_, uint256 detfIndex_, uint256 shareIndex_) {
        (TokenConfig[] memory tokens_, uint256[] memory weights_, uint256 dIdx_, uint256 sIdx_) =
            _buildTokenConfigs(seShare_, rateProvider_, detfWeight_, vaultShareWeight_);
        detfIndex_ = dIdx_;
        shareIndex_ = sIdx_;
        pool_ = _factoryCreatePool(tokens_, weights_, address(seShare_));
    }

    function _buildTokenConfigs(
        IERC20 seShare_,
        IRateProvider rateProvider_,
        uint256 detfWeight_,
        uint256 vaultShareWeight_
    )
        private
        view
        returns (TokenConfig[] memory tokens_, uint256[] memory weights_, uint256 detfIndex_, uint256 shareIndex_)
    {
        tokens_ = new TokenConfig[](2);
        weights_ = new uint256[](2);
        bool withRate_ = address(rateProvider_) != address(0);
        TokenType shareType_ = withRate_ ? TokenType.WITH_RATE : TokenType.STANDARD;
        IRateProvider shareRp_ = withRate_ ? rateProvider_ : IRateProvider(address(0));

        if (address(this) < address(seShare_)) {
            detfIndex_ = 0;
            shareIndex_ = 1;
            tokens_[0] = TokenConfig(IERC20(address(this)), TokenType.STANDARD, IRateProvider(address(0)), false);
            tokens_[1] = TokenConfig(seShare_, shareType_, shareRp_, false);
            weights_[0] = detfWeight_;
            weights_[1] = vaultShareWeight_;
        } else {
            detfIndex_ = 1;
            shareIndex_ = 0;
            tokens_[0] = TokenConfig(seShare_, shareType_, shareRp_, false);
            tokens_[1] = TokenConfig(IERC20(address(this)), TokenType.STANDARD, IRateProvider(address(0)), false);
            weights_[0] = vaultShareWeight_;
            weights_[1] = detfWeight_;
        }
    }

    function _factoryCreatePool(TokenConfig[] memory tokens_, uint256[] memory weights_, address share_)
        private
        returns (address pool_)
    {
        PoolRoleAccounts memory roles_;
        // WeightedPool min swap fee is 0.001e16; use 0.3% like dual-liquidity reserves.
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
            keccak256(abi.encode(address(this), share_, block.timestamp))
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

    function _tryInitDetfNft(IDETFNFTVault bondVault_) private returns (uint256 detfNftId_) {
        address feeTo_ = address(FEE_ORACLE.feeTo());
        address creator_ = _deployConfig().creator;
        detfNftId_ = bondVault_.initializeReservedBondNfts(feeTo_, creator_);
    }

    function _initBasicVaultTokens(address seShare_, address reservePool_, address staking_) private {
        address[] memory host_ = IBasicVault(address(_deployConfig().standardExchangeVault)).vaultTokens();
        address[] memory tokens_ = new address[](host_.length + 4);
        tokens_[0] = address(this);
        tokens_[1] = seShare_;
        tokens_[2] = reservePool_;
        tokens_[3] = staking_;
        uint256 count_ = 4;
        for (uint256 i_; i_ < host_.length; ++i_) {
            bool seen_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == host_[i_]) seen_ = true;
            if (!seen_) tokens_[count_++] = host_[i_];
        }
        assembly { mstore(tokens_, count_) }
        MultiAssetBasicVaultRepo._initialize(tokens_);
    }

    function _initFamilyRepo(
        DeployConfig storage cfg,
        PoolBuild memory pb_,
        IDETFNFTVault bondVault_,
        IRebasingClaimToken claimToken_
    ) private {
        SingleStandardExchangeDETFRepo._initialize(
            cfg.standardExchangeVault,
            pb_.seShare,
            cfg.rateTarget,
            pb_.rateProvider,
            pb_.reservePool,
            pb_.detfIndex,
            pb_.shareIndex,
            cfg.detfWeight,
            cfg.vaultShareWeight,
            _thresholdAndFeeInit(cfg, bondVault_)
        );
        SingleStandardExchangeDETFRepo._setRebasingClaimToken(claimToken_);
        _emitThresholdsSet(cfg);
    }

    function _thresholdAndFeeInit(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_
    ) private view returns (SingleStandardExchangeDETFRepo.ThresholdAndFeeInit memory tf_) {
        tf_.mintThreshold = cfg.mintThreshold;
        tf_.burnThreshold = cfg.burnThreshold;
        tf_.feeOracle = FEE_ORACLE;
        tf_.bondNftVault = bondVault_;
        tf_.expansionClosureRatePerSecond = cfg.expansionClosureRatePerSecond;
    }

    function _emitThresholdsSet(DeployConfig storage cfg) private {
        emit ISingleStandardExchangeDETFInfo.ThresholdsSet(
            cfg.mintThreshold, cfg.burnThreshold
        );
    }
}
