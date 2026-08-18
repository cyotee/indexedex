// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4StandardExchangeWeightedBufferHookPackage
 * @notice DFPkg interface for SE Weighted Buffer Hook (hook diamond package).
 * @dev PkgInit / PkgArgs on interface (Crane rule). Shared LP = ERC20PermitDFPkg facets + MultiAsset vault.
 *      Deploy: package → registry.deployHookVault → shared hook CREATE2 factory.
 */
interface IUniswapV4StandardExchangeWeightedBufferHookPackage is
    IUniswapV4HookDiamondPackage,
    IStandardVaultPkg
{
    error ZeroAddress();
    error InvalidN();
    error SameToken();
    error TokensNotAscending();
    error InvalidWeight();
    error WeightsSum();
    error ZeroStandardExchangeRequired();
    error SameStandardExchange();
    error RateProviderWithoutSE();
    error InvalidSE();
    error InvalidDecimals();
    error ArrayLengthMismatch();

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        /// @dev Option 1d: join + exit replace combined liquidityFacet.
        IFacet joinFacet;
        IFacet exitFacet;
        IFacet seFacet;
        IFacet hooksFacet;
        /// @dev ERC20PermitDFPkg parity: LP share is the hook diamond.
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (n∈[2,8], ≥1 SE).
    /// @dev poolManager + feeOracle from factory-scope wiring; still passed for init.
    ///      Salt identity: PRODUCT_ID + n + tokens + weights + SEs + RPs (no package/facet addresses).
    struct PkgArgs {
        address poolManager;
        address feeOracle;
        uint8 n;
        address[] tokens;
        uint256[] weights;
        address[] standardExchanges;
        address[] rateProviders;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function JOIN_FACET() external view returns (IFacet);
    function EXIT_FACET() external view returns (IFacet);
    function SE_FACET() external view returns (IFacet);
    function HOOKS_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Production Add list applied by finalizeInitialization. Not used at initAccount.
    function productionFacetCuts() external view returns (IDiamond.FacetCut[] memory);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
}
