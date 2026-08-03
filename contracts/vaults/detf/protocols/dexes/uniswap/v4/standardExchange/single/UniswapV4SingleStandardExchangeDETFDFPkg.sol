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
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {
    UniV4DetfListingOracleLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/UniV4DetfListingOracleLib.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFRepo.sol";
import {
    IUniswapV4SingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFBondingTarget.sol";
import {
    IUniswapV4SingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFInfoTarget.sol";
import {
    IUniV4DetfBondNftDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftDFPkg.sol";
import {
    IUniV4DetfRebasingClaimDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol";

/// @title IUniswapV4SingleStandardExchangeDETFDFPkg
interface IUniswapV4SingleStandardExchangeDETFDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    error NotCalledByRegistry(address caller);
    error PairTokenNotInBackingTokens();
    error HooksNotAllowed();
    error InvalidCreationPrice();
    error InvalidWidthMultiplier();

    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IPoolManager poolManager;
        IUniV4DetfBondNftDFPkg bondNftPkg;
        IUniV4DetfRebasingClaimDFPkg rebasingClaimPkg;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        string name;
        string symbol;
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare; // address(0) → vault is share
        IERC20 pairToken;
        uint24 poolFee;
        int24 tickSpacing;
        address hooks; // must be address(0)
        uint160 sqrtPriceX96;
        uint32 twapSeconds; // 0 → 1800
        uint24 widthMultiplier;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
    }

    function deployVault(PkgArgs memory args) external returns (address vault);
}

/// @title UniswapV4SingleStandardExchangeDETFDFPkg
contract UniswapV4SingleStandardExchangeDETFDFPkg is IUniswapV4SingleStandardExchangeDETFDFPkg {
    using BetterEfficientHashLib for bytes;
    using PoolIdLibrary for PoolKey;

    bytes32 private constant _DEPLOY_CONFIG_SLOT =
        keccak256("vault.detf.uniswap.v4.standardExchange.single.pkg.deploy-config");

    struct DeployConfig {
        IStandardExchangeProxy standardExchangeVault;
        IERC20 standardExchangeVaultShare;
        IERC20 pairToken;
        uint24 poolFee;
        int24 tickSpacing;
        address hooks;
        uint160 sqrtPriceX96;
        uint32 twapSeconds;
        uint24 widthMultiplier;
        uint256 mintThreshold;
        uint256 burnThreshold;
        ThresholdMode thresholdMode;
        uint256 expansionClosureRatePerSecond;
        uint256 expansionCatchUpMaxSeconds;
        uint256 expansionCatchUpCapBps;
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
    IUniV4DetfBondNftDFPkg immutable BOND_NFT_PKG;
    IUniV4DetfRebasingClaimDFPkg immutable REBASING_CLAIM_PKG;
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
        POOL_MANAGER = pkgInit.poolManager;
        BOND_NFT_PKG = pkgInit.bondNftPkg;
        REBASING_CLAIM_PKG = pkgInit.rebasingClaimPkg;
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
        return type(UniswapV4SingleStandardExchangeDETFDFPkg).name;
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
        interfaces_[7] = type(IUniswapV4SingleStandardExchangeDETFBonding).interfaceId;
        interfaces_[8] = type(IUniswapV4SingleStandardExchangeDETFInfo).interfaceId;
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

        if (args.hooks != address(0)) revert HooksNotAllowed();
        if (args.sqrtPriceX96 == 0) revert InvalidCreationPrice();
        // Bound-check sqrt price roughly via TickMath.
        if (
            args.sqrtPriceX96 < TickMath.MIN_SQRT_PRICE || args.sqrtPriceX96 >= TickMath.MAX_SQRT_PRICE
        ) {
            revert InvalidCreationPrice();
        }
        if (args.widthMultiplier < 1) revert InvalidWidthMultiplier();

        IERC20 seShare = address(args.standardExchangeVaultShare) == address(0)
            ? IERC20(address(args.standardExchangeVault))
            : args.standardExchangeVaultShare;

        // pairToken ∈ Backing SE tokens()
        address[] memory tokens_ = IBasicVault(address(args.standardExchangeVault)).vaultTokens();
        bool found_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(args.pairToken)) {
                found_ = true;
                break;
            }
        }
        if (!found_) revert PairTokenNotInBackingTokens();

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");

        address[] memory contents_ = new address[](2);
        contents_[0] = address(args.standardExchangeVault);
        contents_[1] = address(args.pairToken);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents_)._hash());

        DETFThresholdPolicy.requireValidThresholdMode(args.thresholdMode);
        (uint256 mint_, uint256 burn_) =
            DETFThresholdPolicy.resolveAndRequireValidThresholds(args.mintThreshold, args.burnThreshold);
        (uint256 expRate_, uint256 expCatchUpSec_, uint256 expCapBps_) = DETFNaturalExpansionLib.resolveExpansionParams(
            args.expansionClosureRatePerSecond, args.expansionCatchUpMaxSeconds, args.expansionCatchUpCapBps
        );

        DeployConfig storage cfg = _deployConfig();
        cfg.standardExchangeVault = args.standardExchangeVault;
        cfg.standardExchangeVaultShare = seShare;
        cfg.pairToken = args.pairToken;
        cfg.poolFee = args.poolFee;
        cfg.tickSpacing = args.tickSpacing;
        cfg.hooks = args.hooks;
        cfg.sqrtPriceX96 = args.sqrtPriceX96;
        cfg.twapSeconds = args.twapSeconds == 0 ? 1800 : args.twapSeconds;
        cfg.widthMultiplier = args.widthMultiplier;
        cfg.mintThreshold = mint_;
        cfg.burnThreshold = burn_;
        cfg.thresholdMode = args.thresholdMode;
        cfg.expansionClosureRatePerSecond = expRate_;
        cfg.expansionCatchUpMaxSeconds = expCatchUpSec_;
        cfg.expansionCatchUpCapBps = expCapBps_;
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
        address detf_ = address(this);

        // Sort currencies for PoolKey.
        address tokenA = detf_;
        address tokenB = address(cfg.pairToken);
        Currency c0;
        Currency c1;
        bool pairIs0;
        if (tokenA < tokenB) {
            c0 = Currency.wrap(tokenA);
            c1 = Currency.wrap(tokenB);
            pairIs0 = false; // pair is currency1
        } else {
            c0 = Currency.wrap(tokenB);
            c1 = Currency.wrap(tokenA);
            pairIs0 = true; // pair is currency0
        }

        PoolKey memory key = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: cfg.poolFee,
            tickSpacing: cfg.tickSpacing,
            hooks: IHooks(cfg.hooks)
        });

        // Initialize listing pool.
        int24 tick = POOL_MANAGER.initialize(key, cfg.sqrtPriceX96);
        PoolId poolId = key.toId();

        // Bootstrap listing-oracle ring.
        UniV4DetfListingOracleLib._initialize(tick);

        // Deploy bond NFT child (pure Crane).
        address bondNft = BOND_NFT_PKG.deployBondNft(
            IUniV4DetfBondNftDFPkg.PkgArgs({
                detf: detf_,
                poolManager: POOL_MANAGER,
                poolKey: key,
                pairToken: cfg.pairToken,
                detfToken: IERC20(detf_),
                widthMultiplier: cfg.widthMultiplier,
                owner: detf_,
                optionalSalt: abi.encode(detf_, "bond")._hash()
            })
        );

        // Deploy rebasing child (pure Crane).
        address rebasing = REBASING_CLAIM_PKG.deployClaim(
            IUniV4DetfRebasingClaimDFPkg.PkgArgs({
                name: string(abi.encodePacked(ERC20Repo._name(), " Claim")),
                symbol: string(abi.encodePacked(ERC20Repo._symbol(), "-RC")),
                poolManager: POOL_MANAGER,
                poolKey: key,
                pairToken: cfg.pairToken,
                detfToken: IERC20(detf_),
                widthMultiplier: cfg.widthMultiplier,
                owner: detf_,
                optionalSalt: abi.encode(detf_, "rebasing")._hash()
            })
        );

        // Basic vault tokens surface.
        address[] memory vaultTokens_ = new address[](3);
        vaultTokens_[0] = detf_;
        vaultTokens_[1] = address(cfg.standardExchangeVaultShare);
        vaultTokens_[2] = address(cfg.pairToken);
        MultiAssetBasicVaultRepo._initialize(vaultTokens_);

        UniswapV4SingleStandardExchangeDETFRepo._initialize(
            UniswapV4SingleStandardExchangeDETFRepo.InitParams({
                standardExchangeVault: cfg.standardExchangeVault,
                standardExchangeVaultShare: cfg.standardExchangeVaultShare,
                pairToken: cfg.pairToken,
                poolManager: POOL_MANAGER,
                poolKey: key,
                poolId: poolId,
                creationSqrtPriceX96: cfg.sqrtPriceX96,
                pairIsCurrency0: pairIs0,
                twapSeconds: cfg.twapSeconds,
                widthMultiplier: cfg.widthMultiplier,
                mintThreshold: cfg.mintThreshold,
                burnThreshold: cfg.burnThreshold,
                thresholdMode: cfg.thresholdMode,
                feeOracle: FEE_ORACLE,
                bondNft: bondNft,
                rebasingClaimToken: rebasing,
                expansionClosureRatePerSecond: cfg.expansionClosureRatePerSecond,
                expansionCatchUpMaxSeconds: cfg.expansionCatchUpMaxSeconds,
                expansionCatchUpCapBps: cfg.expansionCatchUpCapBps
            })
        );
    }
}
