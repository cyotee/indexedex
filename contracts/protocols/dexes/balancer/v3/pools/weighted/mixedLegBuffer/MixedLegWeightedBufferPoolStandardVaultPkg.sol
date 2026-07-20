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

import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IMixedLegWeightedBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/IMixedLegWeightedBufferPool.sol";
import {MixedLegWeightedBufferPoolRepo} from
    "contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";

interface IMixedLegWeightedBufferPoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /**
     * @dev Token layout: unpairedCount unpaired tokens + pairCount buffer/share pairs.
     *      Require 2 <= unpairedCount + 2*pairCount <= 8.
     * @dev weights length == tokenCount, in Balancer address-sorted order of the final token list.
     * @dev unpairedRateProviders: address(0) => TokenType.STANDARD; non-zero => WITH_RATE.
     * @dev pairRateProviders: address(0) => deploy default SE rate provider for (vault, bufferToken).
     * @dev Unpaired tokens must not equal any pair buffer or share (Balancer forbids duplicates).
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
        uint8 unpairedCount;
        IERC20[] unpairedTokens;
        IRateProvider[] unpairedRateProviders;
        uint8 pairCount;
        IERC20[] bufferTokens;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] pairRateProviders;
        uint256[] weights;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}

contract MixedLegWeightedBufferPoolStandardVaultPkg is BalancerV3BasePoolFactory, IMixedLegWeightedBufferPoolPkg {
    using BetterEfficientHashLib for bytes;
    using SafeERC20 for IERC20;
    using SafeERC20 for BetterIERC20;
    using TokenConfigUtils for TokenConfig[];

    error NotCalledByRegistry(address caller);

    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e14;
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18;
    uint256 private constant _MIN_INVARIANT_RATIO = 70e16;
    uint256 private constant _MAX_INVARIANT_RATIO = 300e16;
    uint256 private constant _MIN_WEIGHT = 1e16;

    MixedLegWeightedBufferPoolStandardVaultPkg public immutable SELF;
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
        return type(MixedLegWeightedBufferPoolStandardVaultPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.DEX, type(IMixedLegWeightedBufferPoolPkg).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory) {
        return type(MixedLegWeightedBufferPoolStandardVaultPkg).name;
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

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        if (msg.sender != address(VAULT_REGISTRY)) revert NotCalledByRegistry(msg.sender);
        _validatePkgArgs(abi.decode(pkgArgs, (PkgArgs)));
        return pkgArgs;
    }

    function updatePkg(address expectedProxy, bytes memory pkgArgs) public virtual returns (bool) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        (TokenConfig[] memory tc,,,,,) = _prepareLayout(a);
        BalancerV3BasePoolFactoryRepo._setTokenConfigs(expectedProxy, tc);
        BalancerV3BasePoolFactoryRepo._setHooksContract(expectedProxy, expectedProxy);
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        MixedLegWeightedBufferPoolRepo.InitParams memory init = _buildInitParams(a);

        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        address[] memory tokens = _tokensFromInit(init);
        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(tokens, a.unpairedCount, a.pairCount)._hash()
        );

        string memory name_ = "BV3MixedLegWeightedBuffer";
        ERC20Repo._initialize(name_, "mlBPT", 18);
        EIP712Repo._initialize(name_, "1");
        BalancerV3PoolRepo._initialize(
            _MIN_INVARIANT_RATIO, _MAX_INVARIANT_RATIO, _MIN_SWAP_FEE_PERCENTAGE, _MAX_SWAP_FEE_PERCENTAGE, tokens
        );
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));

        MixedLegWeightedBufferPoolRepo._initialize(init);
    }

    function _buildInitParams(PkgArgs memory a)
        internal
        returns (MixedLegWeightedBufferPoolRepo.InitParams memory init)
    {
        (
            ,
            IERC20[] memory shares,
            IRateProvider[] memory pairRps,
            uint8[] memory unpairedIndices,
            uint8[] memory bufferIndices,
            uint8[] memory shareIndices
        ) = _prepareLayout(a);

        init = MixedLegWeightedBufferPoolRepo.InitParams({
            unpairedCount: a.unpairedCount,
            pairCount: a.pairCount,
            unpairedTokens: a.unpairedTokens,
            unpairedRps: a.unpairedRateProviders,
            unpairedIndices: unpairedIndices,
            bufferTokens: a.bufferTokens,
            shareTokens: shares,
            vaults: a.standardExchangeVaults,
            pairRps: pairRps,
            bufferIndices: bufferIndices,
            shareIndices: shareIndices,
            weights: a.weights,
            expectedFactory: address(SELF)
        });
    }

    function _tokensFromInit(MixedLegWeightedBufferPoolRepo.InitParams memory init)
        internal
        pure
        returns (address[] memory tokens)
    {
        uint256 n = uint256(init.unpairedCount) + uint256(init.pairCount) * 2;
        tokens = new address[](n);
        for (uint256 i; i < init.unpairedCount; ++i) {
            tokens[init.unpairedIndices[i]] = address(init.unpairedTokens[i]);
        }
        for (uint256 i; i < init.pairCount; ++i) {
            tokens[init.bufferIndices[i]] = address(init.bufferTokens[i]);
            tokens[init.shareIndices[i]] = address(init.shareTokens[i]);
        }
    }

    function _roleAccounts() internal view returns (PoolRoleAccounts memory roleAccounts) {
        address feeTo_ = address(VAULT_FEE_ORACLE.feeTo());
        roleAccounts = PoolRoleAccounts({pauseManager: feeTo_, swapFeeManager: feeTo_, poolCreator: feeTo_});
    }

    function _liquidityManagement() internal pure returns (LiquidityManagement memory lm) {
        lm = LiquidityManagement({
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
            5e16,
            false,
            _roleAccounts(),
            proxy,
            _liquidityManagement()
        );
        return true;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool) {
        pool = VAULT_REGISTRY.deployVault(IStandardVaultPkg(address(this)), abi.encode(args));
    }

    function _validatePkgArgs(PkgArgs memory a) internal pure {
        uint256 n = uint256(a.unpairedCount) + uint256(a.pairCount) * 2;
        if (n < 2 || n > 8 || a.pairCount > 4 || a.unpairedCount > 8) {
            revert IMixedLegWeightedBufferPool.InvalidTokenLayout(a.unpairedCount, a.pairCount);
        }
        if (
            a.unpairedTokens.length != a.unpairedCount || a.unpairedRateProviders.length != a.unpairedCount
                || a.bufferTokens.length != a.pairCount || a.standardExchangeVaults.length != a.pairCount
                || a.pairRateProviders.length != a.pairCount
        ) {
            revert IMixedLegWeightedBufferPool.ArrayLengthMismatch();
        }
        if (a.weights.length != n) {
            revert IMixedLegWeightedBufferPool.WeightLengthMismatch(n, a.weights.length);
        }
        uint256 sum;
        for (uint256 t; t < n; ++t) {
            if (a.weights[t] < _MIN_WEIGHT) revert IMixedLegWeightedBufferPool.InvalidWeights();
            sum += a.weights[t];
        }
        if (sum != 1e18) revert IMixedLegWeightedBufferPool.InvalidWeights();
    }

    /// @dev Working memory for address-sort + TokenConfig build (avoids stack-too-deep).
    struct LayoutWork {
        address[] all;
        uint8[] kinds; // 0=unpaired 1=buffer 2=share
        uint256[] legs;
        IERC20[] shares;
        IRateProvider[] pairRps;
        uint8[] unpairedIndices;
        uint8[] bufferIndices;
        uint8[] shareIndices;
        TokenConfig[] tc;
    }

    function _prepareLayout(PkgArgs memory a)
        internal
        returns (
            TokenConfig[] memory tc,
            IERC20[] memory shares,
            IRateProvider[] memory pairRps,
            uint8[] memory unpairedIndices,
            uint8[] memory bufferIndices,
            uint8[] memory shareIndices
        )
    {
        _validatePkgArgs(a);
        LayoutWork memory w = _allocLayoutWork(a);
        _fillPairSharesAndRps(a, w);
        _fillSortKeys(a, w);
        _sortAndCheckDuplicates(w);
        _buildTokenConfigs(a, w);
        return (w.tc, w.shares, w.pairRps, w.unpairedIndices, w.bufferIndices, w.shareIndices);
    }

    function _allocLayoutWork(PkgArgs memory a) internal pure returns (LayoutWork memory w) {
        uint256 n = uint256(a.unpairedCount) + uint256(a.pairCount) * 2;
        w.all = new address[](n);
        w.kinds = new uint8[](n);
        w.legs = new uint256[](n);
        w.shares = new IERC20[](a.pairCount);
        w.pairRps = new IRateProvider[](a.pairCount);
        w.unpairedIndices = new uint8[](a.unpairedCount);
        w.bufferIndices = new uint8[](a.pairCount);
        w.shareIndices = new uint8[](a.pairCount);
        w.tc = new TokenConfig[](n);
    }

    function _fillPairSharesAndRps(PkgArgs memory a, LayoutWork memory w) internal {
        for (uint256 i; i < a.pairCount; ++i) {
            w.shares[i] = IERC20(address(a.standardExchangeVaults[i]));
            if (address(a.pairRateProviders[i]) == address(0)) {
                w.pairRps[i] =
                    RATE_PROVIDER_PKG.deployRateProvider(a.standardExchangeVaults[i], a.bufferTokens[i]);
            } else {
                w.pairRps[i] = a.pairRateProviders[i];
            }
        }
    }

    function _fillSortKeys(PkgArgs memory a, LayoutWork memory w) internal pure {
        uint256 cursor;
        for (uint256 i; i < a.unpairedCount; ++i) {
            w.all[cursor] = address(a.unpairedTokens[i]);
            w.kinds[cursor] = 0;
            w.legs[cursor] = i;
            unchecked {
                ++cursor;
            }
        }
        for (uint256 i; i < a.pairCount; ++i) {
            w.all[cursor] = address(a.bufferTokens[i]);
            w.kinds[cursor] = 1;
            w.legs[cursor] = i;
            unchecked {
                ++cursor;
            }
            w.all[cursor] = address(w.shares[i]);
            w.kinds[cursor] = 2;
            w.legs[cursor] = i;
            unchecked {
                ++cursor;
            }
        }
    }

    function _sortAndCheckDuplicates(LayoutWork memory w) internal pure {
        uint256 n = w.all.length;
        for (uint256 i = 1; i < n; ++i) {
            address keyA = w.all[i];
            uint8 keyK = w.kinds[i];
            uint256 keyL = w.legs[i];
            uint256 j = i;
            while (j > 0 && w.all[j - 1] > keyA) {
                w.all[j] = w.all[j - 1];
                w.kinds[j] = w.kinds[j - 1];
                w.legs[j] = w.legs[j - 1];
                unchecked {
                    --j;
                }
            }
            w.all[j] = keyA;
            w.kinds[j] = keyK;
            w.legs[j] = keyL;
        }
        for (uint256 i = 1; i < n; ++i) {
            if (w.all[i] == w.all[i - 1]) {
                revert IMixedLegWeightedBufferPool.DuplicatePoolToken(w.all[i]);
            }
        }
    }

    function _buildTokenConfigs(PkgArgs memory a, LayoutWork memory w) internal pure {
        uint256 n = w.all.length;
        for (uint256 t; t < n; ++t) {
            uint256 leg = w.legs[t];
            uint8 kind = w.kinds[t];
            if (kind == 0) {
                w.unpairedIndices[leg] = uint8(t);
                w.tc[t] = _unpairedTokenConfig(a, leg);
            } else if (kind == 1) {
                w.bufferIndices[leg] = uint8(t);
                w.tc[t] = TokenConfig({
                    token: a.bufferTokens[leg],
                    tokenType: TokenType.STANDARD,
                    rateProvider: IRateProvider(address(0)),
                    paysYieldFees: false
                });
            } else {
                w.shareIndices[leg] = uint8(t);
                w.tc[t] = TokenConfig({
                    token: w.shares[leg],
                    tokenType: TokenType.WITH_RATE,
                    rateProvider: w.pairRps[leg],
                    paysYieldFees: false
                });
            }
        }
    }

    function _unpairedTokenConfig(PkgArgs memory a, uint256 leg) internal pure returns (TokenConfig memory tc) {
        IRateProvider rp = a.unpairedRateProviders[leg];
        if (address(rp) == address(0)) {
            tc = TokenConfig({
                token: a.unpairedTokens[leg],
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });
        } else {
            tc = TokenConfig({
                token: a.unpairedTokens[leg],
                tokenType: TokenType.WITH_RATE,
                rateProvider: rp,
                paysYieldFees: false
            });
        }
    }
}
