// SPDX-License-Identifier: BUSL-1.1
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
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
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
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol";
import {
    IMixedBufferMultiVaultStablePoolPkg
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolStandardVaultPkg.sol";
import {
    IMixedBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";

/// @title IMixedBufferMultiVaultStableDetfDFPkg
interface IMixedBufferMultiVaultStableDetfDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        IMixedBufferMultiVaultStablePoolPkg mixedBufferPoolPkg;
        IDetfSelfNftInventoryDFPkg bondNftVaultPkg;
        IRebasingClaimTokenDFPkg rebasingClaimTokenPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @dev Per-instance args. `standardExchangeVaults.length` = N in [1,3].
    /// @dev `vaultShareRateProviders.length == N`; address(0) => STANDARD share leg.
    /// @dev No buffer RP, no DETF RP, no auto-deployed default share RPs.
    /// @dev Trailing `thresholdMode`: 0 = Policy (default); 1 = Open. Never infer Open from zeros.
    struct PkgArgs {
        string name;
        string symbol;
        IERC20 bufferToken;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] vaultShareRateProviders;
        uint256 amplificationParameter;
        uint256 mintThreshold; // 0 → 1.05e18
        uint256 burnThreshold; // 0 → 0.95e18
        ThresholdMode thresholdMode; // trailing; 0 = Policy
    }

    function deployVault(PkgArgs memory args) external returns (address vault);
}

/// @title MixedBufferMultiVaultStableDetfDFPkg
/// @notice Immutable/unowned DETF package: DETF unpaired + bufferToken + N SE vault shares in MixedBuffer stable reserve.
contract MixedBufferMultiVaultStableDetfDFPkg is IMixedBufferMultiVaultStableDetfDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT =
        keccak256("vault.detf.composed.stable.mixedBuffer.pkg.deploy-config");

    uint256 private constant _MAX_VAULTS = 3;
    uint256 private constant _MIN_VAULTS = 1;

    struct DeployConfig {
        uint8 vaultCount;
        IStandardExchange[3] vaults;
        IERC20[3] vaultShares;
        IRateProvider[3] vaultShareRateProviders;
        IERC20 bufferToken;
        uint256 amplificationParameter;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
    }

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable EXCHANGE_IN_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IBalancerV3StandardExchangeRouterProxy immutable BALANCER_V3_ROUTER;
    IVault immutable BALANCER_V3_VAULT;
    IMixedBufferMultiVaultStablePoolPkg immutable MIXED_BUFFER_POOL_PKG;
    IDetfSelfNftInventoryDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        BALANCER_V3_ROUTER = pkgInit.balancerV3Router;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        MIXED_BUFFER_POOL_PKG = pkgInit.mixedBufferPoolPkg;
        BOND_NFT_VAULT_PKG = pkgInit.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = pkgInit.rebasingClaimTokenPkg;
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
        return type(MixedBufferMultiVaultStableDetfDFPkg).name;
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
        facetAddresses_ = new address[](6);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(EXCHANGE_IN_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](9);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
        interfaces_[8] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
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
        _validateArgs(abi.decode(pkgArgs, (PkgArgs)));
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));
        _validateArgs(args);

        uint256 n_ = args.standardExchangeVaults.length;

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");
        BalancerV3StandardExchangeRouterAwareRepo._initialize(BALANCER_V3_ROUTER);
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        address[] memory contents_ = new address[](n_ + 2);
        for (uint256 i; i < n_; ++i) {
            contents_[i] = address(args.standardExchangeVaults[i]);
        }
        contents_[n_] = address(args.bufferToken);
        contents_[n_ + 1] = address(this);
        StandardVaultRepo._initialize(
            FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash()
        );

        DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode);
        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);

        DeployConfig storage cfg = _deployConfig();
        cfg.vaultCount = uint8(n_);
        cfg.bufferToken = args.bufferToken;
        cfg.amplificationParameter = args.amplificationParameter;
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.thresholdMode = args.thresholdMode;
        for (uint256 i; i < n_; ++i) {
            cfg.vaults[i] = args.standardExchangeVaults[i];
            // Vault diamond is the share ERC-20 for Standard Exchange vaults.
            cfg.vaultShares[i] = IERC20(address(args.standardExchangeVaults[i]));
            cfg.vaultShareRateProviders[i] = args.vaultShareRateProviders[i];
        }
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
        (address reservePool_, uint256 detfIndex_, uint256 bufferIndex_, uint256[] memory shareIndexes_) =
            _createMixedBufferReservePool(cfg);
        IDETFNFTVault bondVault_ = _deployBondNftVault(reservePool_);
        uint256 protocolNftId_ = _tryInitProtocolNft(bondVault_);
        IRebasingClaimToken claimToken_ = _deployRebasingClaimToken(cfg, bondVault_, protocolNftId_);
        _initBasicVaultTokens(cfg, reservePool_);
        _initFamilyRepo(cfg, reservePool_, detfIndex_, bufferIndex_, shareIndexes_, bondVault_, protocolNftId_, claimToken_);
    }

    function _validateArgs(PkgArgs memory args) internal pure {
        uint256 n_ = args.standardExchangeVaults.length;
        if (n_ < _MIN_VAULTS || n_ > _MAX_VAULTS) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidVaultCount(n_);
        }
        if (args.vaultShareRateProviders.length != n_) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidRateConfig(type(uint256).max);
        }
        if (address(args.bufferToken) == address(0)) {
            revert MixedBufferMultiVaultStableDetfRepo.ZeroBufferToken();
        }
        if (args.amplificationParameter < StableMath.MIN_AMP || args.amplificationParameter > StableMath.MAX_AMP) {
            revert MixedBufferMultiVaultStableDetfRepo.InvalidAmplification(args.amplificationParameter);
        }
        for (uint256 i; i < n_; ++i) {
            if (address(args.standardExchangeVaults[i]) == address(0)) {
                revert MixedBufferMultiVaultStableDetfRepo.InvalidVaultCount(n_);
            }
            for (uint256 j = i + 1; j < n_; ++j) {
                if (address(args.standardExchangeVaults[i]) == address(args.standardExchangeVaults[j])) {
                    revert MixedBufferMultiVaultStableDetfRepo.DuplicateVault(address(args.standardExchangeVaults[i]));
                }
            }
        }
    }

    function _createMixedBufferReservePool(DeployConfig storage cfg)
        private
        returns (address pool_, uint256 detfIndex_, uint256 bufferIndex_, uint256[] memory shareIndexes_)
    {
        IMixedBufferMultiVaultStablePoolPkg.PkgArgs memory poolArgs;
        poolArgs.unpairedCount = 1;
        poolArgs.unpairedTokens = new IERC20[](1);
        poolArgs.unpairedTokens[0] = IERC20(address(this));
        poolArgs.unpairedRateProviders = new IRateProvider[](1);
        poolArgs.unpairedRateProviders[0] = IRateProvider(address(0)); // DETF never WITH_RATE
        poolArgs.bufferToken = cfg.bufferToken;
        poolArgs.vaultCount = cfg.vaultCount;
        poolArgs.standardExchangeVaults = new IStandardExchange[](cfg.vaultCount);
        poolArgs.vaultShareRateProviders = new IRateProvider[](cfg.vaultCount);
        for (uint256 i; i < cfg.vaultCount; ++i) {
            poolArgs.standardExchangeVaults[i] = cfg.vaults[i];
            poolArgs.vaultShareRateProviders[i] = cfg.vaultShareRateProviders[i];
        }
        poolArgs.amplificationParameter = cfg.amplificationParameter;

        pool_ = MIXED_BUFFER_POOL_PKG.deployPool(poolArgs);

        IMixedBufferMultiVaultStablePool poolView_ = IMixedBufferMultiVaultStablePool(pool_);
        detfIndex_ = poolView_.unpairedIndex(0);
        bufferIndex_ = poolView_.bufferIndex();
        shareIndexes_ = new uint256[](cfg.vaultCount);
        for (uint256 i; i < cfg.vaultCount; ++i) {
            shareIndexes_[i] = poolView_.shareIndex(i);
        }
    }

    function _deployBondNftVault(address reservePool_) private returns (IDETFNFTVault bondVault_) {
        address detf_ = address(this);
        bondVault_ = IDETFNFTVault(
            BOND_NFT_VAULT_PKG.deployVault(
                string(abi.encodePacked(ERC20Repo._name(), " Bond")),
                string(abi.encodePacked(ERC20Repo._symbol(), "-BOND")),
                IProtocolDETF(detf_),
                IERC20(reservePool_),
                IERC20(detf_),
                0,
                detf_
            )
        );
    }

    function _tryInitProtocolNft(IDETFNFTVault bondVault_) private returns (uint256 protocolNftId_) {
        try bondVault_.initializeDETFNFT() returns (uint256 id_) {
            protocolNftId_ = id_;
        } catch {
            protocolNftId_ = 0;
        }
    }

    function _deployRebasingClaimToken(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_,
        uint256 protocolNftId_
    ) private returns (IRebasingClaimToken claimToken_) {
        // Claim rateAsset / payout boundary = bufferToken (family rateAsset).
        address detf_ = address(this);
        claimToken_ = IRebasingClaimToken(
            REBASING_CLAIM_TOKEN_PKG.deployToken(
                IProtocolDETF(detf_), bondVault_, cfg.bufferToken, protocolNftId_, detf_
            )
        );
    }

    function _initBasicVaultTokens(DeployConfig storage cfg, address reservePool_) private {
        // DETF + buffer + N vault shares + reserve BPT
        address[] memory vaultTokens_ = new address[](uint256(cfg.vaultCount) + 3);
        vaultTokens_[0] = address(this);
        vaultTokens_[1] = address(cfg.bufferToken);
        for (uint256 i; i < cfg.vaultCount; ++i) {
            vaultTokens_[i + 2] = address(cfg.vaultShares[i]);
        }
        vaultTokens_[cfg.vaultCount + 2] = reservePool_;
        MultiAssetBasicVaultRepo._initialize(vaultTokens_);
    }

    function _initFamilyRepo(
        DeployConfig storage cfg,
        address reservePool_,
        uint256 detfIndex_,
        uint256 bufferIndex_,
        uint256[] memory shareIndexes_,
        IDETFNFTVault bondVault_,
        uint256 protocolNftId_,
        IRebasingClaimToken claimToken_
    ) private {
        MixedBufferMultiVaultStableDetfRepo.InitParams memory p;
        p.vaultCount = cfg.vaultCount;
        p.bufferToken = cfg.bufferToken;
        p.bufferIndex = bufferIndex_;
        p.detfIndex = detfIndex_;
        p.shareIndexes = shareIndexes_;
        p.reservePool = reservePool_;
        p.amplificationParameter = cfg.amplificationParameter;
        p.mintThreshold = cfg.mintThreshold;
        p.burnThreshold = cfg.burnThreshold;
        p.thresholdMode = cfg.thresholdMode;
        p.feeOracle = FEE_ORACLE;
        p.bondNftVault = bondVault_;
        p.protocolNftId = protocolNftId_;
        p.rebasingClaimToken = claimToken_;

        uint256 n_ = cfg.vaultCount;
        p.vaults = new IStandardExchange[](n_);
        p.shares = new IERC20[](n_);
        p.vaultShareRateProviders = new IRateProvider[](n_);
        for (uint256 i; i < n_; ++i) {
            p.vaults[i] = cfg.vaults[i];
            p.shares[i] = cfg.vaultShares[i];
            p.vaultShareRateProviders[i] = cfg.vaultShareRateProviders[i];
        }
        MixedBufferMultiVaultStableDetfRepo._initialize(p);
        // Emit once after storage write with resolved thresholds (PRD §16.4).
        emit IMixedBufferMultiVaultStableDetfInfo.ThresholdModeSet(
            cfg.thresholdMode, cfg.mintThreshold, cfg.burnThreshold
        );
    }
}
