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
import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
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
import {
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {
    CommonBufferMultiVaultStablePoolRepo
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolRepo.sol";
import {
    IStandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";

interface ICommonBufferMultiVaultStablePoolPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    /**
     * @dev T = 1 + vaultCount, require 1 <= vaultCount <= 3 (2 <= T <= 4).
     * @dev vaultShareRateProviders: address(0) => STANDARD; non-zero => WITH_RATE.
     *      Package NEVER auto-deploys default SE rate providers.
     * @dev amplificationParameter: raw amp (1–50000), fixed at deploy (no post-deploy updates).
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
        IStandardExchangeRateProviderDFPkg rateProviderPkg; // optional; never auto-used on zero args
    }

    struct PkgArgs {
        IERC20 bufferToken;
        uint8 vaultCount;
        IStandardExchange[] standardExchangeVaults;
        IRateProvider[] vaultShareRateProviders;
        uint256 amplificationParameter;
    }

    function deployPool(PkgArgs calldata args) external returns (address pool);
}

contract CommonBufferMultiVaultStablePoolStandardVaultPkg is
    BalancerV3BasePoolFactory,
    ICommonBufferMultiVaultStablePoolPkg
{
    using BetterEfficientHashLib for bytes;
    using SafeERC20 for IERC20;
    using SafeERC20 for BetterIERC20;
    using TokenConfigUtils for TokenConfig[];

    error NotCalledByRegistry(address caller);

    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e14;
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 0.1e18;
    // StableMath invariant ratio bounds (not weighted).
    uint256 private constant _MIN_INVARIANT_RATIO = 60e16;
    uint256 private constant _MAX_INVARIANT_RATIO = 500e16;

    CommonBufferMultiVaultStablePoolStandardVaultPkg public immutable SELF;
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
        return type(CommonBufferMultiVaultStablePoolStandardVaultPkg).name;
    }

    function vaultFeeTypeIds() public pure returns (bytes32 vaultFeeTypeIds_) {
        return VaultTypeUtils._insertFeeTypeId(
            vaultFeeTypeIds_, VaultFeeType.DEX, type(ICommonBufferMultiVaultStablePoolPkg).interfaceId
        );
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        return facetInterfaces();
    }

    function vaultDeclaration() public pure returns (VaultPkgDeclaration memory declaration) {
        return VaultPkgDeclaration({name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()});
    }

    function packageName() public pure returns (string memory) {
        return type(CommonBufferMultiVaultStablePoolStandardVaultPkg).name;
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
        (TokenConfig[] memory tc,,,,) = _prepareLayout(a);
        BalancerV3BasePoolFactoryRepo._setTokenConfigs(expectedProxy, tc);
        BalancerV3BasePoolFactoryRepo._setHooksContract(expectedProxy, expectedProxy);
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        CommonBufferMultiVaultStablePoolRepo.InitParams memory init = _buildInitParams(a);

        BalancerV3VaultAwareRepo._initialize(BALANCER_V3_VAULT);

        address[] memory tokens = _tokensFromInit(init);
        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE, vaultFeeTypeIds(), vaultTypes(), abi.encode(tokens, a.vaultCount)._hash()
        );

        string memory name_ = "BV3CommonBufferMultiVaultStable";
        ERC20Repo._initialize(name_, "cbmvsBPT", 18);
        EIP712Repo._initialize(name_, "1");
        BalancerV3PoolRepo._initialize(
            _MIN_INVARIANT_RATIO, _MAX_INVARIANT_RATIO, _MIN_SWAP_FEE_PERCENTAGE, _MAX_SWAP_FEE_PERCENTAGE, tokens
        );
        BalancerV3AuthenticationRepo._initialize(keccak256(abi.encode(address(this))));

        CommonBufferMultiVaultStablePoolRepo._initialize(init);
    }

    function _buildInitParams(PkgArgs memory a)
        internal
        view
        returns (CommonBufferMultiVaultStablePoolRepo.InitParams memory init)
    {
        (, IERC20[] memory shares, IRateProvider[] memory shareRps, uint8 bufferIndex, uint8[] memory shareIndices) =
            _prepareLayout(a);

        init = CommonBufferMultiVaultStablePoolRepo.InitParams({
            vaultCount: a.vaultCount,
            bufferToken: a.bufferToken,
            bufferIndex: bufferIndex,
            shareTokens: shares,
            vaults: a.standardExchangeVaults,
            vaultShareRps: shareRps,
            shareIndices: shareIndices,
            amplificationParameter: a.amplificationParameter,
            expectedFactory: address(SELF)
        });
    }

    function _tokensFromInit(CommonBufferMultiVaultStablePoolRepo.InitParams memory init)
        internal
        pure
        returns (address[] memory tokens)
    {
        uint256 n = 1 + uint256(init.vaultCount);
        tokens = new address[](n);
        tokens[init.bufferIndex] = address(init.bufferToken);
        for (uint256 i; i < init.vaultCount; ++i) {
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

    function _validatePkgArgs(PkgArgs memory a) internal view {
        if (a.vaultCount == 0 || a.vaultCount > 3) {
            revert ICommonBufferMultiVaultStablePool.InvalidTokenLayout(a.vaultCount);
        }
        if (a.standardExchangeVaults.length != a.vaultCount || a.vaultShareRateProviders.length != a.vaultCount) {
            revert ICommonBufferMultiVaultStablePool.ArrayLengthMismatch();
        }
        if (a.amplificationParameter < StableMath.MIN_AMP) {
            revert ICommonBufferMultiVaultStablePool.AmplificationFactorTooLow();
        }
        if (a.amplificationParameter > StableMath.MAX_AMP) {
            revert ICommonBufferMultiVaultStablePool.AmplificationFactorTooHigh();
        }

        // S9: each vault must accept+produce bufferToken.
        for (uint256 i; i < a.vaultCount; ++i) {
            if (!_vaultAcceptsAndProducesBuffer(a.standardExchangeVaults[i], a.bufferToken)) {
                revert ICommonBufferMultiVaultStablePool.BufferTokenNotInVault(
                    address(a.bufferToken), address(a.standardExchangeVaults[i])
                );
            }
        }
    }

    function _vaultAcceptsAndProducesBuffer(IStandardExchange vault, IERC20 buffer) internal view returns (bool) {
        IERC20 share = IERC20(address(vault));
        if (_tokenListContainsVault(address(vault), address(buffer))) return true;
        try vault.previewExchangeIn(buffer, 1e18, share) returns (uint256 minted) {
            if (minted == 0) return false;
        } catch {
            return false;
        }
        try vault.previewExchangeOut(share, buffer, 1e15) returns (uint256 sharesIn) {
            return sharesIn > 0;
        } catch {
            return false;
        }
    }

    function _tokenListContainsVault(address vault, address buffer) internal view returns (bool) {
        try IBasicVault(vault).vaultTokens() returns (address[] memory toks) {
            for (uint256 i; i < toks.length; ++i) {
                if (toks[i] == buffer) return true;
            }
        } catch {}
        try IStandardVault(vault).vaultConfig() returns (IStandardVault.VaultConfig memory cfg) {
            for (uint256 i; i < cfg.tokens.length; ++i) {
                if (cfg.tokens[i] == buffer) return true;
            }
        } catch {}
        return false;
    }

    struct LayoutWork {
        address[] all;
        uint8[] kinds; // 0=buffer 1=share
        uint256[] legs;
        IERC20[] shares;
        IRateProvider[] shareRps;
        uint8 bufferIndex;
        uint8[] shareIndices;
        TokenConfig[] tc;
    }

    function _prepareLayout(PkgArgs memory a)
        internal
        view
        returns (
            TokenConfig[] memory tc,
            IERC20[] memory shares,
            IRateProvider[] memory shareRps,
            uint8 bufferIndex,
            uint8[] memory shareIndices
        )
    {
        _validatePkgArgs(a);
        LayoutWork memory w = _allocLayoutWork(a);
        _fillSharesAndRps(a, w);
        _fillSortKeys(a, w);
        _sortAndCheckDuplicates(w);
        _buildTokenConfigs(a, w);
        return (w.tc, w.shares, w.shareRps, w.bufferIndex, w.shareIndices);
    }

    function _allocLayoutWork(PkgArgs memory a) internal pure returns (LayoutWork memory w) {
        uint256 n = 1 + uint256(a.vaultCount);
        w.all = new address[](n);
        w.kinds = new uint8[](n);
        w.legs = new uint256[](n);
        w.shares = new IERC20[](a.vaultCount);
        w.shareRps = new IRateProvider[](a.vaultCount);
        w.shareIndices = new uint8[](a.vaultCount);
        w.tc = new TokenConfig[](n);
    }

    function _fillSharesAndRps(PkgArgs memory a, LayoutWork memory w) internal pure {
        for (uint256 i; i < a.vaultCount; ++i) {
            w.shares[i] = IERC20(address(a.standardExchangeVaults[i]));
            w.shareRps[i] = a.vaultShareRateProviders[i];
        }
    }

    function _fillSortKeys(PkgArgs memory a, LayoutWork memory w) internal pure {
        uint256 cursor;
        w.all[cursor] = address(a.bufferToken);
        w.kinds[cursor] = 0;
        w.legs[cursor] = 0;
        unchecked {
            ++cursor;
        }
        for (uint256 i; i < a.vaultCount; ++i) {
            w.all[cursor] = address(w.shares[i]);
            w.kinds[cursor] = 1;
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
                revert ICommonBufferMultiVaultStablePool.DuplicatePoolToken(w.all[i]);
            }
        }
    }

    function _buildTokenConfigs(PkgArgs memory a, LayoutWork memory w) internal pure {
        uint256 n = w.all.length;
        for (uint256 t; t < n; ++t) {
            uint256 leg = w.legs[t];
            uint8 kind = w.kinds[t];
            if (kind == 0) {
                w.bufferIndex = uint8(t);
                w.tc[t] = TokenConfig({
                    token: a.bufferToken,
                    tokenType: TokenType.STANDARD,
                    rateProvider: IRateProvider(address(0)),
                    paysYieldFees: false
                });
            } else {
                w.shareIndices[leg] = uint8(t);
                w.tc[t] = _optionalRateTokenConfig(w.shares[leg], w.shareRps[leg]);
            }
        }
    }

    function _optionalRateTokenConfig(IERC20 token, IRateProvider rp) internal pure returns (TokenConfig memory tc) {
        if (address(rp) == address(0)) {
            tc = TokenConfig({
                token: token,
                tokenType: TokenType.STANDARD,
                rateProvider: IRateProvider(address(0)),
                paysYieldFees: false
            });
        } else {
            tc = TokenConfig({token: token, tokenType: TokenType.WITH_RATE, rateProvider: rp, paysYieldFees: false});
        }
    }
}
