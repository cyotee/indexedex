// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg,
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";

/// @title UniswapV4StandardExchangeOrbitalDETDFPkg
/// @notice Immutable/unowned DETF package: Orbital SE Buffer Hook reserve (1–2 SEs, free DETF binding).
contract UniswapV4StandardExchangeOrbitalDETDFPkg is IUniswapV4StandardExchangeOrbitalDETDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.orbital.pkg.deploy-config")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @dev Plumbing-only sqrt price (1:1). First bond sets economic creation rates.
    uint160 private constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    struct DeployConfig {
        IERC20 pairToken0;
        IERC20 pairToken1;
        IStandardExchangeProxy standardExchange0;
        IStandardExchangeProxy standardExchange1;
        IERC20 vaultShare0;
        IERC20 vaultShare1;
        address rateProvider0;
        address rateProvider1;
        IERC20 rateAsset;
        uint8 detfBindingIndex;
        uint8 pair0BindingIndex;
        uint8 pair1BindingIndex;
        uint256 creationPair0PerDetfWad;
        uint256 creationPair1PerDetfWad;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionEpochLength;
        uint256 expansionClosureRatePerYearWad;
        uint256 expansionMaxCatchUpEpochs;
        uint256 hookMineNonce;
    }

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable EXCHANGE_IN_FACET;
    IFacet immutable INFO_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPoolManager immutable POOL_MANAGER;
    IUniswapV4StandardExchangeOrbitalBufferHookPackage immutable HOOK_PKG;
    IDetfSelfNftInventoryDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;

    constructor(PkgInit memory pkgInit) {
        if (
            address(pkgInit.erc20Facet) == address(0) || address(pkgInit.exchangeInFacet) == address(0)
                || address(pkgInit.infoFacet) == address(0) || address(pkgInit.feeOracle) == address(0)
                || address(pkgInit.vaultRegistryDeployment) == address(0)
                || address(pkgInit.poolManager) == address(0) || address(pkgInit.hookPkg) == address(0)
                || address(pkgInit.bondNftVaultPkg) == address(0)
                || address(pkgInit.rebasingClaimTokenPkg) == address(0)
        ) {
            revert ZeroAddress();
        }
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        INFO_FACET = pkgInit.infoFacet;
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        POOL_MANAGER = pkgInit.poolManager;
        HOOK_PKG = pkgInit.hookPkg;
        BOND_NFT_VAULT_PKG = pkgInit.bondNftVaultPkg;
        REBASING_CLAIM_TOKEN_PKG = pkgInit.rebasingClaimTokenPkg;
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
        return type(UniswapV4StandardExchangeOrbitalDETDFPkg).name;
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
        facetAddresses_[6] = address(INFO_FACET);
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
        interfaces_[7] = type(IUniswapV4StandardExchangeOrbitalDETF).interfaceId;
        interfaces_[8] = bytes4(keccak256("UniswapV4StandardExchangeOrbitalDETF"));
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
            address(MULTI_ASSET_BASIC_VAULT_FACET),
            IDiamond.FacetCutAction.Add,
            MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        );
        facetCuts_[4] = IDiamond.FacetCut(
            address(MULTI_ASSET_STANDARD_VAULT_FACET),
            IDiamond.FacetCutAction.Add,
            MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        );
        facetCuts_[5] =
            IDiamond.FacetCut(address(EXCHANGE_IN_FACET), IDiamond.FacetCutAction.Add, EXCHANGE_IN_FACET.facetFuncs());
        facetCuts_[6] = IDiamond.FacetCut(address(INFO_FACET), IDiamond.FacetCutAction.Add, INFO_FACET.facetFuncs());
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
        if (args.creationPair0PerDetfWad == 0 || args.creationPair1PerDetfWad == 0) {
            revert InvalidCreationRate();
        }
        if (address(args.pairToken0) == address(0) || address(args.pairToken1) == address(0)) {
            revert ZeroAddress();
        }
        if (address(args.pairToken0) == address(args.pairToken1)) revert SamePairTokens();
        if (args.detfBindingIndex > 2) revert InvalidDetfBindingIndex();

        // ≥1 SE among external legs
        bool se0Set_ = address(args.standardExchange0) != address(0);
        bool se1Set_ = address(args.standardExchange1) != address(0);
        if (!se0Set_ && !se1Set_) revert BothBareForbidden();
        if (se0Set_ && se1Set_ && address(args.standardExchange0) == address(args.standardExchange1)) {
            revert SameStandardExchange();
        }
        if (args.rateProvider0 != address(0) && !se0Set_) revert RateProviderWithoutSE();
        if (args.rateProvider1 != address(0) && !se1Set_) revert RateProviderWithoutSE();

        IERC20 rateAsset_ = address(args.rateAsset) == address(0) ? args.pairToken0 : args.rateAsset;
        if (address(rateAsset_) != address(args.pairToken0) && address(rateAsset_) != address(args.pairToken1)) {
            revert InvalidRateAsset();
        }

        // Resolve binding indices: DETF at detfBindingIndex; pair0/pair1 fill remaining in order.
        (uint8 p0Idx_, uint8 p1Idx_) = _resolvePairBinding(args.detfBindingIndex);

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](2);
        contents_[0] = address(args.pairToken0);
        contents_[1] = address(args.pairToken1);
        StandardVaultRepo._initialize(
            FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash()
        );

        DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode);
        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        (uint256 epoch_, uint256 rate_, uint256 maxCatch_) = DETFEpochNaturalExpansionLib.resolveExpansionParams(
            args.expansionEpochLength, args.expansionClosureRatePerYearWad, args.expansionMaxCatchUpEpochs
        );

        DeployConfig storage cfg = _deployConfig();
        cfg.pairToken0 = args.pairToken0;
        cfg.pairToken1 = args.pairToken1;
        cfg.standardExchange0 = args.standardExchange0;
        cfg.standardExchange1 = args.standardExchange1;
        cfg.vaultShare0 = se0Set_
            ? (address(args.vaultShare0) == address(0) ? IERC20(address(args.standardExchange0)) : args.vaultShare0)
            : IERC20(address(0));
        cfg.vaultShare1 = se1Set_
            ? (address(args.vaultShare1) == address(0) ? IERC20(address(args.standardExchange1)) : args.vaultShare1)
            : IERC20(address(0));
        cfg.rateProvider0 = args.rateProvider0;
        cfg.rateProvider1 = args.rateProvider1;
        cfg.rateAsset = rateAsset_;
        cfg.detfBindingIndex = args.detfBindingIndex;
        cfg.pair0BindingIndex = p0Idx_;
        cfg.pair1BindingIndex = p1Idx_;
        cfg.creationPair0PerDetfWad = args.creationPair0PerDetfWad;
        cfg.creationPair1PerDetfWad = args.creationPair1PerDetfWad;
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.thresholdMode = args.thresholdMode;
        cfg.expansionEpochLength = epoch_;
        cfg.expansionClosureRatePerYearWad = rate_;
        cfg.expansionMaxCatchUpEpochs = maxCatch_;
        cfg.hookMineNonce = args.hookMineNonce;
    }

    function _resolvePairBinding(uint8 detfIdx_)
        private
        pure
        returns (uint8 pair0Idx_, uint8 pair1Idx_)
    {
        // Remaining indices in ascending order: first → pair0, second → pair1.
        uint8[2] memory rem;
        uint256 k;
        for (uint8 i; i < 3; ++i) {
            if (i != detfIdx_) rem[k++] = i;
        }
        pair0Idx_ = rem[0];
        pair1Idx_ = rem[1];
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
        _validateSes(cfg);
        address hook_ = _deployReserveHook(cfg);
        IDETFNFTVault bondVault_ = _deployBondNftVault(hook_);
        uint256 detfNftId_ = _tryInitDetfNft(bondVault_);
        uint256 feeRecipientNftId_ = _tryInitFeeRecipientNft(bondVault_);
        IRebasingClaimToken claimToken_ = _deployRebasingClaimToken(cfg, bondVault_, detfNftId_);
        _initVaultTokens(hook_, cfg);
        _initRepo(cfg, hook_, bondVault_, detfNftId_, feeRecipientNftId_, claimToken_);
    }

    function _validateSes(DeployConfig storage cfg) private view {
        if (address(cfg.standardExchange0) != address(0)) {
            _validateSePair(address(cfg.standardExchange0), address(cfg.pairToken0));
        }
        if (address(cfg.standardExchange1) != address(0)) {
            _validateSePair(address(cfg.standardExchange1), address(cfg.pairToken1));
        }
    }

    function _validateSePair(address se_, address pair_) private view {
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        bool found_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == pair_) found_ = true;
            if (tokens_[i] == address(this)) revert DetfInSeTokens();
        }
        if (!found_) revert PairTokenNotInSeTokens();
    }

    function _deployReserveHook(DeployConfig storage cfg) private returns (address hook_) {
        // Binding-order tokens for hook: index 0/1/2 with DETF at detfBindingIndex.
        address[3] memory tokens_;
        address[3] memory ses_;
        address[3] memory rps_;
        tokens_[cfg.detfBindingIndex] = address(this);
        tokens_[cfg.pair0BindingIndex] = address(cfg.pairToken0);
        tokens_[cfg.pair1BindingIndex] = address(cfg.pairToken1);
        ses_[cfg.pair0BindingIndex] = address(cfg.standardExchange0);
        ses_[cfg.pair1BindingIndex] = address(cfg.standardExchange1);
        rps_[cfg.pair0BindingIndex] = cfg.rateProvider0;
        rps_[cfg.pair1BindingIndex] = cfg.rateProvider1;
        // DETF is always raw (no SE).

        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
                poolManager: address(POOL_MANAGER),
                feeOracle: address(FEE_ORACLE),
                token0: tokens_[0],
                token1: tokens_[1],
                token2: tokens_[2],
                se0: ses_[0],
                se1: ses_[1],
                se2: ses_[2],
                rp0: rps_[0],
                rp1: rps_[1],
                rp2: rps_[2],
                tickSpacing: 60,
                sqrtPriceX96: SQRT_PRICE_1_1
            });

        if (cfg.hookMineNonce == 0) {
            hook_ = HOOK_PKG.deployVaultAutoMine(hArgs);
        } else {
            hook_ = HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce);
        }
    }

    function _deployBondNftVault(address reserveHook_) private returns (IDETFNFTVault bondVault_) {
        address detf_ = address(this);
        bondVault_ = IDETFNFTVault(
            BOND_NFT_VAULT_PKG.deployVault(
                string(abi.encodePacked(ERC20Repo._name(), " Bond")),
                string(abi.encodePacked(ERC20Repo._symbol(), "-BOND")),
                IDetf(detf_),
                IERC20(reserveHook_),
                IERC20(detf_),
                0,
                detf_
            )
        );
    }

    function _tryInitDetfNft(IDETFNFTVault bondVault_) private returns (uint256 detfNftId_) {
        try bondVault_.initializeDETFNFT() returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            detfNftId_ = 0;
        }
    }

    function _tryInitFeeRecipientNft(IDETFNFTVault bondVault_) private returns (uint256 feeNftId_) {
        address feeTo_ = address(FEE_ORACLE.feeTo());
        if (feeTo_ == address(0)) return 0;
        try bondVault_.createPosition(1, _minLockOrDefault(), feeTo_) returns (uint256 id_) {
            feeNftId_ = id_;
        } catch {
            feeNftId_ = 0;
        }
    }

    function _minLockOrDefault() private view returns (uint256 lock_) {
        try FEE_ORACLE.bondTermsOfVault(address(this)) returns (BondTerms memory terms_) {
            lock_ = terms_.minLockDuration == 0 ? 1 : terms_.minLockDuration;
        } catch {
            lock_ = 1;
        }
    }

    function _deployRebasingClaimToken(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_,
        uint256 detfNftId_
    ) private returns (IRebasingClaimToken claimToken_) {
        address detf_ = address(this);
        // Rate token for claim = rateAsset (pair).
        claimToken_ = IRebasingClaimToken(
            REBASING_CLAIM_TOKEN_PKG.deployToken(
                IDetf(detf_), bondVault_, cfg.rateAsset, detfNftId_, detf_
            )
        );
    }

    function _initVaultTokens(address hook_, DeployConfig storage cfg) private {
        address[] memory vaultTokens_ = new address[](4);
        vaultTokens_[0] = address(this);
        vaultTokens_[1] = address(cfg.pairToken0);
        vaultTokens_[2] = address(cfg.pairToken1);
        vaultTokens_[3] = hook_;
        MultiAssetBasicVaultRepo._initialize(vaultTokens_);
    }

    function _initRepo(
        DeployConfig storage cfg,
        address hook_,
        IDETFNFTVault bondVault_,
        uint256 detfNftId_,
        uint256 feeRecipientNftId_,
        IRebasingClaimToken claimToken_
    ) private {
        Repo._initializeCore(
            Repo.CoreInit({
                pairToken0: cfg.pairToken0,
                pairToken1: cfg.pairToken1,
                standardExchange0: cfg.standardExchange0,
                standardExchange1: cfg.standardExchange1,
                vaultShare0: cfg.vaultShare0,
                vaultShare1: cfg.vaultShare1,
                rateProvider0: cfg.rateProvider0,
                rateProvider1: cfg.rateProvider1,
                rateAsset: cfg.rateAsset,
                detfBindingIndex: cfg.detfBindingIndex,
                pair0BindingIndex: cfg.pair0BindingIndex,
                pair1BindingIndex: cfg.pair1BindingIndex,
                reserveHook: hook_,
                poolManager: POOL_MANAGER,
                feeOracle: FEE_ORACLE,
                bondNftVault: bondVault_,
                rebasingClaimToken: claimToken_,
                detfNftId: detfNftId_,
                feeRecipientNftId: feeRecipientNftId_,
                creationPair0PerDetfWad: cfg.creationPair0PerDetfWad,
                creationPair1PerDetfWad: cfg.creationPair1PerDetfWad
            })
        );
        Repo._initializePolicy(
            Repo.PolicyInit({
                mintThreshold: cfg.mintThreshold,
                burnThreshold: cfg.burnThreshold,
                thresholdMode: cfg.thresholdMode,
                expansionEpochLength: cfg.expansionEpochLength,
                expansionClosureRatePerYearWad: cfg.expansionClosureRatePerYearWad,
                expansionMaxCatchUpEpochs: cfg.expansionMaxCatchUpEpochs
            })
        );
        emit IUniswapV4StandardExchangeOrbitalDETF.ThresholdModeSet(
            cfg.thresholdMode, cfg.mintThreshold, cfg.burnThreshold
        );
    }
}
