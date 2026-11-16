// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {EIP712Repo} from "@crane/contracts/utils/cryptography/EIP712/EIP712Repo.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg[]
/// @notice Registry-deployed immutable family package. Pool and target are both part of instance identity.
contract UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg is IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    IFacet[] private components;
    IPoolManager private immutable MANAGER;
    IVaultRegistryDeployment private immutable REGISTRY;
    IVaultFeeOracleQuery private immutable ORACLE;
    IPermit2 private immutable PERMIT2;
    address private immutable SELF;
    bytes32 public immutable bindingHash;

    constructor(PkgInit memory init_) {
        if (address(init_.poolManager).code.length == 0 || address(init_.registry).code.length == 0
            || address(init_.oracle).code.length == 0 || address(init_.permit2).code.length == 0
            || init_.facets.length == 0) revert InvalidComponent();
        for (uint256 i; i < init_.facets.length; ++i) {
            if (address(init_.facets[i]).code.length == 0) revert InvalidComponent();
            components.push(init_.facets[i]);
        }
        MANAGER = init_.poolManager; REGISTRY = init_.registry; ORACLE = init_.oracle; PERMIT2 = init_.permit2;
        SELF = address(this); bindingHash = keccak256(abi.encode(init_));
    }
    function name() public pure returns (string memory) { return packageName(); }
    function packageName() public pure returns (string memory) { return type(UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg).name; }
    function vaultFeeTypeIds() public pure returns (bytes32) {
        return VaultTypeUtils._insertFeeTypeId(bytes32(0), VaultFeeType.USAGE, type(IUniswapV4UpperLowerWingsStandardExchangeVault).interfaceId);
    }
    function vaultTypes() public view returns (bytes4[] memory) { return facetInterfaces(); }
    function vaultDeclaration() public view returns (VaultPkgDeclaration memory) {
        return VaultPkgDeclaration(name(), vaultFeeTypeIds(), vaultTypes());
    }
    function facetInterfaces() public view returns (bytes4[] memory ids_) {
        // Read package storage even when initAccount is executing in the new diamond.
        if (address(this) != SELF) return IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg(SELF).facetInterfaces();
        uint256 count;
        for (uint256 i; i < components.length; ++i) count += components[i].facetInterfaces().length;
        ids_ = new bytes4[](count);
        uint256 used;
        for (uint256 i; i < components.length; ++i) {
            bytes4[] memory next = components[i].facetInterfaces();
            for (uint256 j; j < next.length; ++j) {
                bool exists;
                for (uint256 k; k < used; ++k) if (ids_[k] == next[j]) exists = true;
                if (!exists) ids_[used++] = next[j];
            }
        }
        assembly ("memory-safe") { mstore(ids_, used) }
    }
    function facetAddresses() public view returns (address[] memory addresses_) {
        addresses_ = new address[](components.length);
        for (uint256 i; i < components.length; ++i) addresses_[i] = address(components[i]);
    }
    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts_) {
        cuts_ = new IDiamond.FacetCut[](components.length);
        for (uint256 i; i < components.length; ++i) {
            cuts_[i] = IDiamond.FacetCut(address(components[i]), IDiamond.FacetCutAction.Add, components[i].facetFuncs());
        }
    }
    function diamondConfig() public view returns (DiamondConfig memory) { return DiamondConfig(facetCuts(), facetInterfaces()); }
    function packageMetadata() external view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }
    function calcSalt(bytes memory args_) public pure returns (bytes32) { return keccak256(args_); }
    function processArgs(bytes memory args_) external view returns (bytes memory) {
        if (msg.sender != address(REGISTRY)) revert NotCalledByRegistry();
        _validate(abi.decode(args_, (PkgArgs)));
        return args_;
    }
    function deployVault(PkgArgs memory args_) external returns (address) {
        return REGISTRY.deployVault(this, abi.encode(args_));
    }
    function initAccount(bytes memory args_) external {
        if (address(this) == SELF) revert InvalidComponent();
        Repo.Storage storage state = Repo._layout();
        if (state.initialized) revert IUniswapV4UpperLowerWingsStandardExchangeVault.AlreadyInitialized();
        PkgArgs memory args = abi.decode(args_, (PkgArgs));
        _validate(args);
        state.initialized = true; state.manager = MANAGER; state.key = args.poolKey; state.oracle = ORACLE;
        state.registry = address(REGISTRY);
        state.target0 = args.targetToken == Currency.unwrap(args.poolKey.currency0);
        address[] memory tokens = new address[](1); tokens[0] = args.targetToken;
        MultiAssetBasicVaultRepo._initialize(tokens);
        StandardVaultRepo._initialize(ORACLE, vaultFeeTypeIds(), facetInterfaces(), keccak256(abi.encode(tokens)));
        VaultFeeOracleQueryAwareRepo._initialize(ORACLE);
        Permit2AwareRepo._initialize(PERMIT2);
        string memory tokenName = "Uniswap V4 Upper Lower Wings Vault";
        // Native target units also denominate shares: no precision-losing bootstrap scale or permanent sink.
        ERC20Repo._initialize(tokenName, "UV4W", IERC20Metadata(args.targetToken).decimals());
        EIP712Repo._initialize(tokenName, "1");
    }
    function postDeploy(address) external pure returns (bool) { return true; }
    /// @dev Factory pre-deployment notification; deliberately performs no configuration or instance writes.
    function updatePkg(address, bytes memory) external pure returns (bool) { return true; }
    function _validate(PkgArgs memory args_) private view {
        address token0 = Currency.unwrap(args_.poolKey.currency0);
        address token1 = Currency.unwrap(args_.poolKey.currency1);
        if (token0 == address(0) || token0 >= token1 || token0.code.length == 0 || token1.code.length == 0
            || address(args_.poolKey.hooks) != address(0) || args_.poolKey.fee > 1_000_000
            || args_.poolKey.tickSpacing <= 0 || args_.poolKey.tickSpacing > 32767) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidPoolKey();
        if (args_.targetToken != token0 && args_.targetToken != token1) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidTarget();
        (uint160 price,,,) = MANAGER.getSlot0(args_.poolKey.toId());
        if (price == 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InvalidPoolKey();
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg[]
