// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4OrbitalSwapHookPackage
 * @notice DFPkg interface for Uniswap V4 Orbital Swap Hook (hook diamond package).
 * @dev PkgInit / PkgArgs on interface (Crane rule). Shared LP = ERC20PermitDFPkg facets + MultiAsset vault.
 *      Deploy: package → registry.deployHookVault → shared hook CREATE2 factory.
 */
interface IUniswapV4OrbitalSwapHookPackage is IUniswapV4HookDiamondPackage, IStandardVaultPkg {
    error ZeroAddress();
    error SameToken();

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IFacet hooksFacet;
        IFacet liquidityFacet;
        /// @dev ERC20PermitDFPkg parity: LP share is the hook diamond.
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (salt identity).
    /// @dev tickSpacing / sqrtPriceX96 are process/init only — NOT in calcSalt (R15/R32).
    struct PkgArgs {
        address poolManager;
        address feeOracle;
        address token0;
        address token1;
        address token2;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function HOOKS_FACET() external view returns (IFacet);
    function LIQUIDITY_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
}
