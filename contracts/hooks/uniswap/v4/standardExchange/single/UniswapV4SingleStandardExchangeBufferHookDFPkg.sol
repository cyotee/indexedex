// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookRepo.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookDFPkg
 * @notice Option B DFPkg: MultiAsset vault facets + product buffer facet.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      No LP ERC20 facets (buffer is not an LP product). Reserves stay 0.
 */
contract UniswapV4SingleStandardExchangeBufferHookDFPkg is IUniswapV4SingleStandardExchangeBufferHookPackage {
    bytes32 public constant PRODUCT_ID = keccak256("uv4-single-se-buffer-hook");
    bytes4 public constant HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4SingleStandardExchangeBufferHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IFacet public immutable PRODUCT_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IUniswapV4SingleStandardExchangeBufferHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.productFacet) == address(0)
                || address(init.multiAssetBasicVaultFacet) == address(0)
                || address(init.multiAssetStandardVaultFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        VAULT_REGISTRY_DEPLOYMENT = init.vaultRegistryDeployment;
        PRODUCT_FACET = init.productFacet;
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
        return type(UniswapV4SingleStandardExchangeBufferHookDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](5);
        interfaces[0] = type(IHooks).interfaceId;
        interfaces[1] = type(IUniswapV4SingleStandardExchangeBufferHook).interfaceId;
        interfaces[2] = type(IBasicVault).interfaceId;
        interfaces[3] = type(IStandardVault).interfaceId;
        interfaces[4] = HOOK_VAULT_TYPE;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](3);
        facets[0] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[1] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[2] = address(PRODUCT_FACET);
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
            facetAddress: address(PRODUCT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: PRODUCT_FACET.facetFuncs()
        });
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
        return keccak256(abi.encode(PRODUCT_ID, a.poolManager, a.standardExchange, a.pairToken));
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        _validateArgs(a);

        // Product bindings (wrapZeroForOne + currency order in Repo).
        Repo._initialize(a.poolManager, a.standardExchange, a.pairToken);

        // MultiAsset BasicVault: address-sorted [currency0, currency1] (O8).
        address c0 = a.pairToken < a.standardExchange ? a.pairToken : a.standardExchange;
        address c1 = a.pairToken < a.standardExchange ? a.standardExchange : a.pairToken;
        address[] memory vaultTokens = new address[](2);
        vaultTokens[0] = c0;
        vaultTokens[1] = c1;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        // StandardVault metadata (O12). No feeOracle product binding — zero.
        // bytes32(bytes4) is left-aligned in Solidity (pad right with zeros).
        bytes32 feeTypeIds = bytes32(HOOK_VAULT_TYPE);
        bytes32 contentsId_ = keccak256(abi.encode(PRODUCT_ID, a.standardExchange, a.pairToken));
        StandardVaultRepo._initialize(
            IVaultFeeOracleQuery(address(0)), feeTypeIds, vaultTypes(), contentsId_
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    /* ----------------------------- IStandardVaultPkg ---------------------------- */

    function name() public pure returns (string memory) {
        return "UniswapV4SingleStandardExchangeBufferHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(HOOK_VAULT_TYPE);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](5);
        typeIDs[0] = type(IHooks).interfaceId;
        typeIDs[1] = type(IUniswapV4SingleStandardExchangeBufferHook).interfaceId;
        typeIDs[2] = type(IBasicVault).interfaceId;
        typeIDs[3] = type(IStandardVault).interfaceId;
        typeIDs[4] = HOOK_VAULT_TYPE;
    }

    function vaultDeclaration() public pure returns (IStandardVaultPkg.VaultPkgDeclaration memory decl) {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    /* --------------------------------- helpers --------------------------------- */

    function _validateArgs(PkgArgs memory a) private view {
        if (a.poolManager == address(0) || a.standardExchange == address(0) || a.pairToken == address(0)) {
            revert ZeroAddress();
        }
        if (a.pairToken == a.standardExchange) revert SameToken();
        _requirePairInVaultTokens(a.standardExchange, a.pairToken);
    }

    function _requirePairInVaultTokens(address se, address pair) private view {
        address[] memory tokens = IBasicVault(se).vaultTokens();
        bool found;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == pair) {
                found = true;
                break;
            }
        }
        if (!found) revert InvalidPairToken();
    }
}
