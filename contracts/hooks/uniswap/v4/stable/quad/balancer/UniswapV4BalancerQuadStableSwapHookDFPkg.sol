// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IStandardExchangeMultiAssetLiquidity
} from "contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4BalancerQuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookRepo.sol";
import {
    UniswapV4BalancerQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookMath.sol";
import {
    UniswapV4BalancerQuadStableSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookPairPoolLib.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";
import {
    IUniswapV4BalancerQuadStableSwapHookPackage
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHookPackage.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookDFPkg
 * @notice Hook diamond package: ERC20Permit LP + MultiAsset vault + quad StableSwap facets.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      postDeploy ensures six pair doors; permissionless ensurePairPools for re-ensure.
 */
contract UniswapV4BalancerQuadStableSwapHookDFPkg is IUniswapV4BalancerQuadStableSwapHookPackage {
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("uv4-balancer-quad-stable-swap-hook");
    bytes4 public constant HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4BalancerQuadStableSwapHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IFacet public immutable HOOKS_FACET;
    IFacet public immutable LIQUIDITY_FACET;
    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IUniswapV4BalancerQuadStableSwapHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.vaultFeeOracleQuery) == address(0)
                || address(init.hooksFacet) == address(0) || address(init.liquidityFacet) == address(0)
                || address(init.erc20Facet) == address(0) || address(init.erc5267Facet) == address(0)
                || address(init.erc2612Facet) == address(0)
                || address(init.multiAssetBasicVaultFacet) == address(0)
                || address(init.multiAssetStandardVaultFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        VAULT_REGISTRY_DEPLOYMENT = init.vaultRegistryDeployment;
        VAULT_FEE_ORACLE_QUERY = init.vaultFeeOracleQuery;
        HOOKS_FACET = init.hooksFacet;
        LIQUIDITY_FACET = init.liquidityFacet;
        ERC20_FACET = init.erc20Facet;
        ERC5267_FACET = init.erc5267Facet;
        ERC2612_FACET = init.erc2612Facet;
        MULTI_ASSET_BASIC_VAULT_FACET = init.multiAssetBasicVaultFacet;
        MULTI_ASSET_STANDARD_VAULT_FACET = init.multiAssetStandardVaultFacet;
        SELF = this;
    }

    /* ----------------------- Package → Registry deploy path ----------------------- */

    function deployVault(PkgArgs memory args, uint256 mineNonce) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVault(
            IStandardVaultPkg(address(SELF)), abi.encode(args), mineNonce
        );
    }

    function deployVaultAutoMine(PkgArgs memory args) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVaultAutoMine(
            IStandardVaultPkg(address(SELF)), abi.encode(args)
        );
    }

    /* ----------------------- IUniswapV4HookDiamondPackage ----------------------- */

    function requiredHookFlags() public pure returns (uint160 flags) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
        );
    }

    function isExpectedInstance(address proxy, bytes calldata) external view returns (bool) {
        if (proxy.code.length == 0) return false;
        return (uint160(proxy) & Create2Lib.FLAG_MASK) == (requiredHookFlags() & Create2Lib.FLAG_MASK);
    }

    /* ------------------------------ DFPkg lifecycle ----------------------------- */

    function packageName() public pure returns (string memory) {
        return type(UniswapV4BalancerQuadStableSwapHookDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](7);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IBasicVault).interfaceId;
        interfaces[5] = type(IStandardVault).interfaceId;
        interfaces[6] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](7);
        facets[0] = address(ERC20_FACET);
        facets[1] = address(ERC5267_FACET);
        facets[2] = address(ERC2612_FACET);
        facets[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[5] = address(HOOKS_FACET);
        facets[6] = address(LIQUIDITY_FACET);
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

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](7);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(HOOKS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: HOOKS_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(LIQUIDITY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: LIQUIDITY_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        _validateArgs(a);
        return pkgArgs;
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        // Q12–Q16: PRODUCT_ID + poolManager + tokens + fee + amp + rateProviders.
        // Excludes package address, facets, caller, mineNonce, saltNamespace.
        return keccak256(
            abi.encode(
                PRODUCT_ID,
                a.poolManager,
                a.token0,
                a.token1,
                a.token2,
                a.token3,
                a.lpFeePips,
                a.baseAmp,
                a.rateProviders
            )
        );
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        _validateArgs(a);
        _initLpAndVault(a);
        _initProductBindings(a);
    }

    function _initLpAndVault(PkgArgs memory a) private {
        (string memory name_, string memory symbol_) =
            _buildLpMetadata(a.token0, a.token1, a.token2, a.token3);
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");

        address[] memory vaultTokens = new address[](4);
        vaultTokens[0] = a.token0;
        vaultTokens[1] = a.token1;
        vaultTokens[2] = a.token2;
        vaultTokens[3] = a.token3;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(a.token0, a.token1, a.token2, a.token3, a.lpFeePips, a.baseAmp)._hash()
        );
    }

    function _initProductBindings(PkgArgs memory a) private {
        uint8[4] memory decs;
        uint256[4] memory scales;
        decs[0] = _readDecimalsFailClosed(a.token0);
        decs[1] = _readDecimalsFailClosed(a.token1);
        decs[2] = _readDecimalsFailClosed(a.token2);
        decs[3] = _readDecimalsFailClosed(a.token3);
        scales[0] = Math.baseScaleFromDecimals(decs[0]);
        scales[1] = Math.baseScaleFromDecimals(decs[1]);
        scales[2] = Math.baseScaleFromDecimals(decs[2]);
        scales[3] = Math.baseScaleFromDecimals(decs[3]);
        Repo._initializeBindings(
            a.poolManager,
            a.token0,
            a.token1,
            a.token2,
            a.token3,
            a.lpFeePips,
            a.baseAmp,
            a.rateProviders,
            decs,
            scales
        );
    }

    /// @notice Ensure six pair doors after diamond deploy (idempotent skip-if-live).
    function postDeploy(address proxy) public returns (bool) {
        _ensure(proxy);
        return true;
    }

    /// @notice Permissionless re-ensure of all six pair doors.
    function ensurePairPools(address hook)
        external
        returns (PoolKey[6] memory poolKeys, uint8 createdCount)
    {
        uint8 already;
        (poolKeys, createdCount, already) = _ensure(hook);
        emit PairPoolsEnsured(hook, createdCount, already);
    }

    function pairPoolKeys(address hook) external view returns (PoolKey[6] memory keys) {
        IUniswapV4BalancerQuadStableSwapHook h = IUniswapV4BalancerQuadStableSwapHook(hook);
        return PairPoolLib.computeKeys(
            hook, h.token0(), h.token1(), h.token2(), h.token3(), h.lpFeePips()
        );
    }

    function _ensure(address hook)
        private
        returns (PoolKey[6] memory keys, uint8 created, uint8 already)
    {
        IUniswapV4BalancerQuadStableSwapHook h = IUniswapV4BalancerQuadStableSwapHook(hook);
        return PairPoolLib.ensureSixPairPools(
            h.poolManager(),
            hook,
            h.token0(),
            h.token1(),
            h.token2(),
            h.token3(),
            h.lpFeePips()
        );
    }

    /* ----------------------------- IStandardVaultPkg ---------------------------- */

    function name() public pure returns (string memory) {
        return "UniswapV4BalancerQuadStableSwapHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](4);
        typeIDs[0] = type(IBasicVault).interfaceId;
        typeIDs[1] = type(IStandardVault).interfaceId;
        typeIDs[2] = HOOK_VAULT_TYPE;
        typeIDs[3] = type(IStandardExchangeMultiAssetLiquidity).interfaceId;
    }

    function vaultDeclaration() public pure returns (IStandardVaultPkg.VaultPkgDeclaration memory decl) {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    /* --------------------------------- helpers --------------------------------- */

    function _validateArgs(PkgArgs memory a) private pure {
        if (
            a.poolManager == address(0) || a.token0 == address(0) || a.token1 == address(0)
                || a.token2 == address(0) || a.token3 == address(0)
        ) {
            revert ZeroAddress();
        }
        if (!(a.token0 < a.token1 && a.token1 < a.token2 && a.token2 < a.token3)) {
            revert InvalidTokenOrder();
        }
        if (a.lpFeePips == 0 || a.lpFeePips >= Math.FEE_DENOMINATOR) revert InvalidFee();
        if (a.baseAmp == 0 || a.baseAmp >= Math.MAX_AMP) revert InvalidAmp();
    }

    function _readDecimalsFailClosed(address token) private view returns (uint8 d) {
        (bool ok, bytes memory ret) =
            token.staticcall(abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        if (!ok || ret.length < 32) revert InvalidToken();
        uint256 raw = abi.decode(ret, (uint256));
        if (raw < 6 || raw > 18) revert InvalidToken();
        d = uint8(raw);
    }

    function _buildLpMetadata(address t0, address t1, address t2, address t3)
        private
        view
        returns (string memory name_, string memory symbol_)
    {
        string memory s0 = _readSymbolSoft(t0);
        string memory s1 = _readSymbolSoft(t1);
        string memory s2 = _readSymbolSoft(t2);
        string memory s3 = _readSymbolSoft(t3);
        string memory qsBody = string.concat(s0, "-", s1, "-", s2, "-", s3);
        string memory qsFull = string.concat("BQS-", qsBody);
        symbol_ = _truncateUtf8(qsFull, Math.LP_SYMBOL_MAX);
        name_ = _truncateUtf8(string.concat("Balancer QS ", qsFull), Math.LP_NAME_MAX);
    }

    function _readSymbolSoft(address token) private view returns (string memory) {
        (bool ok, bytes memory ret) =
            token.staticcall(abi.encodeWithSelector(IERC20Metadata.symbol.selector));
        if (ok && ret.length >= 64) {
            string memory s = abi.decode(ret, (string));
            if (bytes(s).length > 0) return s;
        }
        return _last4Hex(token);
    }

    function _last4Hex(address token) private pure returns (string memory) {
        bytes16 hexChars = "0123456789abcdef";
        uint160 v = uint160(token);
        bytes memory out = new bytes(4);
        out[0] = hexChars[uint8((v >> 12) & 0xf)];
        out[1] = hexChars[uint8((v >> 8) & 0xf)];
        out[2] = hexChars[uint8((v >> 4) & 0xf)];
        out[3] = hexChars[uint8(v & 0xf)];
        return string(out);
    }

    function _truncateUtf8(string memory s, uint256 maxBytes) private pure returns (string memory) {
        bytes memory b = bytes(s);
        if (b.length <= maxBytes) return s;
        uint256 end = maxBytes;
        while (end > 0 && (uint8(b[end]) & 0xC0) == 0x80) {
            --end;
        }
        bytes memory out = new bytes(end);
        for (uint256 i; i < end; ++i) {
            out[i] = b[i];
        }
        return string(out);
    }
}
