// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

// tag::IUniswapV4PairTokenStandardExchangeVaultDFPkg[]
/// @notice Immutable registered package for the full-range PairToken family.
/// @dev Factory-owned introspection and temporary-hook facets are never package inputs.
/// @custom:interfaceid 0xc283faa9
interface IUniswapV4PairTokenStandardExchangeVaultDFPkg is IDiamondFactoryPackage, IStandardVaultPkg {
    // tag::PkgInit[]
    /// @dev All twelve facets and five infrastructure bindings participate in bindingHash.
    /// No optional component or caller-selectable execution address is reserved here.
    struct PkgInit {
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet basicVaultFacet;
        IFacet standardVaultFacet;
        IFacet moneyFacet;
        IFacet quoteFacet;
        IFacet outFacet;
        IFacet queryFacet;
        IFacet syMoneyFacet;
        IFacet syQueryFacet;
        IFacet callbackFacet;
        IPoolManager poolManager;
        IVaultRegistryDeployment registry;
        IVaultFeeOracleQuery oracle;
        IWETH wrappedNative;
        IDiamondPackageCallBackFactory diamondFactory;
        // Fixed CREATE3-linked components: Math, Projection, SwapProjection,
        // Planner, Execution (donation), ExecutionPreparation.
        address[6] linkedLibraries;
    }
    // end::PkgInit[]

    // tag::PkgArgs[]
    /// @dev Complete canonical instance arguments; there are no silent zap defaults.
    struct PkgArgs {
        PoolKey poolKey;
        address rateAsset;
        string name;
        string symbol;
        uint16 maxZapBps;
        int24 maxZapTickMove;
    }
    // end::PkgArgs[]

    // tag::InvalidComponent[]
    /// @custom:signature InvalidComponent()
    /// @custom:selector 0xb03ac0b6
    /// @notice A required package component is absent or incompatible.
    error InvalidComponent();
    // end::InvalidComponent[]

    // tag::InvalidPoolKey[]
    /// @custom:signature InvalidPoolKey()
    /// @custom:selector 0xc256622b
    /// @notice The pool key or initialized manager state is outside the supported domain.
    error InvalidPoolKey();
    // end::InvalidPoolKey[]

    // tag::InvalidRateAsset[]
    /// @custom:signature InvalidRateAsset()
    /// @custom:selector 0x41ef82fd
    /// @notice The valuation asset is not a declared ERC-20 currency face.
    error InvalidRateAsset();
    // end::InvalidRateAsset[]

    // tag::InvalidZapLimits[]
    /// @custom:signature InvalidZapLimits()
    /// @custom:selector 0x70965b62
    /// @notice Zap limits are not positive/in-range basis points and a nonnegative tick bound.
    error InvalidZapLimits();
    // end::InvalidZapLimits[]

    // tag::InvalidWrappedNative[]
    /// @custom:signature InvalidWrappedNative()
    /// @custom:selector 0x5e66e44d
    /// @notice The native wrapper is incompatible or collides with the other currency face.
    error InvalidWrappedNative();
    // end::InvalidWrappedNative[]

    // tag::NotCalledByRegistry[]
    /// @custom:signature NotCalledByRegistry()
    /// @custom:selector 0xd8af869a
    /// @notice Argument processing was not entered through the bound registry/factory context.
    error NotCalledByRegistry();
    // end::NotCalledByRegistry[]

    // tag::InvalidInitializationContext[]
    /// @custom:signature InvalidInitializationContext()
    /// @custom:selector 0x0bda07c4
    /// @notice Proxy initialization does not match the bound factory's package and arguments.
    error InvalidInitializationContext();
    // end::InvalidInitializationContext[]

    // tag::AlreadyInitialized[]
    /// @custom:signature AlreadyInitialized()
    /// @custom:selector 0x0dc149f0
    /// @notice Instance configuration has already been initialized.
    error AlreadyInitialized();
    // end::AlreadyInitialized[]

    // tag::bindingHash[]
    /// @custom:signature bindingHash()
    /// @custom:selector 0xd727562b
    /// @notice Hash of the package's immutable components and infrastructure.
    /// @dev calcSalt/processArgs run by delegatecall in the factory; they must use
    /// immutable bindings and SELF calls rather than foreign-context package storage.
    function bindingHash() external view returns (bytes32);
    // end::bindingHash[]

    // tag::deployVault[]
    /// @custom:signature deployVault(((address,address,uint24,int24,address),address,string,string,uint16,int24))
    /// @custom:selector 0x15a4ac82
    /// @notice Deploy an instance through the bound IndexedEx vault registry.
    function deployVault(PkgArgs memory args_) external returns (address vault);
    // end::deployVault[]
}
// end::IUniswapV4PairTokenStandardExchangeVaultDFPkg[]
