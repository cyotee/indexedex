// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
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
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg,
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @title UniswapV4SingleStandardExchangeDETDFPkg
/// @notice Immutable/unowned DETF package: one SE + Uni V4 Single SE Buffer CP reserve hook.
contract UniswapV4SingleStandardExchangeDETDFPkg is IUniswapV4SingleStandardExchangeDETDFPkg {
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT = keccak256(
        abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.cp.single.pkg.deploy-config")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @dev Plumbing-only sqrt price (1:1). First bond sets economic creation rate.
    uint160 private constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    struct DeployConfig {
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        uint256 creationPairPerDetfWad;
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
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IPoolManager immutable POOL_MANAGER;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage immutable HOOK_PKG;
    IDetfSelfNftInventoryDFPkg immutable BOND_NFT_VAULT_PKG;
    IRebasingClaimTokenDFPkg immutable REBASING_CLAIM_TOKEN_PKG;

    constructor(PkgInit memory pkgInit) {
        if (
            address(pkgInit.erc20Facet) == address(0) || address(pkgInit.exchangeInFacet) == address(0)
                || address(pkgInit.feeOracle) == address(0)
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
        return type(UniswapV4SingleStandardExchangeDETDFPkg).name;
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
        interfaces_[7] = type(IUniswapV4SingleStandardExchangeDETF).interfaceId;
        interfaces_[8] = bytes4(keccak256("UniswapV4SingleStandardExchangeDETF"));
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
        if (args.creationPairPerDetfWad == 0) revert InvalidCreationRate();
        if (address(args.standardExchangeVault) == address(0) || address(args.pairToken) == address(0)) {
            revert ZeroAddress();
        }

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](2);
        contents_[0] = address(args.standardExchangeVault);
        contents_[1] = address(args.pairToken);
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
        cfg.standardExchangeVault = args.standardExchangeVault;
        cfg.standardExchangeVaultShare = address(args.standardExchangeVaultShare) == address(0)
            ? IERC20(address(args.standardExchangeVault))
            : args.standardExchangeVaultShare;
        cfg.pairToken = args.pairToken;
        cfg.creationPairPerDetfWad = args.creationPairPerDetfWad;
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
        _validateSePair(cfg);
        address hook_ = _deployReserveHook(cfg);
        _initPool(hook_);
        IDETFNFTVault bondVault_ = _deployBondNftVault(hook_);
        uint256 detfNftId_ = _tryInitDetfNft(bondVault_);
        uint256 feeRecipientNftId_ = _tryInitFeeRecipientNft(bondVault_);
        IRebasingClaimToken claimToken_ = _deployRebasingClaimToken(cfg, bondVault_, detfNftId_);
        _initVaultTokens(hook_, address(cfg.pairToken));
        _initRepo(cfg, hook_, bondVault_, detfNftId_, feeRecipientNftId_, claimToken_);
    }

    function _deployRebasingClaimToken(
        DeployConfig storage cfg,
        IDETFNFTVault bondVault_,
        uint256 detfNftId_
    ) private returns (IRebasingClaimToken claimToken_) {
        address detf_ = address(this);
        claimToken_ = IRebasingClaimToken(
            REBASING_CLAIM_TOKEN_PKG.deployToken(
                IDetf(detf_), bondVault_, cfg.pairToken, detfNftId_, detf_
            )
        );
    }

    /// @dev Peer seigniorage shape: open a fee-recipient NFT owned by feeTo for claimable free DETF weight.
    ///      Requires fee oracle bond terms (global/type/vault) so createPosition lock validation passes.
    function _tryInitFeeRecipientNft(IDETFNFTVault bondVault_) private returns (uint256 feeNftId_) {
        address feeTo_ = address(FEE_ORACLE.feeTo());
        if (feeTo_ == address(0)) return 0;
        // 1-wei principal share: fee recipient participates in free-DETF reward ledger (no auto-compound).
        // Physical LP for this dust share is not required (convert excludes protocol NFT; fee dust is negligible).
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

    function _initVaultTokens(address hook_, address pair_) private {
        address[] memory vaultTokens_ = new address[](3);
        vaultTokens_[0] = address(this);
        vaultTokens_[1] = pair_;
        vaultTokens_[2] = hook_;
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
                standardExchangeVault: cfg.standardExchangeVault,
                standardExchangeVaultShare: cfg.standardExchangeVaultShare,
                pairToken: cfg.pairToken,
                reserveHook: hook_,
                poolManager: POOL_MANAGER,
                feeOracle: FEE_ORACLE,
                bondNftVault: bondVault_,
                rebasingClaimToken: claimToken_,
                detfNftId: detfNftId_,
                feeRecipientNftId: feeRecipientNftId_,
                creationPairPerDetfWad: cfg.creationPairPerDetfWad
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
        emit IUniswapV4SingleStandardExchangeDETF.ThresholdModeSet(
            cfg.thresholdMode, cfg.mintThreshold, cfg.burnThreshold
        );
    }

    function _validateSePair(DeployConfig storage cfg) private view {
        address se_ = address(cfg.standardExchangeVault);
        address pair_ = address(cfg.pairToken);
        address[] memory tokens_ = IBasicVault(se_).vaultTokens();
        bool found_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == pair_) found_ = true;
            if (tokens_[i] == address(this)) revert DetfInSeTokens();
        }
        if (!found_) revert PairTokenNotInSeTokens();
    }

    function _deployReserveHook(DeployConfig storage cfg) private returns (address hook_) {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs = IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
            .PkgArgs({
            poolManager: address(POOL_MANAGER),
            feeOracle: address(FEE_ORACLE),
            standardExchange: address(cfg.standardExchangeVault),
            pairToken: address(cfg.pairToken),
            rawToken: address(this)
        });
        // 0 → auto-mine flags (rawToken = this diamond is only known in postDeploy).
        if (cfg.hookMineNonce == 0) {
            hook_ = HOOK_PKG.deployVaultAutoMine(hArgs);
        } else {
            hook_ = HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce);
        }
    }

    function _initPool(address hook_) private {
        IHook h = IHook(hook_);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(h.currency0()),
            currency1: Currency.wrap(h.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook_)
        });
        POOL_MANAGER.initialize(key, SQRT_PRICE_1_1);
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
}
