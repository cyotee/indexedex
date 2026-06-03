// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IBasePool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBasePool.sol";
import {IPoolInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolInfo.sol";
import {IPoolLiquidity} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolLiquidity.sol";
import {
    ISwapFeePercentageBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISwapFeePercentageBounds.sol";
import {
    IUnbalancedLiquidityInvariantRatioBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IUnbalancedLiquidityInvariantRatioBounds.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IBalancerPoolToken} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerPoolToken.sol";
import {IHooks} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IHooks.sol";
import {
    TokenConfig,
    TokenType,
    PoolRoleAccounts,
    LiquidityManagement
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";

/* -------------------------------------------------------------------------- */
/*                                  OpenZeppelin                              */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {BetterAddress as Address} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterIERC20} from "@crane/contracts/interfaces/BetterIERC20.sol";
import {IBalancerV3VaultAware} from "@crane/contracts/interfaces/IBalancerV3VaultAware.sol";
import {
    BalancerV3BasePoolFactory
} from "@crane/contracts/protocols/dexes/balancer/v3/pool-utils/BalancerV3BasePoolFactory.sol";
import {TokenConfigUtils} from "@crane/contracts/protocols/dexes/balancer/v3/utils/TokenConfigUtils.sol";
import {
    BalancerV3BasePoolFactoryRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/pool-utils/BalancerV3BasePoolFactoryRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {BalancerV3PoolRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3PoolRepo.sol";
import {
    BalancerV3AuthenticationRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3AuthenticationRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {StandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";

/* -------------------------------------------------------------------------- */
/*                                 Interface                                  */
/* -------------------------------------------------------------------------- */

interface IStandardExchangeBufferPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerV3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet;
        IFacet balancerV3AuthenticationFacet;
        IFacet bufferPoolFacet;
        IFacet poolLiquidityFacet;
        IFacet hookFacet;
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracleQuery vaultFeeOracle;
        IVault balancerV3Vault;
        IDiamondPackageCallBackFactory diamondFactory;
        IStandardExchangeRateProviderDFPkg rateProviderPkg;
    }

    struct PkgArgs {
        IERC20 tta;
        IStandardExchange standardExchangeVault;
    }

    function deployPool(IStandardExchange seVault, IERC20 tta) external returns (address pool);
}

/* -------------------------------------------------------------------------- */
/*                                 Contract                                   */
/* -------------------------------------------------------------------------- */

contract StandardExchangeBufferPoolStandardVaultPkg is
    BalancerV3BasePoolFactory,
    IStandardExchangeBufferPoolPkg
{
    using Address for address[];
    using BetterEfficientHashLib for bytes;
    using SafeERC20 for IERC20;
    using SafeERC20 for BetterIERC20;
    using TokenConfigUtils for TokenConfig[];

    error NotCalledByRegistry(address caller);
    error InvalidTokensLength(uint256 maxLength, uint256 minLength, uint256 providedLength);

    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e14; // 0.01%
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18; // 10%
    // Buffer pool is constant-product: invariant ratio bounds are fixed at 1.0 (no rebalancing).
    uint256 private constant _MIN_INVARIANT_RATIO = 1e18;
    uint256 private constant _MAX_INVARIANT_RATIO = 1e18;

    StandardExchangeBufferPoolStandardVaultPkg public immutable SELF;

    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE;
    IVaultRegistryDeployment public immutable VAULT_REGISTRY;
    IVault public immutable BALANCER_V3_VAULT;
    IDiamondPackageCallBackFactory public immutable DIAMOND_PACKAGE_FACTORY;

    IStandardExchangeRateProviderDFPkg public immutable RATE_PROVIDER_PKG;

    IFacet public immutable BASIC_VAULT_FACET;
    IFacet public immutable STANDARD_VAULT_FACET;
    IFacet public immutable BALANCER_V3_VAULT_AWARE_FACET;
    IFacet public immutable BETTER_BALANCER_V3_POOL_TOKEN_FACET;
    IFacet public immutable DEFAULT_POOL_INFO_FACET;
    IFacet public immutable STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET;
    IFacet public immutable UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET;
    IFacet public immutable BALANCER_V3_AUTHENTICATION_FACET;
    IFacet public immutable BUFFER_POOL_FACET;
    IFacet public immutable POOL_LIQUIDITY_FACET;
    IFacet public immutable HOOK_FACET;

    constructor(PkgInit memory init) {
        SELF = this;
        VAULT_FEE_ORACLE = init.vaultFeeOracle;
        VAULT_REGISTRY = init.vaultRegistry;
        BALANCER_V3_VAULT = init.balancerV3Vault;
        DIAMOND_PACKAGE_FACTORY = init.diamondFactory;
        RATE_PROVIDER_PKG = init.rateProviderPkg;
        BASIC_VAULT_FACET = init.basicVaultFacet;
        STANDARD_VAULT_FACET = init.standardVaultFacet;
        BALANCER_V3_VAULT_AWARE_FACET = init.balancerV3VaultAwareFacet;
        BETTER_BALANCER_V3_POOL_TOKEN_FACET = init.betterBalancerV3PoolTokenFacet;
        DEFAULT_POOL_INFO_FACET = init.defaultPoolInfoFacet;
        STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET = init.standardSwapFeePercentageBoundsFacet;
        UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET = init.unbalancedLiquidityInvariantRatioBoundsFacet;
        BALANCER_V3_AUTHENTICATION_FACET = init.balancerV3AuthenticationFacet;
        BUFFER_POOL_FACET = init.bufferPoolFacet;
        POOL_LIQUIDITY_FACET = init.poolLiquidityFacet;
        HOOK_FACET = init.hookFacet;

        BalancerV3BasePoolFactoryRepo._initialize(365 days, address(VAULT_FEE_ORACLE.feeTo()));
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));

        // Initialize vault repo so postDeploy can call _registerPoolWithBalV3Vault.
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
    }

    function _diamondPkgFactory() internal view virtual override returns (IDiamondPackageCallBackFactory) {
        return DIAMOND_PACKAGE_FACTORY;
    }

    /// forge-lint: disable-next-line(mixed-case-function)
    function _poolDFPkg() internal view virtual override returns (IDiamondFactoryPackage) {
        return IDiamondFactoryPackage(this);
    }

    /* ---------------------------------------------------------------------- */
    /*                            IStandardVaultPkg                           */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return type(StandardExchangeBufferPoolStandardVaultPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.DEX, type(IStandardExchangeBufferPoolPkg).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    /* ---------------------------------------------------------------------- */
    /*                         IDiamondFactoryPackage                         */
    /* ---------------------------------------------------------------------- */

    function packageName() public pure returns (string memory name_) {
        return type(StandardExchangeBufferPoolStandardVaultPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](15);
        interfaces[0]  = type(IERC20).interfaceId;
        interfaces[1]  = type(IERC20Metadata).interfaceId;
        interfaces[2]  = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        interfaces[3]  = type(IERC20Permit).interfaceId;
        interfaces[4]  = type(IERC5267).interfaceId;
        interfaces[5]  = type(IBasicVault).interfaceId;
        interfaces[6]  = type(IStandardVault).interfaceId;
        interfaces[7]  = type(IBalancerV3VaultAware).interfaceId;
        interfaces[8]  = type(IPoolInfo).interfaceId;
        interfaces[9]  = type(IBasePool).interfaceId;
        interfaces[10] = type(ISwapFeePercentageBounds).interfaceId;
        interfaces[11] = type(IUnbalancedLiquidityInvariantRatioBounds).interfaceId;
        interfaces[12] = type(IBalancerPoolToken).interfaceId;
        interfaces[13] = type(IPoolLiquidity).interfaceId;
        interfaces[14] = type(IHooks).interfaceId;
        return interfaces;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](11);
        facetAddresses_[0]  = address(BASIC_VAULT_FACET);
        facetAddresses_[1]  = address(STANDARD_VAULT_FACET);
        facetAddresses_[2]  = address(BALANCER_V3_VAULT_AWARE_FACET);
        facetAddresses_[3]  = address(BETTER_BALANCER_V3_POOL_TOKEN_FACET);
        facetAddresses_[4]  = address(DEFAULT_POOL_INFO_FACET);
        facetAddresses_[5]  = address(STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET);
        facetAddresses_[6]  = address(UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET);
        facetAddresses_[7]  = address(BALANCER_V3_AUTHENTICATION_FACET);
        facetAddresses_[8]  = address(BUFFER_POOL_FACET);
        facetAddresses_[9]  = address(POOL_LIQUIDITY_FACET);
        facetAddresses_[10] = address(HOOK_FACET);
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        address[] memory addrs = facetAddresses();
        facetCuts_ = new IDiamond.FacetCut[](addrs.length);
        for (uint256 i; i < addrs.length; ++i) {
            facetCuts_[i] = IDiamond.FacetCut({
                facetAddress: addrs[i],
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: IFacet(addrs[i]).facetFuncs()
            });
        }
    }

    /**
     * @return config Unified function to retrieved `facetInterfaces()` AND `facetCuts()` in one call.
     */
    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY)) {
            revert NotCalledByRegistry(msg.sender);
        }
        return pkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public virtual returns (bool) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        IERC20 shares = IERC20(address(a.standardExchangeVault));
        IRateProvider rp = RATE_PROVIDER_PKG.deployRateProvider(a.standardExchangeVault, a.tta);
        // Build the sorted TokenConfig array and store it for postDeploy.
        TokenConfig[] memory tc = _buildTokenConfigs(a.tta, shares, rp);
        BalancerV3BasePoolFactoryRepo._setTokenConfigs(expectedProxy, tc);
        // The hook lives in the same Diamond as the pool; store proxy address as the hooks contract.
        BalancerV3BasePoolFactoryRepo._setHooksContract(expectedProxy, expectedProxy);
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));

        // Derive the share token from the SE vault address (the vault IS its own share token).
        IERC20 shares = IERC20(address(a.standardExchangeVault));

        // Deploy (or idempotently recover) the canonical rate provider for this (seVault, tta) pair.
        IRateProvider rp = RATE_PROVIDER_PKG.deployRateProvider(a.standardExchangeVault, a.tta);

        // IMPORTANT: must be initialized on the proxy (storage), not just in the package constructor.
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        // Determine sorted indices: lower address = index 0 (Balancer convention).
        (uint256 ttaIdx, uint256 sharesIdx) =
            address(a.tta) < address(shares) ? (0, 1) : (1, 0);

        address[] memory tokens = new address[](2);
        tokens[ttaIdx]    = address(a.tta);
        tokens[sharesIdx] = address(shares);

        MultiAssetBasicVaultRepo._initialize(tokens);

        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE,
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(tokens, address(a.standardExchangeVault), address(rp))._hash()
        );

        string memory name_ = string.concat(
            "BV3StdExchBuffer of (",
            IERC20Metadata(address(a.tta)).name(),
            " <-> ",
            IERC20Metadata(address(shares)).name(),
            ")"
        );

        ERC20Repo._initialize(name_, "BPT", 18);
        EIP712Repo._initialize(name_, "1");
        BalancerV3PoolRepo._initialize(
            _MIN_INVARIANT_RATIO,
            _MAX_INVARIANT_RATIO,
            _MIN_SWAP_FEE_PERCENTAGE,
            _MAX_SWAP_FEE_PERCENTAGE,
            tokens
        );
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));

        StandardExchangeBufferPoolRepo._initialize(
            a.tta,
            shares,
            a.standardExchangeVault,
            rp,
            ttaIdx,
            sharesIdx,
            address(SELF)
        );
    }

    function _roleAccounts() internal view returns (PoolRoleAccounts memory roleAccounts) {
        address feeTo_ = address(VAULT_FEE_ORACLE.feeTo());
        roleAccounts = PoolRoleAccounts({pauseManager: feeTo_, swapFeeManager: feeTo_, poolCreator: feeTo_});
    }

    function _liquidityManagement() internal pure returns (LiquidityManagement memory liquidityManagement) {
        liquidityManagement = LiquidityManagement({
            disableUnbalancedLiquidity: true,
            enableAddLiquidityCustom: true,
            enableRemoveLiquidityCustom: true,
            enableDonation: true
        });
    }

    function postDeploy(address proxy) public returns (bool) {
        _registerPoolWithBalV3Vault(
            // address pool
            proxy,
            // TokenConfig[] memory tokens
            BalancerV3BasePoolFactoryRepo._getTokenConfigs(proxy),
            // uint256 swapFeePercentage — default 0.05%; tune per deployment
            5e16,
            // bool protocolFeeExempt
            false,
            // PoolRoleAccounts memory roleAccounts
            _roleAccounts(),
            // address poolHooksContract — hook facet lives in this Diamond, so proxy == hook
            proxy,
            // LiquidityManagement memory liquidityManagement
            _liquidityManagement()
        );
        return true;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Internal helpers                           */
    /* ---------------------------------------------------------------------- */

    function _buildTokenConfigs(
        IERC20 tta,
        IERC20 shares,
        IRateProvider rp
    ) internal pure returns (TokenConfig[] memory tc) {
        tc = new TokenConfig[](2);
        (uint256 ttaIdx, uint256 sharesIdx) =
            address(tta) < address(shares) ? (0, 1) : (1, 0);
        tc[ttaIdx] = TokenConfig({
            token:         tta,
            tokenType:     TokenType.STANDARD,
            rateProvider:  IRateProvider(address(0)),
            paysYieldFees: false
        });
        tc[sharesIdx] = TokenConfig({
            token:         shares,
            tokenType:     TokenType.WITH_RATE,
            rateProvider:  rp,
            paysYieldFees: false
        });
    }

    /* ---------------------------------------------------------------------- */
    /*                              Public API                                 */
    /* ---------------------------------------------------------------------- */

    function deployPool(IStandardExchange seVault, IERC20 tta) external returns (address pool) {
        pool = VAULT_REGISTRY.deployVault(
            IStandardVaultPkg(address(this)),
            abi.encode(PkgArgs({tta: tta, standardExchangeVault: seVault}))
        );
    }
}
