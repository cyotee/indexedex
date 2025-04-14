// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IBasePool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBasePool.sol";
import {IPoolInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IPoolInfo.sol";
// import { IRateProvider } from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    ISwapFeePercentageBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISwapFeePercentageBounds.sol";
import {
    IUnbalancedLiquidityInvariantRatioBounds
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IUnbalancedLiquidityInvariantRatioBounds.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    TokenConfig,
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

// import {
//     AddressSet
//     // AddressSetRepo
// } from "@crane/src/utils/collections/sets/AddressSetRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {BetterIERC20} from "@crane/contracts/interfaces/BetterIERC20.sol";
// import {
//     BetterBalancerV3PoolTokenStorage
// } from "@crane/contracts/protocols/dexes/balancer/v3/vault/utils/BetterBalancerV3PoolTokenStorage.sol";
import {IBalancerV3VaultAware} from "@crane/contracts/interfaces/IBalancerV3VaultAware.sol";
import {IBalancerPoolToken} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerPoolToken.sol";
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

    // BondTerms,
    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

interface IBalancerV3ConstantProductPoolStandardVaultPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    struct PkgInit {
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet balancerV3VaultAwareFacet;
        IFacet betterBalancerV3PoolTokenFacet;
        IFacet defaultPoolInfoFacet;
        IFacet standardSwapFeePercentageBoundsFacet;
        IFacet unbalancedLiquidityInvariantRatioBoundsFacet;
        IFacet balancerV3AuthenticationFacet;
        IFacet balancerV3ConstProdPoolFacet;
        IVaultRegistryDeployment vaultRegistry;
        IVaultFeeOracleQuery vaultFeeOracle;
        IVault balancerV3Vault;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct PkgArgs {
        TokenConfig[] tokenConfigs;
        address hooksContract;
    }

    function constantProductMarkerFunction() external pure returns (bool);

    function deployVault(TokenConfig[] calldata tokenConfigs, address hooksContract) external returns (address vault);
}

contract BalancerV3ConstantProductPoolStandardVaultPkg is
    BalancerV3BasePoolFactory,
    IBalancerV3ConstantProductPoolStandardVaultPkg
{
    using Address for address[];
    using BetterEfficientHashLib for bytes;
    using SafeERC20 for IERC20;
    using SafeERC20 for BetterIERC20;
    using TokenConfigUtils for TokenConfig[];

    error NotCalledByRegistry(address caller);

    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12; // 0.0001%
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18; // 10%
    uint256 private constant _MIN_INVARIANT_RATIO = 70e16; // 70%
    uint256 private constant _MAX_INVARIANT_RATIO = 300e16; // 300%

    BalancerV3ConstantProductPoolStandardVaultPkg public immutable SELF;

    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE;
    IVaultRegistryDeployment public immutable VAULT_REGISTRY;
    IVault public immutable BALANCER_V3_VAULT;
    IDiamondPackageCallBackFactory public immutable DIAMOND_PACKAGE_FACTORY;

    IFacet public immutable BASIC_VAULT_FACET;
    IFacet public immutable STANDARD_VAULT_FACET;
    IFacet public immutable BALANCER_V3_VAULT_AWARE_FACET;
    IFacet public immutable BETTER_BALANCER_V3_POOL_TOKEN_FACET;
    IFacet public immutable DEFAULT_POOL_INFO_FACET;
    IFacet public immutable STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET;
    IFacet public immutable UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET;
    IFacet public immutable BALANCER_V3_AUTHENTICATION_FACET;
    IFacet public immutable BALANCER_V3_CONST_PROD_POOL_FACET;

    constructor(PkgInit memory pkgInit) {
        SELF = this;
        VAULT_FEE_ORACLE = pkgInit.vaultFeeOracle;
        VAULT_REGISTRY = pkgInit.vaultRegistry;
        BALANCER_V3_VAULT = pkgInit.balancerV3Vault;
        DIAMOND_PACKAGE_FACTORY = pkgInit.diamondFactory;
        BASIC_VAULT_FACET = pkgInit.basicVaultFacet;
        STANDARD_VAULT_FACET = pkgInit.standardVaultFacet;
        BALANCER_V3_VAULT_AWARE_FACET = pkgInit.balancerV3VaultAwareFacet;
        BETTER_BALANCER_V3_POOL_TOKEN_FACET = pkgInit.betterBalancerV3PoolTokenFacet;
        DEFAULT_POOL_INFO_FACET = pkgInit.defaultPoolInfoFacet;
        STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET = pkgInit.standardSwapFeePercentageBoundsFacet;
        UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET = pkgInit.unbalancedLiquidityInvariantRatioBoundsFacet;
        BALANCER_V3_AUTHENTICATION_FACET = pkgInit.balancerV3AuthenticationFacet;
        BALANCER_V3_CONST_PROD_POOL_FACET = pkgInit.balancerV3ConstProdPoolFacet;
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

    function constantProductMarkerFunction() external pure returns (bool) {
        return true;
    }

    /* ---------------------------------------------------------------------- */
    /*                            IStandardVaultPkg                           */
    /* ---------------------------------------------------------------------- */

    function name() public pure returns (string memory) {
        return type(BalancerV3ConstantProductPoolStandardVaultPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.DEX, type(IBalancerV3ConstantProductPoolStandardVaultPkg).interfaceId
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
        return type(BalancerV3ConstantProductPoolStandardVaultPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](13);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Metadata).interfaceId ^ type(IERC20).interfaceId;
        interfaces[3] = type(IERC20Permit).interfaceId;
        interfaces[4] = type(IERC5267).interfaceId;
        interfaces[5] = type(IBasicVault).interfaceId;
        interfaces[6] = type(IStandardVault).interfaceId;
        interfaces[7] = type(IBalancerV3VaultAware).interfaceId;
        interfaces[8] = type(IPoolInfo).interfaceId;
        interfaces[9] = type(IBasePool).interfaceId;
        interfaces[10] = type(ISwapFeePercentageBounds).interfaceId;
        interfaces[11] = type(IUnbalancedLiquidityInvariantRatioBounds).interfaceId;
        interfaces[12] = type(IBalancerPoolToken).interfaceId;
        return interfaces;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](9);
        facetAddresses_[0] = address(BASIC_VAULT_FACET);
        facetAddresses_[1] = address(STANDARD_VAULT_FACET);
        facetAddresses_[2] = address(BALANCER_V3_VAULT_AWARE_FACET);
        facetAddresses_[3] = address(BETTER_BALANCER_V3_POOL_TOKEN_FACET);
        facetAddresses_[4] = address(DEFAULT_POOL_INFO_FACET);
        facetAddresses_[5] = address(STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET);
        facetAddresses_[6] = address(UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET);
        facetAddresses_[7] = address(BALANCER_V3_AUTHENTICATION_FACET);
        facetAddresses_[8] = address(BALANCER_V3_CONST_PROD_POOL_FACET);
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
        facetCuts_ = new IDiamond.FacetCut[](9);

        facetCuts_[0] = IDiamond.FacetCut({
            facetAddress: address(BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BASIC_VAULT_FACET.facetFuncs()
        });

        facetCuts_[1] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_VAULT_FACET.facetFuncs()
        });

        facetCuts_[2] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_VAULT_AWARE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_VAULT_AWARE_FACET.facetFuncs()
        });

        facetCuts_[3] = IDiamond.FacetCut({
            facetAddress: address(BETTER_BALANCER_V3_POOL_TOKEN_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BETTER_BALANCER_V3_POOL_TOKEN_FACET.facetFuncs()
        });

        facetCuts_[4] = IDiamond.FacetCut({
            facetAddress: address(DEFAULT_POOL_INFO_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: DEFAULT_POOL_INFO_FACET.facetFuncs()
        });

        facetCuts_[5] = IDiamond.FacetCut({
            facetAddress: address(STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET.facetFuncs()
        });

        facetCuts_[6] = IDiamond.FacetCut({
            facetAddress: address(UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET.facetFuncs()
        });

        facetCuts_[7] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_AUTHENTICATION_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_AUTHENTICATION_FACET.facetFuncs()
        });

        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(BALANCER_V3_CONST_PROD_POOL_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: BALANCER_V3_CONST_PROD_POOL_FACET.facetFuncs()
        });

        return facetCuts_;
    }

    /**
     * @return config Unified function to retrieved `facetInterfaces()` AND `facetCuts()` in one call.
     */
    function diamondConfig() public view returns (DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory decodedArgs = abi.decode(pkgArgs, (PkgArgs));

        if (decodedArgs.tokenConfigs.length != 2) {
            revert InvalidTokensLength(2, 2, decodedArgs.tokenConfigs.length);
        }

        decodedArgs.tokenConfigs = decodedArgs.tokenConfigs._sort();
        pkgArgs = abi.encode(decodedArgs);
        // return keccak256(abi.encode(pkgArgs));
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory processedPkgArgs) {
        if (msg.sender != address(VAULT_REGISTRY)) {
            revert NotCalledByRegistry(msg.sender);
        }
        PkgArgs memory decodedArgs = abi.decode(pkgArgs, (PkgArgs));
        decodedArgs.tokenConfigs = decodedArgs.tokenConfigs._sort();
        processedPkgArgs = abi.encode(decodedArgs);
        return processedPkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public virtual returns (bool) {
        PkgArgs memory decodedArgs = abi.decode(pkgArgs, (PkgArgs));
        BalancerV3BasePoolFactoryRepo._setTokenConfigs(expectedProxy, decodedArgs.tokenConfigs);
        BalancerV3BasePoolFactoryRepo._setHooksContract(expectedProxy, decodedArgs.hooksContract);
        return true;
    }

    error InvalidTokensLength(uint256 maxLength, uint256 minLength, uint256 providedLength);

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decodedArgs = abi.decode(initArgs, (PkgArgs));

        // IMPORTANT: this must be initialized on the proxy (storage), not just in the package constructor.
        // Several Balancer V3 pool token helpers are vault-gated and will revert during `Vault.initialize(...)`
        // if the proxy doesn't know the Balancer V3 Vault address.
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        address[] memory tokens = new address[](decodedArgs.tokenConfigs.length);
        tokens[0] = address(decodedArgs.tokenConfigs[0].token);
        tokens[1] = address(decodedArgs.tokenConfigs[1].token);

        MultiAssetBasicVaultRepo._initialize(
            // address[] memory vaultTokens,
            tokens
        );

        StandardVaultRepo._initialize(
            // IVaultFeeOracleQuery feeOracle,
            VAULT_FEE_ORACLE,
            // bytes32 vaultFeeTypeIds,
            vaultFeeTypeIds(),
            // bytes4[] memory vaultTypes,
            vaultTypes(),
            // bytes32 contentsId
            abi.encode(tokens)._hash()
        );

        string memory name_ = string.concat(
            "BV3ConstProd of (", IERC20Metadata(tokens[0]).name(), " / ", IERC20Metadata(tokens[1]).name(), ")"
        );

        ERC20Repo._initialize(name_, "BPT", 18);
        EIP712Repo._initialize(name_, "1");
        BalancerV3PoolRepo._initialize(
            _MIN_INVARIANT_RATIO, _MAX_INVARIANT_RATIO, _MIN_SWAP_FEE_PERCENTAGE, _MAX_SWAP_FEE_PERCENTAGE, tokens
        );
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));
    }

    function _roleAccounts() internal view returns (PoolRoleAccounts memory roleAccounts) {
        address feeTo_ = address(VAULT_FEE_ORACLE.feeTo());
        roleAccounts = PoolRoleAccounts({pauseManager: feeTo_, swapFeeManager: feeTo_, poolCreator: feeTo_});
    }

    function _liquidityManagement() internal pure returns (LiquidityManagement memory liquidityManagement) {
        liquidityManagement = LiquidityManagement({
            disableUnbalancedLiquidity: false,
            enableAddLiquidityCustom: false,
            enableRemoveLiquidityCustom: false,
            enableDonation: true
        });
    }

    function postDeploy(address proxy) public returns (bool) {
        _registerPoolWithBalV3Vault(
            // address pool,
            proxy,
            // TokenConfig[] memory tokens,
            BalancerV3BasePoolFactoryRepo._getTokenConfigs(proxy),
            // uint256 swapFeePercentage,
            5e16,
            // bool protocolFeeExempt,
            false,
            // PoolRoleAccounts memory roleAccounts,
            _roleAccounts(),
            // address poolHooksContract,
            BalancerV3BasePoolFactoryRepo._getHooksContract(proxy),
            // LiquidityManagement memory liquidityManagement
            _liquidityManagement()
        );
        return true;
    }

    function deployVault(TokenConfig[] calldata tokenConfigs_, address hooksContract) public returns (address vault) {
        vault = VAULT_REGISTRY.deployVault(
            IStandardVaultPkg(address(this)),
            abi.encode(PkgArgs({tokenConfigs: tokenConfigs_, hooksContract: hooksContract}))
        );
    }

    // function _tokens()
    // internal view virtual
    // override(BetterBalancerV3PoolTokenStorage, StandardVaultStorage)
    // returns (AddressSet storage) {
    //     return _balV3Pool().tokens;
    // }
}
