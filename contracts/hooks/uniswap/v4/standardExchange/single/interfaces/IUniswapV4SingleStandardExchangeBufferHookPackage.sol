// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title IUniswapV4SingleStandardExchangeBufferHookPackage
 * @notice DFPkg interface for Single SE Buffer Hook (Option B hook diamond).
 * @dev PkgInit / PkgArgs on interface (Crane rule). MultiAsset vault facets only —
 *      no LP ERC20 facets (buffer is not an LP product).
 *
 * Integrator notes (PRD §12):
 * - Pool: fee 0, currencies sort(pairToken, SE), tickSpacing 60, sqrtPriceX96 1:1 hint.
 * - Zero CL; wrap/unwrap only via V4 swap; SE preview == execution on closed-form routes.
 * - Deploy via package → Vault Registry.deployHookVault → shared hook factory (CREATE2 flags).
 */
interface IUniswapV4SingleStandardExchangeBufferHookPackage is IUniswapV4HookDiamondPackage, IStandardVaultPkg {
    error ZeroAddress();
    error SameToken();
    error InvalidPairToken();

    struct PkgInit {
        IVaultRegistryDeployment vaultRegistryDeployment;
        IFacet productFacet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @notice Binding for one immortal hook instance (salt identity).
    struct PkgArgs {
        address poolManager;
        address standardExchange;
        address pairToken;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);
    function PRODUCT_FACET() external view returns (IFacet);
    function PRODUCT_ID() external pure returns (bytes32);

    /// @notice Product path: package → Vault Registry.deployHookVault → hook factory.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Gas-risky auto-mine convenience. Prefer deployVault with premined mineNonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);
}
