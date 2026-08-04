// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

/**
 * @title IUniswapV4HookDiamondFactoryStubPackage
 * @notice Hermetic stub package for hook diamond factory tests (PkgArgs on interface).
 * @dev Gold pattern for production hook packages:
 *      deployVault(PkgArgs, mineNonce) → registry.deployHookVault(this, abi.encode(args), mineNonce).
 */
interface IUniswapV4HookDiamondFactoryStubPackage is IUniswapV4HookDiamondPackage {
    struct PkgArgs {
        uint256 value;
    }

    function VAULT_REGISTRY_DEPLOYMENT() external view returns (IVaultRegistryDeployment);

    /// @notice Typed package deploy: enumerates args, then deploys through the Vault Registry.
    function deployVault(PkgArgs memory args, uint256 mineNonce) external returns (address vault);

    /// @notice Auto-mine convenience (gas-risky). Prefer deployVault with premine nonce.
    function deployVaultAutoMine(PkgArgs memory args) external returns (address vault);

    function bindingValue() external view returns (uint256);
    function name() external view returns (string memory);
    function vaultDeclaration() external view returns (IStandardVaultPkg.VaultPkgDeclaration memory);
    function vaultConfig() external view returns (IStandardVault.VaultConfig memory);
}
