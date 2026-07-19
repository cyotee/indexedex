// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

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

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {BetterAddress as Address} from "@crane/contracts/utils/BetterAddress.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

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

import {VaultFeeType, VaultFeeTypeIds} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IMultiPairStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/IMultiPairStandardExchangeBufferPool.sol";
import {MultiPairStandardExchangeBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferPoolRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";

interface IMultiPairStandardExchangeBufferPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /**
     * @dev weights: length == 2 * pairCount, in Balancer address-sorted order of
     *      the final pool token list (bufferToken[i] and vaultShare[i] for each pair,
     *      sorted by address). Each weight >= 1e16; sum == 1e18.
     * @dev rateProviders: address(0) deploys default SE rate provider for (vault, bufferToken).
     */
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
        uint8 pairCount;
        IERC20[] bufferTokens;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] rateProviders;
        uint256[] weights;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}

contract MultiPairStandardExchangeBufferPoolStandardVaultPkg is
    BalancerV3BasePoolFactory,
    IMultiPairStandardExchangeBufferPoolPkg
{
    using Address for address[];
    using BetterEfficientHashLib for bytes;
    using SafeERC20 for IERC20;
    using SafeERC20 for BetterIERC20;
    using TokenConfigUtils for TokenConfig[];

    error NotCalledByRegistry(address caller);

    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e14;
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18;
    // L26: normal weighted pool invariant ratio bounds
    uint256 private constant _MIN_INVARIANT_RATIO = 70e16;
    uint256 private constant _MAX_INVARIANT_RATIO = 300e16;
    uint256 private constant _MIN_WEIGHT = 1e16;

    MultiPairStandardExchangeBufferPoolStandardVaultPkg public immutable SELF;

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
        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);
    }

    function _diamondPkgFactory() internal view virtual override returns (IDiamondPackageCallBackFactory) {
        return DIAMOND_PACKAGE_FACTORY;
    }

    /// forge-lint: disable-next-line(mixed-case-function)
    function _poolDFPkg() internal view virtual override returns (IDiamondFactoryPackage) {
        return IDiamondFactoryPackage(this);
    }

    function name() public pure returns (string memory) {
        return type(MultiPairStandardExchangeBufferPoolStandardVaultPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.DEX, type(IMultiPairStandardExchangeBufferPoolPkg).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory name_) {
        return type(MultiPairStandardExchangeBufferPoolStandardVaultPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](15);
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
        interfaces[13] = type(IPoolLiquidity).interfaceId;
        interfaces[14] = type(IHooks).interfaceId;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](11);
        facetAddresses_[0] = address(BASIC_VAULT_FACET);
        facetAddresses_[1] = address(STANDARD_VAULT_FACET);
        facetAddresses_[2] = address(BALANCER_V3_VAULT_AWARE_FACET);
        facetAddresses_[3] = address(BETTER_BALANCER_V3_POOL_TOKEN_FACET);
        facetAddresses_[4] = address(DEFAULT_POOL_INFO_FACET);
        facetAddresses_[5] = address(STANDARD_SWAP_FEE_PERCENTAGE_BOUNDS_FACET);
        facetAddresses_[6] = address(UNBALANCED_LIQUIDITY_INVARIANT_RATIO_BOUNDS_FACET);
        facetAddresses_[7] = address(BALANCER_V3_AUTHENTICATION_FACET);
        facetAddresses_[8] = address(BUFFER_POOL_FACET);
        facetAddresses_[9] = address(POOL_LIQUIDITY_FACET);
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
        _validatePkgArgs(abi.decode(pkgArgs, (PkgArgs)));
        return pkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public virtual returns (bool) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        (,, TokenConfig[] memory tc,,) = _preparePairsFull(a);
        BalancerV3BasePoolFactoryRepo._setTokenConfigs(expectedProxy, tc);
        // L5: hooks live on the pool proxy
        BalancerV3BasePoolFactoryRepo._setHooksContract(expectedProxy, expectedProxy);
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        (
            IERC20[] memory shares,
            IRateProvider[] memory rps,
            ,
            uint8[] memory bufferIndices,
            uint8[] memory shareIndices
        ) = _preparePairsFull(a);

        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        uint256 n = uint256(a.pairCount) * 2;
        address[] memory tokens = new address[](n);
        for (uint256 i; i < a.pairCount; ++i) {
            tokens[bufferIndices[i]] = address(a.bufferTokens[i]);
            tokens[shareIndices[i]] = address(shares[i]);
        }

        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE,
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(tokens, a.pairCount)._hash()
        );

        string memory name_ = "BV3MultiPairStdExchBuffer";
        ERC20Repo._initialize(name_, "mpBPT", 18);
        EIP712Repo._initialize(name_, "1");
        BalancerV3PoolRepo._initialize(
            _MIN_INVARIANT_RATIO,
            _MAX_INVARIANT_RATIO,
            _MIN_SWAP_FEE_PERCENTAGE,
            _MAX_SWAP_FEE_PERCENTAGE,
            tokens
        );
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));

        MultiPairStandardExchangeBufferPoolRepo._initialize(
            a.pairCount,
            a.bufferTokens,
            shares,
            a.standardExchangeVaults,
            rps,
            bufferIndices,
            shareIndices,
            a.weights,
            address(SELF)
        );
    }

    function _roleAccounts() internal view returns (PoolRoleAccounts memory roleAccounts) {
        address feeTo_ = address(VAULT_FEE_ORACLE.feeTo());
        roleAccounts = PoolRoleAccounts({pauseManager: feeTo_, swapFeeManager: feeTo_, poolCreator: feeTo_});
    }

    function _liquidityManagement() internal pure returns (LiquidityManagement memory liquidityManagement) {
        liquidityManagement = LiquidityManagement({
            disableUnbalancedLiquidity: false,
            enableAddLiquidityCustom: true,
            enableRemoveLiquidityCustom: true,
            enableDonation: true
        });
    }

    function postDeploy(address proxy) public returns (bool) {
        _registerPoolWithBalV3Vault(
            proxy,
            BalancerV3BasePoolFactoryRepo._getTokenConfigs(proxy),
            5e16, // 0.05% default static fee
            false,
            _roleAccounts(),
            proxy, // L5 hooksContract == pool
            _liquidityManagement()
        );
        return true;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool) {
        pool = VAULT_REGISTRY.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    /* ----- Internal ----- */

    function _validatePkgArgs(PkgArgs memory a) internal pure {
        if (a.pairCount < 1 || a.pairCount > 4) {
            revert IMultiPairStandardExchangeBufferPool.InvalidPairCount(a.pairCount);
        }
        if (
            a.bufferTokens.length != a.pairCount || a.standardExchangeVaults.length != a.pairCount
                || a.rateProviders.length != a.pairCount
        ) {
            revert IMultiPairStandardExchangeBufferPool.ArrayLengthMismatch();
        }
        uint256 n = uint256(a.pairCount) * 2;
        if (a.weights.length != n) {
            revert IMultiPairStandardExchangeBufferPool.WeightLengthMismatch(n, a.weights.length);
        }
        uint256 sum;
        for (uint256 t; t < n; ++t) {
            if (a.weights[t] < _MIN_WEIGHT) {
                revert IMultiPairStandardExchangeBufferPool.InvalidWeights();
            }
            sum += a.weights[t];
        }
        if (sum != 1e18) revert IMultiPairStandardExchangeBufferPool.InvalidWeights();

        for (uint256 i; i < a.pairCount; ++i) {
            for (uint256 j = i + 1; j < a.pairCount; ++j) {
                if (address(a.bufferTokens[i]) == address(a.bufferTokens[j])) {
                    revert IMultiPairStandardExchangeBufferPool.DuplicateBufferToken(address(a.bufferTokens[i]));
                }
                if (address(a.standardExchangeVaults[i]) == address(a.standardExchangeVaults[j])) {
                    revert IMultiPairStandardExchangeBufferPool.DuplicateVaultShare(
                        address(a.standardExchangeVaults[i])
                    );
                }
            }
            // vault-as-share vs buffer uniqueness across all pool tokens
            address share_ = address(a.standardExchangeVaults[i]);
            if (share_ == address(a.bufferTokens[i])) {
                revert IMultiPairStandardExchangeBufferPool.DuplicatePoolToken(share_);
            }
            for (uint256 j; j < a.pairCount; ++j) {
                if (i != j && share_ == address(a.bufferTokens[j])) {
                    revert IMultiPairStandardExchangeBufferPool.DuplicatePoolToken(share_);
                }
            }
        }
    }

    function _preparePairsFull(PkgArgs memory a)
        internal
        returns (
            IERC20[] memory shares,
            IRateProvider[] memory rps,
            TokenConfig[] memory tc,
            uint8[] memory bufferIndices,
            uint8[] memory shareIndices
        )
    {
        _validatePkgArgs(a);
        shares = new IERC20[](a.pairCount);
        rps = new IRateProvider[](a.pairCount);
        for (uint256 i; i < a.pairCount; ++i) {
            shares[i] = IERC20(address(a.standardExchangeVaults[i]));
            if (address(a.rateProviders[i]) == address(0)) {
                rps[i] = RATE_PROVIDER_PKG.deployRateProvider(a.standardExchangeVaults[i], a.bufferTokens[i]);
            } else {
                rps[i] = a.rateProviders[i];
            }
        }

        // Build unsorted then assign Balancer-sorted indices.
        // Collect all token addresses and sort.
        uint256 n = uint256(a.pairCount) * 2;
        address[] memory all = new address[](n);
        bool[] memory isBuffer = new bool[](n);
        uint256[] memory pairOf = new uint256[](n);
        for (uint256 i; i < a.pairCount; ++i) {
            all[i * 2] = address(a.bufferTokens[i]);
            isBuffer[i * 2] = true;
            pairOf[i * 2] = i;
            all[i * 2 + 1] = address(shares[i]);
            isBuffer[i * 2 + 1] = false;
            pairOf[i * 2 + 1] = i;
        }
        // Insertion sort by address
        for (uint256 i = 1; i < n; ++i) {
            address key = all[i];
            bool keyB = isBuffer[i];
            uint256 keyP = pairOf[i];
            uint256 j = i;
            while (j > 0 && all[j - 1] > key) {
                all[j] = all[j - 1];
                isBuffer[j] = isBuffer[j - 1];
                pairOf[j] = pairOf[j - 1];
                unchecked {
                    --j;
                }
            }
            all[j] = key;
            isBuffer[j] = keyB;
            pairOf[j] = keyP;
        }

        // Detect duplicate addresses after sort
        for (uint256 i = 1; i < n; ++i) {
            if (all[i] == all[i - 1]) {
                revert IMultiPairStandardExchangeBufferPool.DuplicatePoolToken(all[i]);
            }
        }

        bufferIndices = new uint8[](a.pairCount);
        shareIndices = new uint8[](a.pairCount);
        tc = new TokenConfig[](n);
        for (uint256 t; t < n; ++t) {
            uint256 p = pairOf[t];
            if (isBuffer[t]) {
                bufferIndices[p] = uint8(t);
                tc[t] = TokenConfig({
                    token: a.bufferTokens[p],
                    tokenType: TokenType.STANDARD,
                    rateProvider: IRateProvider(address(0)),
                    paysYieldFees: false
                });
            } else {
                shareIndices[p] = uint8(t);
                tc[t] = TokenConfig({
                    token: shares[p],
                    tokenType: TokenType.WITH_RATE,
                    rateProvider: rps[p],
                    paysYieldFees: false
                });
            }
        }
    }
}
