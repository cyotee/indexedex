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
 * @title IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
 * @notice DFPkg interface for Dual SE Buffer CP Hook (Option B hook diamond).
 * @dev PkgInit / PkgArgs on interface (Crane rule). Shared LP token facets match
 *      ERC20PermitDFPkg (ERC20 + ERC5267 + ERC2612) plus MultiAsset vault facets.
 *      SE In/Out surface: residual (D-SE) — vault registration is DoD; pair0↔pair1 SE
 *      methods deferred (swap previews remain on product surface).
 */
interface IUniswapV4DualStandardExchangeBufferConstantProductHookPackage is
    IUniswapV4HookDiamondPackage,
    IStandardVaultPkg
{
    error ZeroAddress();
    error SameStandardExchange();
    error SamePairToken();
    error TokenNotInVaultTokens();

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IVaultFeeOracleQuery vaultFeeOracleQuery;
        IFacet hooksFacet;
        IFacet depositFacet;
        IFacet withdrawFacet;
        /// @dev ERC20PermitDFPkg parity: LP share is the hook diamond.
        IFacet erc20Facet;
        IFacet erc5267Facet;
        IFacet erc2612Facet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (salt identity). Free ctor leg order OK.
    struct PkgArgs {
        address poolManager;
        address feeOracle;
        address standardExchange0;
        address token0;
        address standardExchange1;
        address token1;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function HOOKS_FACET() external view returns (IFacet);
    function DEPOSIT_FACET() external view returns (IFacet);
    function WITHDRAW_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
}
