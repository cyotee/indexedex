// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4HookDiamondFactoryStubPackage
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/IUniswapV4HookDiamondFactoryStubPackage.sol";
import {
    UniswapV4HookDiamondFactoryStubRepo
} from "test/foundry/spec/hooks/uniswap/v4/factory/stubs/UniswapV4HookDiamondFactoryStubRepo.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";

/**
 * @title UniswapV4HookDiamondFactoryStubPackage
 * @notice Hermetic stub DFPkg demonstrating package → registry → hook factory deploy.
 * @dev Sparse flags (BEFORE_SWAP only) for easy mining. processArgs is identity.
 *      Package is also cut as a facet onto the proxy for vaultConfig / bindingValue.
 *
 *      Canonical product path (mirror SE packages):
 *        deployVault(args, mineNonce) → VAULT_REGISTRY_DEPLOYMENT.deployHookVault(SELF, encode(args), mineNonce)
 */
contract UniswapV4HookDiamondFactoryStubPackage is
    IUniswapV4HookDiamondFactoryStubPackage,
    IStandardVaultPkg,
    IStandardVault,
    IFacet
{
    using BetterEfficientHashLib for bytes;

    bytes32 public constant PRODUCT_ID = keccak256("UniswapV4HookDiamondFactoryStub");
    bytes4 public constant STUB_HOOK_VAULT_TYPE = bytes4(keccak256("UniswapV4HookDiamondFactoryStub"));

    IVaultRegistryDeployment public immutable VAULT_REGISTRY_DEPLOYMENT;
    IUniswapV4HookDiamondFactoryStubPackage private immutable SELF;

    constructor(IVaultRegistryDeployment vaultRegistryDeployment_) {
        VAULT_REGISTRY_DEPLOYMENT = vaultRegistryDeployment_;
        SELF = this;
    }

    /* ----------------------- Package → Registry deploy path ----------------------- */

    /// @inheritdoc IUniswapV4HookDiamondFactoryStubPackage
    function deployVault(PkgArgs memory args, uint256 mineNonce) public returns (address vault) {
        // Same pattern as SE DFPkg.deployVault → registry.deployVault, but hook factory + mineNonce.
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVault(
            IStandardVaultPkg(address(SELF)), abi.encode(args), mineNonce
        );
    }

    /// @inheritdoc IUniswapV4HookDiamondFactoryStubPackage
    function deployVaultAutoMine(PkgArgs memory args) public returns (address vault) {
        vault = VAULT_REGISTRY_DEPLOYMENT.deployHookVaultAutoMine(
            IStandardVaultPkg(address(SELF)), abi.encode(args)
        );
    }

    function requiredHookFlags() public pure returns (uint160 flags) {
        return Hooks.BEFORE_SWAP_FLAG;
    }

    function isExpectedInstance(address proxy, bytes calldata) external view returns (bool) {
        if (proxy.code.length == 0) return false;
        return (uint160(proxy) & Create2Lib.FLAG_MASK) == (Hooks.BEFORE_SWAP_FLAG & Create2Lib.FLAG_MASK);
    }

    function packageName() public pure returns (string memory) {
        return type(UniswapV4HookDiamondFactoryStubPackage).name;
    }

    function facetInterfaces() public pure override(IDiamondFactoryPackage, IFacet) returns (bytes4[] memory interfaces)
    {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardVault).interfaceId;
        interfaces[1] = type(IUniswapV4HookDiamondFactoryStubPackage).interfaceId;
    }

    function facetAddresses() public view returns (address[] memory facets) {
        facets = new address[](1);
        facets[0] = address(SELF);
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
        cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(SELF),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _packageFuncs()
        });
    }

    function diamondConfig() public view returns (IDiamondFactoryPackage.DiamondConfig memory config) {
        config = IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        PkgArgs memory decoded = abi.decode(pkgArgs, (PkgArgs));
        return keccak256(abi.encode(PRODUCT_ID, decoded.value));
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        PkgArgs memory decoded = abi.decode(initArgs, (PkgArgs));
        UniswapV4HookDiamondFactoryStubRepo._set(decoded.value);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }

    /* ----------------------------- IStandardVaultPkg ---------------------------- */

    function name() public pure override(IStandardVaultPkg, IUniswapV4HookDiamondFactoryStubPackage) returns (string memory) {
        return "UniswapV4HookDiamondFactoryStub";
    }

    function vaultFeeTypeIds() public pure override(IStandardVault, IStandardVaultPkg) returns (bytes32) {
        return bytes32(0);
    }

    function vaultTypes() public pure override(IStandardVault, IStandardVaultPkg) returns (bytes4[] memory typeIDs) {
        typeIDs = new bytes4[](1);
        typeIDs[0] = STUB_HOOK_VAULT_TYPE;
    }

    function vaultDeclaration()
        public
        pure
        override(IStandardVaultPkg, IUniswapV4HookDiamondFactoryStubPackage)
        returns (IStandardVaultPkg.VaultPkgDeclaration memory decl)
    {
        decl = IStandardVaultPkg.VaultPkgDeclaration({
            name: name(), vaultFeeTypeIds: vaultFeeTypeIds(), vaultTypes: vaultTypes()
        });
    }

    /* ------------------------------ IStandardVault ------------------------------ */

    function contentsId() public pure returns (bytes32) {
        return PRODUCT_ID;
    }

    function vaultConfig()
        public
        pure
        override(IStandardVault, IUniswapV4HookDiamondFactoryStubPackage)
        returns (IStandardVault.VaultConfig memory cfg)
    {
        address[] memory tokens = new address[](0);
        cfg = IStandardVault.VaultConfig({
            vaultFeeTypeIds: vaultFeeTypeIds(),
            contentsId: contentsId(),
            vaultTypes: vaultTypes(),
            tokens: tokens
        });
    }

    function bindingValue() public view returns (uint256) {
        return UniswapV4HookDiamondFactoryStubRepo._value();
    }

    /* ---------------------------------- IFacet ---------------------------------- */

    function facetName() public pure returns (string memory) {
        return packageName();
    }

    function facetFuncs() public pure returns (bytes4[] memory) {
        return _packageFuncs();
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function _packageFuncs() private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IStandardVault.vaultConfig.selector;
        funcs[1] = IStandardVault.vaultFeeTypeIds.selector;
        funcs[2] = IStandardVault.contentsId.selector;
        funcs[3] = IStandardVault.vaultTypes.selector;
        funcs[4] = IUniswapV4HookDiamondFactoryStubPackage.bindingValue.selector;
        funcs[5] = IStandardVaultPkg.name.selector;
    }
}
