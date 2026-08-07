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
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg,
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";

/// @title UniswapV4StandardExchangeWeightedDETDFPkg
/// @notice Immutable/unowned DETF package: Weighted SE Buffer Hook reserve (n∈[2,8], ≥1 SE).
contract UniswapV4StandardExchangeWeightedDETDFPkg is IUniswapV4StandardExchangeWeightedDETDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.weighted.pkg.deploy-config")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 private constant ONE_WAD = 1e18;
    uint256 private constant MIN_WEIGHT = 0.01e18;
    uint8 private constant MAX_M = 7;
    uint8 private constant MAX_N = 8;

    struct DeployConfig {
        uint8 n;
        uint8 m;
        uint8 detfBindingIndex;
        IERC20[MAX_M] pairTokens;
        IStandardExchangeProxy[MAX_M] standardExchanges;
        IERC20[MAX_M] vaultShares;
        address[MAX_M] rateProviders;
        uint256[MAX_M] creationPairPerDetfWad;
        uint8[MAX_M] pairBindingIndex;
        uint256[MAX_N] weightsBinding;
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
    IUniswapV4StandardExchangeWeightedBufferHookPackage immutable HOOK_PKG;
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
        return type(UniswapV4StandardExchangeWeightedDETDFPkg).name;
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
        interfaces_[7] = type(IUniswapV4StandardExchangeWeightedDETF).interfaceId;
        interfaces_[8] = bytes4(keccak256("UniswapV4StandardExchangeWeightedDETF"));
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
        uint256 m_ = args.pairTokens.length;
        if (m_ == 0 || m_ > MAX_M) revert InvalidN();
        uint8 n_ = uint8(m_ + 1);
        if (n_ < 2 || n_ > MAX_N) revert InvalidN();

        if (
            args.standardExchanges.length != m_ || args.vaultShares.length != m_
                || args.rateProviders.length != m_ || args.creationPairPerDetfWad.length != m_
                || args.pairWeights.length != m_
        ) {
            revert ArrayLengthMismatch();
        }

        // ≥1 SE among external legs
        uint256 seCount_;
        for (uint256 i; i < m_; ++i) {
            if (address(args.pairTokens[i]) == address(0)) revert ZeroAddress();
            if (args.creationPairPerDetfWad[i] == 0) revert InvalidCreationRate();
            if (address(args.standardExchanges[i]) != address(0)) {
                ++seCount_;
                for (uint256 j = i + 1; j < m_; ++j) {
                    if (
                        address(args.standardExchanges[j]) != address(0)
                            && address(args.standardExchanges[i]) == address(args.standardExchanges[j])
                    ) {
                        revert SameStandardExchange();
                    }
                }
            } else if (args.rateProviders[i] != address(0)) {
                revert RateProviderWithoutSE();
            }
            for (uint256 j = i + 1; j < m_; ++j) {
                if (address(args.pairTokens[i]) == address(args.pairTokens[j])) revert SamePairTokens();
            }
        }
        if (seCount_ == 0) revert AllExternalBareForbidden();

        // Weights: detfWeight + pairWeights product-order; sum 1e18, each ≥ 1%
        if (args.detfWeight < MIN_WEIGHT) revert InvalidWeights();
        uint256 wSum_ = args.detfWeight;
        for (uint256 i; i < m_; ++i) {
            if (args.pairWeights[i] < MIN_WEIGHT) revert InvalidWeights();
            wSum_ += args.pairWeights[i];
        }
        if (wSum_ != ONE_WAD) revert InvalidWeights();

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](m_);
        for (uint256 i; i < m_; ++i) {
            contents_[i] = address(args.pairTokens[i]);
        }
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
        cfg.n = n_;
        cfg.m = uint8(m_);
        // Binding indices resolved in postDeploy after address(this) known.
        cfg.detfBindingIndex = 0;
        for (uint256 i; i < m_; ++i) {
            cfg.pairTokens[i] = args.pairTokens[i];
            cfg.standardExchanges[i] = args.standardExchanges[i];
            bool seSet_ = address(args.standardExchanges[i]) != address(0);
            cfg.vaultShares[i] = seSet_
                ? (
                    address(args.vaultShares[i]) == address(0)
                        ? IERC20(address(args.standardExchanges[i]))
                        : args.vaultShares[i]
                )
                : IERC20(address(0));
            cfg.rateProviders[i] = args.rateProviders[i];
            cfg.creationPairPerDetfWad[i] = args.creationPairPerDetfWad[i];
            // Temporarily store product-order pair weights in weightsBinding[1..m] slots;
            // remapped to binding order in _resolveBinding after detf index known.
            // weightsBinding[0] holds detfWeight until remap.
        }
        // Stash: weightsBinding[0] = detfWeight; weightsBinding[1+i] = pairWeights[i] (product).
        cfg.weightsBinding[0] = args.detfWeight;
        for (uint256 i; i < m_; ++i) {
            cfg.weightsBinding[i + 1] = args.pairWeights[i];
        }
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.thresholdMode = args.thresholdMode;
        cfg.expansionEpochLength = epoch_;
        cfg.expansionClosureRatePerYearWad = rate_;
        cfg.expansionMaxCatchUpEpochs = maxCatch_;
        cfg.hookMineNonce = args.hookMineNonce;
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
        _resolveBinding(cfg);
        _validateSes(cfg);
        address hook_ = _deployReserveHook(cfg);
        IDETFNFTVault bondVault_ = _deployBondNftVault(hook_);
        uint256 detfNftId_ = _tryInitDetfNft(bondVault_);
        uint256 feeRecipientNftId_ = _tryInitFeeRecipientNft(bondVault_);
        // Claim rate token = first pair (product order); no whole-DETF rateAsset surface.
        IRebasingClaimToken claimToken_ =
            _deployRebasingClaimToken(cfg.pairTokens[0], bondVault_, detfNftId_);
        _initVaultTokens(hook_, cfg);
        _initRepo(cfg, hook_, bondVault_, detfNftId_, feeRecipientNftId_, claimToken_);
    }

    /// @dev Sort DETF + pairTokens by address ascending; store detfBindingIndex + pairBindingIndex;
    ///      remap stashed product weights into binding-order weightsBinding.
    function _resolveBinding(DeployConfig storage cfg) private {
        uint8 m_ = cfg.m;
        uint8 n_ = cfg.n;
        // Stash product weights before overwrite.
        uint256 detfW_ = cfg.weightsBinding[0];
        uint256[] memory pairW_ = new uint256[](m_);
        for (uint8 i; i < m_; ++i) {
            pairW_[i] = cfg.weightsBinding[i + 1];
        }

        address[] memory tokens_ = new address[](n_);
        tokens_[0] = address(this);
        for (uint8 i; i < m_; ++i) {
            tokens_[i + 1] = address(cfg.pairTokens[i]);
        }
        // Insertion sort by address.
        for (uint8 i = 1; i < n_; ++i) {
            address key_ = tokens_[i];
            uint8 j = i;
            while (j > 0 && tokens_[j - 1] > key_) {
                tokens_[j] = tokens_[j - 1];
                unchecked {
                    --j;
                }
            }
            tokens_[j] = key_;
        }
        // Map DETF + pairs to binding indices.
        for (uint8 b; b < n_; ++b) {
            if (tokens_[b] == address(this)) {
                cfg.detfBindingIndex = b;
            }
            cfg.weightsBinding[b] = 0; // clear before remap
        }
        for (uint8 i; i < m_; ++i) {
            address p_ = address(cfg.pairTokens[i]);
            for (uint8 b; b < n_; ++b) {
                if (tokens_[b] == p_) {
                    cfg.pairBindingIndex[i] = b;
                    break;
                }
            }
        }
        // Remap weights to binding order.
        cfg.weightsBinding[cfg.detfBindingIndex] = detfW_;
        for (uint8 i; i < m_; ++i) {
            cfg.weightsBinding[cfg.pairBindingIndex[i]] = pairW_[i];
        }
    }

    function _validateSes(DeployConfig storage cfg) private view {
        for (uint8 i; i < cfg.m; ++i) {
            if (address(cfg.standardExchanges[i]) != address(0)) {
                _validateSePair(address(cfg.standardExchanges[i]), address(cfg.pairTokens[i]));
            }
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
        uint8 n_ = cfg.n;
        uint8 m_ = cfg.m;
        address[] memory tokens_ = new address[](n_);
        address[] memory ses_ = new address[](n_);
        address[] memory rps_ = new address[](n_);
        uint256[] memory weights_ = new uint256[](n_);

        tokens_[cfg.detfBindingIndex] = address(this);
        // DETF always raw (no SE).
        for (uint8 i; i < m_; ++i) {
            uint8 b_ = cfg.pairBindingIndex[i];
            tokens_[b_] = address(cfg.pairTokens[i]);
            ses_[b_] = address(cfg.standardExchanges[i]);
            rps_[b_] = cfg.rateProviders[i];
        }
        for (uint8 b; b < n_; ++b) {
            weights_[b] = cfg.weightsBinding[b];
        }

        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: address(POOL_MANAGER),
                feeOracle: address(FEE_ORACLE),
                n: n_,
                tokens: tokens_,
                weights: weights_,
                standardExchanges: ses_,
                rateProviders: rps_
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
        IERC20 rateToken_,
        IDETFNFTVault bondVault_,
        uint256 detfNftId_
    ) private returns (IRebasingClaimToken claimToken_) {
        address detf_ = address(this);
        claimToken_ = IRebasingClaimToken(
            REBASING_CLAIM_TOKEN_PKG.deployToken(IDetf(detf_), bondVault_, rateToken_, detfNftId_, detf_)
        );
    }

    function _initVaultTokens(address hook_, DeployConfig storage cfg) private {
        // vault tokens: DETF + pairs + hook LP
        address[] memory vaultTokens_ = new address[](uint256(cfg.m) + 2);
        vaultTokens_[0] = address(this);
        for (uint8 i; i < cfg.m; ++i) {
            vaultTokens_[i + 1] = address(cfg.pairTokens[i]);
        }
        vaultTokens_[cfg.m + 1] = hook_;
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
        IERC20[] memory pairs_ = new IERC20[](cfg.m);
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](cfg.m);
        IERC20[] memory shares_ = new IERC20[](cfg.m);
        address[] memory rps_ = new address[](cfg.m);
        uint256[] memory rates_ = new uint256[](cfg.m);
        uint8[] memory pairBind_ = new uint8[](cfg.m);
        uint256[] memory weights_ = new uint256[](cfg.n);
        for (uint8 i; i < cfg.m; ++i) {
            pairs_[i] = cfg.pairTokens[i];
            ses_[i] = cfg.standardExchanges[i];
            shares_[i] = cfg.vaultShares[i];
            rps_[i] = cfg.rateProviders[i];
            rates_[i] = cfg.creationPairPerDetfWad[i];
            pairBind_[i] = cfg.pairBindingIndex[i];
        }
        for (uint8 b; b < cfg.n; ++b) {
            weights_[b] = cfg.weightsBinding[b];
        }

        Repo._initializeCore(
            Repo.CoreInit({
                n: cfg.n,
                m: cfg.m,
                detfBindingIndex: cfg.detfBindingIndex,
                pairTokens: pairs_,
                standardExchanges: ses_,
                vaultShares: shares_,
                rateProviders: rps_,
                creationPairPerDetfWad: rates_,
                pairBindingIndex: pairBind_,
                weights: weights_,
                reserveHook: hook_,
                poolManager: POOL_MANAGER,
                feeOracle: FEE_ORACLE,
                bondNftVault: bondVault_,
                rebasingClaimToken: claimToken_,
                detfNftId: detfNftId_,
                feeRecipientNftId: feeRecipientNftId_
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
        emit IUniswapV4StandardExchangeWeightedDETF.ThresholdModeSet(
            cfg.thresholdMode, cfg.mintThreshold, cfg.burnThreshold
        );
    }
}
