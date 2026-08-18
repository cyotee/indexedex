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
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg
 * @notice Option B DFPkg: vault pair + package-as-init at deploy; production facets at finalize.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      Salt sorts legs by pair-token address so free ctor order yields the same instance.
 *      postDeploy stays public pure. Product door via deployPair; ABI via finalizeInitialization.
 *      M3: seFacet declares IStandardExchangeIn / Out for pair0↔pair1.
 */
contract UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg is
    UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet,
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
{
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("uv4-dual-se-buffer-constant-product-hook");
    bytes4 public constant HOOK_VAULT_TYPE =
        bytes4(keccak256("UniswapV4DualStandardExchangeBufferConstantProductHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IFacet public immutable HOOKS_FACET;
    IFacet public immutable DEPOSIT_FACET;
    IFacet public immutable WITHDRAW_FACET;
    IFacet public immutable SE_FACET;
    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.vaultFeeOracleQuery) == address(0)
                || address(init.hooksFacet) == address(0) || address(init.depositFacet) == address(0)
                || address(init.withdrawFacet) == address(0) || address(init.seFacet) == address(0)
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
        DEPOSIT_FACET = init.depositFacet;
        WITHDRAW_FACET = init.withdrawFacet;
        SE_FACET = init.seFacet;
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
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    function isExpectedInstance(address proxy, bytes calldata) external view returns (bool) {
        if (proxy.code.length == 0) return false;
        return (uint160(proxy) & Create2Lib.FLAG_MASK) == (requiredHookFlags() & Create2Lib.FLAG_MASK);
    }

    /* ------------------------------ DFPkg lifecycle ----------------------------- */

    function packageName() public pure returns (string memory) {
        return type(UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg).name;
    }

    function facetInterfaces()
        public
        pure
        override(IDiamondFactoryPackage, UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet)
        returns (bytes4[] memory interfaces)
    {
        // ERC20Permit + vault + product type + M3 SE In/Out.
        interfaces = new bytes4[](9);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IBasicVault).interfaceId;
        interfaces[5] = type(IStandardVault).interfaceId;
        interfaces[6] = type(IStandardExchangeIn).interfaceId;
        interfaces[7] = type(IStandardExchangeOut).interfaceId;
        interfaces[8] = HOOK_VAULT_TYPE;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](10);
        facets[0] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[2] = address(SELF);
        facets[3] = address(HOOKS_FACET);
        facets[4] = address(DEPOSIT_FACET);
        facets[5] = address(WITHDRAW_FACET);
        facets[6] = address(SE_FACET);
        facets[7] = address(ERC20_FACET);
        facets[8] = address(ERC5267_FACET);
        facets[9] = address(ERC2612_FACET);
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
        cuts = new IDiamond.FacetCut[](3);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_BASIC_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_BASIC_VAULT_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(MULTI_ASSET_STANDARD_VAULT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: MULTI_ASSET_STANDARD_VAULT_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(SELF),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: facetFuncs()
        });
    }

    function productionFacetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](7);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(HOOKS_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: HOOKS_FACET.facetFuncs()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(DEPOSIT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: DEPOSIT_FACET.facetFuncs()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(WITHDRAW_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: WITHDRAW_FACET.facetFuncs()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(SE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SE_FACET.facetFuncs()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(ERC20_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC20_FACET.facetFuncs()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(ERC5267_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC5267_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(ERC2612_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ERC2612_FACET.facetFuncs()
        });
    }

    function finalizeInitialization() public override nonReentrant returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (l.initializationFinalized) revert InitializationAlreadyFinalized();
        if (!isPairPoolLive(l.currency0, l.currency1)) {
            revert ProductDoorsNotLive();
        }

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](8);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(SELF),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: facetFuncs()
        });
        IDiamond.FacetCut[] memory adds = productionFacetCuts();
        cuts[1] = adds[0];
        cuts[2] = adds[1];
        cuts[3] = adds[2];
        cuts[4] = adds[3];
        cuts[5] = adds[4];
        cuts[6] = adds[5];
        cuts[7] = adds[6];

        ERC2535Repo._processFacetCuts(cuts);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        emit InitializationFinalized(address(this));
        l.initializationFinalized = true;
        return true;
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        _validateArgs(a);
        return pkgArgs;
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory a = abi.decode(pkgArgs, (PkgArgs));
        // Token-address-sorted legs so free ctor order → same salt (D14–D16).
        (address seLo, address tLo, address seHi, address tHi) = a.token0 < a.token1
            ? (a.standardExchange0, a.token0, a.standardExchange1, a.token1)
            : (a.standardExchange1, a.token1, a.standardExchange0, a.token0);
        return keccak256(abi.encode(PRODUCT_ID, a.poolManager, a.feeOracle, seLo, tLo, seHi, tHi));
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
        address c0 = a.token0 < a.token1 ? a.token0 : a.token1;
        address c1 = a.token0 < a.token1 ? a.token1 : a.token0;

        string memory name_ = string.concat("Dual SE Buffer CP ", _safeSymbol(c0), "/", _safeSymbol(c1));
        string memory symbol_ = string.concat("DSEBCP-", _safeSymbol(c0), "-", _safeSymbol(c1));
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");

        address[] memory vaultTokens = new address[](2);
        vaultTokens[0] = c0;
        vaultTokens[1] = c1;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY,
            vaultFeeTypeIds(),
            vaultTypes(),
            abi.encode(a.standardExchange0, a.token0, a.standardExchange1, a.token1)._hash()
        );
    }

    function _initProductBindings(PkgArgs memory a) private {
        address c0 = a.token0 < a.token1 ? a.token0 : a.token1;
        address c1 = a.token0 < a.token1 ? a.token1 : a.token0;
        Repo._initializeBindings(
            a.poolManager,
            a.feeOracle,
            a.standardExchange0,
            a.token0,
            a.standardExchange1,
            a.token1,
            c0,
            c1,
            _readDecimals(c0),
            _readDecimals(c1)
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    /* ----------------------------- IStandardVaultPkg ---------------------------- */

    function name() public pure returns (string memory) {
        return "UniswapV4DualStandardExchangeBufferConstantProductHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](3);
        typeIDs[0] = type(IBasicVault).interfaceId;
        typeIDs[1] = type(IStandardVault).interfaceId;
        typeIDs[2] = HOOK_VAULT_TYPE;
    }

    function vaultDeclaration() public pure returns (IStandardVaultPkg.VaultPkgDeclaration memory decl) {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    /* --------------------------------- helpers --------------------------------- */

    function _validateArgs(PkgArgs memory a) private view {
        if (
            a.poolManager == address(0) || a.feeOracle == address(0)
                || a.standardExchange0 == address(0) || a.token0 == address(0)
                || a.standardExchange1 == address(0) || a.token1 == address(0)
        ) {
            revert ZeroAddress();
        }
        if (a.standardExchange0 == a.standardExchange1) revert SameStandardExchange();
        if (a.token0 == a.token1) revert SamePairToken();
        _requireTokenInVaultTokens(a.standardExchange0, a.token0);
        _requireTokenInVaultTokens(a.standardExchange1, a.token1);
    }

    function _requireTokenInVaultTokens(address se, address token) private view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == token) return;
        }
        revert TokenNotInVaultTokens();
    }

    function _readDecimals(address token) private view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _safeSymbol(address token) private view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return "TKN";
        }
    }
}
