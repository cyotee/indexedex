// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

/**
 * @title IUniswapV4HookDiamondPackage
 * @notice DFPkg extension for Uniswap V4 hook diamond instances deployed via
 *         UniswapV4HookDiamondPackageCallBackFactory.
 * @dev Package address is NOT mixed into CREATE2 salt. Include a stable PRODUCT_ID in calcSalt.
 *
 *      Production deploy path (same shape as SE vault packages):
 *        1. Register package: registry.deployPkg(...)
 *        2. Package exposes typed deployVault(PkgArgs, mineNonce) that encodes args and calls
 *           IVaultRegistryDeployment.deployHookVault(this, abi.encode(args), mineNonce)
 *        3. Registry → hook factory → _registerVault (hook is a vault)
 *      Do NOT call vault diamond factory deployVault (package-in-salt). Do NOT rely on direct
 *      factory.deploy* as the product surface (permissionless factory is for tests / escape hatch).
 */
interface IUniswapV4HookDiamondPackage is IDiamondFactoryPackage {
    /// @notice Uniswap V4 hook permission flags the CREATE2 proxy address must encode.
    /// @dev Package-constant. Factory masks to Hooks.ALL_HOOK_MASK. Zero is allowed for non-hook diamonds.
    function requiredHookFlags() external pure returns (uint160 flags);

    /// @notice Thin acceptance check for first-deployer-wins / idempotent redeploy.
    /// @dev Factory calls when predicted address has code. Must not require facet-set equality.
    function isExpectedInstance(address proxy, bytes calldata processedArgs) external view returns (bool);
}
