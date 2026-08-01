// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {
    PoolRoleAccounts, TokenConfig, TokenType
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {IWeightedPool} from
    "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-weighted/IWeightedPool.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {BalancerV3VaultAwareRepo} from
    "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IBalancerV3StandardExchangeRouterProxy} from
    "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {BalancerV3StandardExchangeRouterAwareRepo} from
    "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {IUniswapV4StandardExchangeDFPkg} from
    "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {IUniswapV2StandardExchangeDFPkg} from
    "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol";
import {IStandardExchangeRateProviderDFPkg} from
    "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";

/// @title IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
/// @notice Diamond Factory Package interface for the DualLiquidityLinkedCrossVersionUniswapVault family.
/// @dev Per the PRD the deployed vault is immutable and unowned: the facet set is final (no ownership
///      and no diamond-cut facet is installed), so a flawed deployment is abandoned, not upgraded.
///      The package OWNS all infrastructure and companion-package references as immutables and deploys
///      the three leg vaults, optionally three rate providers, and the reserve weighted pool itself;
///      PkgArgs carry the underlying tokens, market configuration, and rate policy.
interface IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /// @notice Reverted when the package is deployed by any caller other than the Vault Registry.
    ///         The registry is the source of truth for all deployed vaults, so it is the only
    ///         permitted deployer.
    error NotCalledByRegistry(address caller);

    /// @notice Infrastructure + companion-package references bound once at package construction.
    /// @dev `erc5267Facet` + `erc2612Facet` give the share token EIP-2612 permit (gasless approvals).
    ///      `v4VaultPkg`/`v2VaultPkg`/`rateProviderPkg` deploy the legs (idempotent via the diamond
    ///      factory). `rateProviderPkg` remains required so one package binary can deploy rates-on
    ///      instances; when `PkgArgs.useRateProviders` is false, instance RP deploy is skipped.
    ///      `balancerV3Router`/`balancerV3Vault` back the direct Balancer integration.
    ///      `vaultRegistryDeployment` is the only permitted deployer (source of truth).
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
        IFacet exchangeInFacet;
        IFacet exchangeInQueryFacet;
        IFacet exchangeOutFacet;
        IFacet exchangeOutQueryFacet;
        IVaultFeeOracleQuery feeOracle;
        IVaultRegistryDeployment vaultRegistryDeployment;
        IBalancerV3StandardExchangeRouterProxy balancerV3Router;
        IVault balancerV3Vault;
        WeightedPoolFactory weightedPoolFactory;
        IUniswapV4StandardExchangeDFPkg v4VaultPkg;
        IUniswapV2StandardExchangeDFPkg v2VaultPkg;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
        IPermit2 permit2;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    /// @notice Per-instance deployment configuration: the underlying tokens plus the market config the
    ///         package needs to deploy the legs and create the reserve pool.
    /// @dev `poolKeyA`/`poolKeyB` are the Uniswap V4 commonToken/tokenA and commonToken/tokenB markets;
    ///      `pairPool` is the (pre-seeded) Uniswap V2 tokenA/tokenB pair. `weightA/B/pair` (WAD, must
    ///      sum to 1e18) default to 20/20/60. Deploy is inert (`totalSupply == 0`, reserve pool created
    ///      but uninitialized); the reserve is bootstrapped by a manual post-deploy procedure and the
    ///      first deposit mints 1:1.
    ///      `useRateProviders` is deploy-time only and homogeneous across all three reserve legs:
    ///      false (product default) → `TokenType.STANDARD` with zero rate providers (no RP deploy);
    ///      true → three SE rate providers + `TokenType.WITH_RATE`. Wrong choice → abandon instance.
    struct PkgArgs {
        string name;
        string symbol;
        IERC20 commonToken;
        IERC20 tokenA;
        IERC20 tokenB;
        PoolKey poolKeyA;
        uint24 widthMultiplierA;
        PoolKey poolKeyB;
        uint24 widthMultiplierB;
        IUniswapV2Pair pairPool;
        uint256 weightA;
        uint256 weightB;
        uint256 weightPair;
        /// @dev If true, deploy SE rate providers for all three legs and register TokenType.WITH_RATE.
        ///      If false (default product preference), register STANDARD with zero rate provider.
        bool useRateProviders;
        bytes32 optionalSalt;
    }

    function deployVault(PkgArgs memory args) external returns (address vault);
}

/// @title DualLiquidityLinkedCrossVersionUniswapVaultDFPkg
/// @notice Deploys immutable DualLiquidityLinkedCrossVersionUniswapVault diamonds. On deploy the package (running in the
///         new proxy's context) deploys the two Uniswap V4 leg vaults + one Uniswap V2 pair leg vault
///         (idempotent through the diamond factory), optionally a StandardExchange rate provider per leg
///         (when `useRateProviders`), and the 3-token Balancer V3 weighted reserve pool, then wires the
///         family storage internally.
contract DualLiquidityLinkedCrossVersionUniswapVaultDFPkg is IDiamondFactoryPackage, IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg {
    using BetterAddress for address[];
    using BetterEfficientHashLib for bytes;

    bytes32 private constant _DEPLOY_CONFIG_SLOT =
        keccak256("indexedex.vaults.protocol.uniswap.crossVersion.dual-liquidity-linked.pkg.deploy.config");

    IFacet immutable ERC20_FACET;
    IFacet immutable ERC5267_FACET;
    IFacet immutable ERC2612_FACET;
    IFacet immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IFacet immutable EXCHANGE_IN_FACET;
    IFacet immutable EXCHANGE_IN_QUERY_FACET;
    IFacet immutable EXCHANGE_OUT_FACET;
    IFacet immutable EXCHANGE_OUT_QUERY_FACET;
    IVaultFeeOracleQuery immutable FEE_ORACLE;
    IVaultRegistryDeployment immutable VAULT_REGISTRY_DEPLOYMENT;
    IBalancerV3StandardExchangeRouterProxy immutable BALANCER_V3_ROUTER;
    IVault immutable BALANCER_V3_VAULT;
    WeightedPoolFactory immutable WEIGHTED_POOL_FACTORY;
    IUniswapV4StandardExchangeDFPkg immutable V4_VAULT_PKG;
    IUniswapV2StandardExchangeDFPkg immutable V2_VAULT_PKG;
    IStandardExchangeRateProviderDFPkg immutable RATE_PROVIDER_PKG;
    IPermit2 immutable PERMIT2;
    IDiamondPackageCallBackFactory immutable DIAMOND_FACTORY;

    /// @dev Deployment config stashed in initAccount and consumed in postDeploy (both proxy-context).
    struct DeployConfig {
        IERC20 commonToken;
        IERC20 tokenA;
        IERC20 tokenB;
        PoolKey poolKeyA;
        uint24 widthMultiplierA;
        PoolKey poolKeyB;
        uint24 widthMultiplierB;
        IUniswapV2Pair pairPool;
        uint256 weightA;
        uint256 weightB;
        uint256 weightPair;
        bool useRateProviders;
    }

    /// @dev Legs + optional rate providers derived during postDeploy.
    struct Derived {
        IStandardExchange vaultA;
        IStandardExchange vaultB;
        IStandardExchange pairVault;
        IRateProvider rateA;
        IRateProvider rateB;
        IRateProvider ratePair;
        address reservePool;
        uint256 indexA;
        uint256 indexB;
        uint256 indexPair;
    }

    constructor(PkgInit memory pkgInit) {
        ERC20_FACET = pkgInit.erc20Facet;
        ERC5267_FACET = pkgInit.erc5267Facet;
        ERC2612_FACET = pkgInit.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = pkgInit.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = pkgInit.multiAssetStandardVaultFacet;
        EXCHANGE_IN_FACET = pkgInit.exchangeInFacet;
        EXCHANGE_IN_QUERY_FACET = pkgInit.exchangeInQueryFacet;
        EXCHANGE_OUT_FACET = pkgInit.exchangeOutFacet;
        EXCHANGE_OUT_QUERY_FACET = pkgInit.exchangeOutQueryFacet;
        FEE_ORACLE = pkgInit.feeOracle;
        VAULT_REGISTRY_DEPLOYMENT = pkgInit.vaultRegistryDeployment;
        BALANCER_V3_ROUTER = pkgInit.balancerV3Router;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        WEIGHTED_POOL_FACTORY = pkgInit.weightedPoolFactory;
        V4_VAULT_PKG = pkgInit.v4VaultPkg;
        V2_VAULT_PKG = pkgInit.v2VaultPkg;
        RATE_PROVIDER_PKG = pkgInit.rateProviderPkg;
        PERMIT2 = pkgInit.permit2;
        DIAMOND_FACTORY = pkgInit.diamondFactory;
    }

    function _deployConfig() internal pure returns (DeployConfig storage cfg_) {
        bytes32 slot_ = _DEPLOY_CONFIG_SLOT;
        assembly {
            cfg_.slot := slot_
        }
    }

    /// @inheritdoc IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg
    /// @dev Deploys through the Vault Registry so the vault is registered (the registry is the source
    ///      of truth for all deployed vaults). The registry calls back into `processArgs`/`initAccount`.
    function deployVault(PkgArgs memory args) external returns (address vault) {
        return VAULT_REGISTRY_DEPLOYMENT.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    /* ----------------------------- Metadata ------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).name;
    }

    /// @inheritdoc IStandardVaultPkg
    function name() public pure returns (string memory name_) {
        return packageName();
    }

    /// @inheritdoc IStandardVaultPkg
    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.USAGE, type(IStandardExchangeIn).interfaceId
        );
    }

    /// @inheritdoc IStandardVaultPkg
    function vaultTypes() public pure returns (bytes4[] memory typeIDs_) {
        return facetInterfaces();
    }

    /// @inheritdoc IStandardVaultPkg
    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration_) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](9);
        facetAddresses_[0] = address(ERC20_FACET);
        facetAddresses_[1] = address(ERC5267_FACET);
        facetAddresses_[2] = address(ERC2612_FACET);
        facetAddresses_[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facetAddresses_[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facetAddresses_[5] = address(EXCHANGE_IN_FACET);
        facetAddresses_[6] = address(EXCHANGE_IN_QUERY_FACET);
        facetAddresses_[7] = address(EXCHANGE_OUT_FACET);
        facetAddresses_[8] = address(EXCHANGE_OUT_QUERY_FACET);
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](8);
        interfaces_[0] = type(IERC20).interfaceId;
        interfaces_[1] = type(IERC20Metadata).interfaceId;
        interfaces_[2] = type(IERC20Permit).interfaceId;
        interfaces_[3] = type(IERC5267).interfaceId;
        interfaces_[4] = type(IBasicVault).interfaceId;
        interfaces_[5] = type(IStandardVault).interfaceId;
        interfaces_[6] = type(IStandardExchangeIn).interfaceId;
        interfaces_[7] = type(IStandardExchangeOut).interfaceId;
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

    /* --------------------------- Diamond config --------------------------- */

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](9);
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
        facetCuts_[6] = IDiamond.FacetCut(
            address(EXCHANGE_IN_QUERY_FACET), IDiamond.FacetCutAction.Add, EXCHANGE_IN_QUERY_FACET.facetFuncs()
        );
        facetCuts_[7] = IDiamond.FacetCut(
            address(EXCHANGE_OUT_FACET), IDiamond.FacetCutAction.Add, EXCHANGE_OUT_FACET.facetFuncs()
        );
        facetCuts_[8] = IDiamond.FacetCut(
            address(EXCHANGE_OUT_QUERY_FACET), IDiamond.FacetCutAction.Add, EXCHANGE_OUT_QUERY_FACET.facetFuncs()
        );
    }

    function diamondConfig() public view returns (DiamondConfig memory config_) {
        config_ = DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    /* -------------------------- Salt & lifecycle -------------------------- */

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt_) {
        return keccak256(pkgArgs);
    }

    /// @notice Restricts deployment to the Vault Registry: any other caller reverts. Ensures every
    ///         deployed vault is registered (the registry is the source of truth).
    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs_) {
        if (msg.sender != address(VAULT_REGISTRY_DEPLOYMENT)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    /// @notice Initializes the share token + Balancer aware repos and stashes the deployment config for
    ///         `postDeploy` (both run via delegatecall in the new proxy's context).
    function initAccount(bytes memory initArgs) public {
        PkgArgs memory args = abi.decode(initArgs, (PkgArgs));

        ERC20Repo._initialize(args.name, args.symbol, 18);
        EIP712Repo._initialize(args.name, "1");
        BalancerV3StandardExchangeRouterAwareRepo._initialize(BALANCER_V3_ROUTER);
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        DeployConfig storage cfg = _deployConfig();
        cfg.commonToken = args.commonToken;
        cfg.tokenA = args.tokenA;
        cfg.tokenB = args.tokenB;
        cfg.poolKeyA = args.poolKeyA;
        cfg.widthMultiplierA = args.widthMultiplierA;
        cfg.poolKeyB = args.poolKeyB;
        cfg.widthMultiplierB = args.widthMultiplierB;
        cfg.pairPool = args.pairPool;
        cfg.weightA = args.weightA == 0 ? 0.2e18 : args.weightA;
        cfg.weightB = args.weightB == 0 ? 0.2e18 : args.weightB;
        cfg.weightPair = args.weightPair == 0 ? 0.6e18 : args.weightPair;
        cfg.useRateProviders = args.useRateProviders;
    }

    /// @notice Deploys the legs, optional rate providers, and reserve pool, then wires family storage.
    ///         Runs in the proxy's context (the factory re-enters via `IPostDeployAccountHook.postDeploy`).
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
        Derived memory d = _deployLegsAndPool(cfg);

        DualLiquidityLinkedCrossVersionUniswapVaultRepo._initialize(
            DualLiquidityLinkedCrossVersionUniswapVaultRepo.InitArgs({
                commonToken: cfg.commonToken,
                tokenA: cfg.tokenA,
                tokenB: cfg.tokenB,
                vaultA: IStandardExchangeProxy(address(d.vaultA)),
                vaultB: IStandardExchangeProxy(address(d.vaultB)),
                pairVault: IStandardExchangeProxy(address(d.pairVault)),
                vaultAShare: IERC20(address(d.vaultA)),
                vaultBShare: IERC20(address(d.vaultB)),
                pairVaultShare: IERC20(address(d.pairVault)),
                reservePool: IWeightedPool(d.reservePool),
                reserveBpt: IERC20(d.reservePool),
                indexA: d.indexA,
                indexB: d.indexB,
                indexPair: d.indexPair,
                feeOracle: FEE_ORACLE
            })
        );

        _initializeVaultSurface(d);
        // Deploy is inert: totalSupply == 0 and the reserve pool is created but uninitialized. The
        // reserve is bootstrapped by a manual post-deploy procedure; the first deposit mints 1:1.
    }

    /// @dev Initializes the standard-vault surface the registry reads (`vaultConfig()` etc.): the vault
    ///      is a multi-asset vault whose contents are itself (the share token), the three legs, and the
    ///      reserve pool.
    function _initializeVaultSurface(Derived memory d) internal {
        address[] memory contents = new address[](5);
        contents[0] = address(this);
        contents[1] = address(d.vaultA);
        contents[2] = address(d.vaultB);
        contents[3] = address(d.pairVault);
        contents[4] = d.reservePool;

        MultiAssetBasicVaultRepo._initialize(contents);
        StandardVaultRepo._initialize(FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(contents._sort())._hash());
    }

    /// @dev Deploys the three legs (idempotent). When `useRateProviders`, deploys a rate provider per
    ///      leg (A/B denominated in commonToken, Pair in tokenA); otherwise rate providers stay zero.
    ///      Then creates the 3-token weighted reserve pool over the leg shares.
    function _deployLegsAndPool(DeployConfig storage cfg) internal returns (Derived memory d) {
        d.vaultA = IStandardExchange(V4_VAULT_PKG.deployVault(cfg.poolKeyA, cfg.widthMultiplierA));
        d.vaultB = IStandardExchange(V4_VAULT_PKG.deployVault(cfg.poolKeyB, cfg.widthMultiplierB));
        d.pairVault = IStandardExchange(V2_VAULT_PKG.deployVault(cfg.pairPool));

        if (cfg.useRateProviders) {
            d.rateA = RATE_PROVIDER_PKG.deployRateProvider(d.vaultA, cfg.commonToken);
            d.rateB = RATE_PROVIDER_PKG.deployRateProvider(d.vaultB, cfg.commonToken);
            d.ratePair = RATE_PROVIDER_PKG.deployRateProvider(d.pairVault, cfg.tokenA);
        }
        // else: rateA/B/pair remain address(0); TokenConfig uses STANDARD

        (d.reservePool, d.indexA, d.indexB, d.indexPair) = _createReservePool(cfg, d);
    }

    /// @dev Builds the sorted 3-token weighted pool (WITH_RATE or STANDARD per deploy policy) and
    ///      returns the pool address with the vault-order [A, B, pair] registration indices.
    function _createReservePool(DeployConfig storage cfg, Derived memory d)
        internal
        returns (address pool_, uint256 indexA_, uint256 indexB_, uint256 indexPair_)
    {
        TokenConfig[] memory cfgs = new TokenConfig[](3);
        uint256[] memory weights = new uint256[](3);
        {
            uint256[3] memory weightByCfg = [cfg.weightA, cfg.weightB, cfg.weightPair];
            bool useRates = cfg.useRateProviders;
            cfgs[0] = _legTokenConfig(address(d.vaultA), d.rateA, useRates);
            cfgs[1] = _legTokenConfig(address(d.vaultB), d.rateB, useRates);
            cfgs[2] = _legTokenConfig(address(d.pairVault), d.ratePair, useRates);
            _sortTokenConfigs(cfgs, weightByCfg);
            weights[0] = weightByCfg[0];
            weights[1] = weightByCfg[1];
            weights[2] = weightByCfg[2];
        }

        pool_ = _createWeightedPool(cfgs, weights, cfg.useRateProviders);

        indexA_ = _indexOf(cfgs, address(d.vaultA));
        indexB_ = _indexOf(cfgs, address(d.vaultB));
        indexPair_ = _indexOf(cfgs, address(d.pairVault));
    }

    /// @dev Isolates the many-argument weighted-pool `create` call in its own stack frame (no viaIR).
    ///      Salt includes rate policy so rates-on and rates-off with the same leg tokens cannot collide.
    function _createWeightedPool(TokenConfig[] memory cfgs, uint256[] memory weights, bool useRateProviders_)
        internal
        returns (address pool_)
    {
        string memory nm = string.concat("Reserve ", ERC20Repo._name());
        string memory sym = string.concat("r", ERC20Repo._symbol());
        bytes32 salt = keccak256(
            abi.encode(cfgs[0].token, cfgs[1].token, cfgs[2].token, useRateProviders_)
        );
        PoolRoleAccounts memory roleAccounts;
        pool_ = WEIGHTED_POOL_FACTORY.create(
            nm, sym, cfgs, weights, roleAccounts, 0.003e18, address(0), false, false, salt
        );
    }

    /// @dev Homogeneous leg TokenConfig: WITH_RATE + rate when useRates; STANDARD + zero otherwise.
    function _legTokenConfig(address token_, IRateProvider rateOrZero_, bool useRates_)
        internal
        pure
        returns (TokenConfig memory cfg_)
    {
        cfg_ = TokenConfig({
            token: OZIERC20(token_),
            tokenType: useRates_ ? TokenType.WITH_RATE : TokenType.STANDARD,
            rateProvider: useRates_ ? rateOrZero_ : IRateProvider(address(0)),
            paysYieldFees: false
        });
    }

    /// @dev Insertion sort of the 3 TokenConfigs by token address, keeping weights aligned.
    function _sortTokenConfigs(TokenConfig[] memory cfgs, uint256[3] memory weights) internal pure {
        for (uint256 i = 1; i < cfgs.length; i++) {
            TokenConfig memory keyCfg = cfgs[i];
            uint256 keyWeight = weights[i];
            uint256 j = i;
            while (j > 0 && address(cfgs[j - 1].token) > address(keyCfg.token)) {
                cfgs[j] = cfgs[j - 1];
                weights[j] = weights[j - 1];
                j--;
            }
            cfgs[j] = keyCfg;
            weights[j] = keyWeight;
        }
    }

    function _indexOf(TokenConfig[] memory cfgs, address token_) internal pure returns (uint256) {
        for (uint256 i = 0; i < cfgs.length; i++) {
            if (address(cfgs[i].token) == token_) return i;
        }
        revert("token not found");
    }
}
