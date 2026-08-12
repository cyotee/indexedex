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
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
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
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg
 * @notice Option B DFPkg: ERC20Permit LP facets + MultiAsset vault facets + product facets.
 * @dev deployVault → registry.deployHookVault → hook CREATE2 factory. Salt excludes package address.
 *      LP token = proxy: cut ERC20 + ERC5267 + ERC2612 (ERC20PermitDFPkg parity) then vault/product.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg is IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage {
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("uv4-single-se-buffer-constant-product-hook");
    bytes4 public constant HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4SingleStandardExchangeBufferConstantProductHook"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IVaultFeeOracleQuery public immutable VAULT_FEE_ORACLE_QUERY;
    IFacet public immutable SE_FACET;
    IFacet public immutable DEPOSIT_FACET;
    IFacet public immutable WITHDRAW_FACET;
    IFacet public immutable ERC20_FACET;
    IFacet public immutable ERC5267_FACET;
    IFacet public immutable ERC2612_FACET;
    IFacet public immutable MULTI_ASSET_BASIC_VAULT_FACET;
    IFacet public immutable MULTI_ASSET_STANDARD_VAULT_FACET;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage private immutable SELF;

    constructor(PkgInit memory init) {
        if (
            address(init.vaultRegistryDeployment) == address(0)
                || address(init.vaultFeeOracleQuery) == address(0)
                || address(init.seFacet) == address(0) || address(init.depositFacet) == address(0)
                || address(init.withdrawFacet) == address(0) || address(init.erc20Facet) == address(0)
                || address(init.erc5267Facet) == address(0) || address(init.erc2612Facet) == address(0)
                || address(init.multiAssetBasicVaultFacet) == address(0)
                || address(init.multiAssetStandardVaultFacet) == address(0)
        ) {
            revert ZeroAddress();
        }
        VAULT_REGISTRY_DEPLOYMENT = init.vaultRegistryDeployment;
        VAULT_FEE_ORACLE_QUERY = init.vaultFeeOracleQuery;
        SE_FACET = init.seFacet;
        DEPOSIT_FACET = init.depositFacet;
        WITHDRAW_FACET = init.withdrawFacet;
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
        return type(UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        // ERC20PermitDFPkg interfaces + vault/SE + product type.
        interfaces = new bytes4[](9);
        interfaces[0] = type(IERC20).interfaceId;
        interfaces[1] = type(IERC20Metadata).interfaceId;
        interfaces[2] = type(IERC20Permit).interfaceId;
        interfaces[3] = type(IERC5267).interfaceId;
        interfaces[4] = type(IStandardExchangeIn).interfaceId;
        interfaces[5] = type(IStandardExchangeOut).interfaceId;
        interfaces[6] = type(IBasicVault).interfaceId;
        interfaces[7] = type(IStandardVault).interfaceId;
        interfaces[8] = HOOK_VAULT_TYPE;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](8);
        facets[0] = address(ERC20_FACET);
        facets[1] = address(ERC5267_FACET);
        facets[2] = address(ERC2612_FACET);
        facets[3] = address(MULTI_ASSET_BASIC_VAULT_FACET);
        facets[4] = address(MULTI_ASSET_STANDARD_VAULT_FACET);
        facets[5] = address(SE_FACET);
        facets[6] = address(DEPOSIT_FACET);
        facets[7] = address(WITHDRAW_FACET);
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
        // LP = ERC20PermitDFPkg facets, then MultiAsset vault, then product size-split.
        cuts = new IDiamond.FacetCut[](8);
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
            facetAddress: address(SE_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: SE_FACET.facetFuncs()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(DEPOSIT_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: DEPOSIT_FACET.facetFuncs()
        });
        cuts[7] = IDiamond.FacetCut({
            facetAddress: address(WITHDRAW_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: WITHDRAW_FACET.facetFuncs()
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
        return keccak256(
            abi.encode(
                PRODUCT_ID, a.poolManager, a.feeOracle, a.standardExchange, a.pairToken, a.rawToken
            )
        );
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory a = abi.decode(initArgs, (PkgArgs));
        _validateArgs(a);

        address c0 = a.rawToken < a.pairToken ? a.rawToken : a.pairToken;
        address c1 = a.rawToken < a.pairToken ? a.pairToken : a.rawToken;
        uint8 d0 = IERC20Metadata(c0).decimals();
        uint8 d1 = IERC20Metadata(c1).decimals();

        string memory sym0 = _safeSymbol(c0);
        string memory sym1 = _safeSymbol(c1);
        string memory name_ = string.concat("SSEBCP-", sym0, "-", sym1);
        string memory symbol_ = string.concat("SSEBCP-", sym0, sym1);

        // Shared ERC20 + EIP-712 (ERC20PermitDFPkg parity; LP = this proxy).
        ERC20Repo._initialize(name_, symbol_, 18);
        EIP712Repo._initialize(name_, "1");

        // Shared MultiAsset BasicVault tokens (pool-order).
        address[] memory vaultTokens = new address[](2);
        vaultTokens[0] = c0;
        vaultTokens[1] = c1;
        MultiAssetBasicVaultRepo._initialize(vaultTokens);

        // Shared StandardVault metadata.
        bytes32 contentsId_ =
            abi.encode(a.rawToken, a.pairToken, a.standardExchange)._hash();
        StandardVaultRepo._initialize(
            VAULT_FEE_ORACLE_QUERY, vaultFeeTypeIds(), vaultTypes(), contentsId_
        );

        // Product bindings.
        Repo._initializeBindings(
            a.poolManager, a.feeOracle, a.standardExchange, a.pairToken, a.rawToken, c0, c1, d0, d1
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    /* ----------------------------- IStandardVaultPkg ---------------------------- */

    function name() public pure returns (string memory) {
        return "UniswapV4SingleStandardExchangeBufferConstantProductHook";
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](5);
        typeIDs[0] = type(IStandardExchangeIn).interfaceId;
        typeIDs[1] = type(IStandardExchangeOut).interfaceId;
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

    function _validateArgs(PkgArgs memory a) private pure {
        if (
            a.poolManager == address(0) || a.feeOracle == address(0) || a.standardExchange == address(0)
                || a.pairToken == address(0) || a.rawToken == address(0)
        ) {
            revert ZeroAddress();
        }
        if (a.rawToken == a.pairToken) revert SameToken();
        if (a.rawToken == a.standardExchange) revert RawIsSE();
    }

    function _safeSymbol(address token) private view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory s) {
            return s;
        } catch {
            return "TKN";
        }
    }
}
