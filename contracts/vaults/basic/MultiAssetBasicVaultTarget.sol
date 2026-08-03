// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/**
 * @title MultiAssetBasicVaultTarget
 * @notice Domain logic for multi-asset basic vault surface (Repo-backed).
 */
contract MultiAssetBasicVaultTarget is IBasicVault {
    /* ---------------------------------------------------------------------- */
    /*                               IBasicVault                              */
    /* ---------------------------------------------------------------------- */

    function vaultTokens() external view returns (address[] memory tokens_) {
        return MultiAssetBasicVaultRepo._vaultTokens();
    }

    function reserveOfToken(address token) external view returns (uint256 reserve_) {
        return MultiAssetBasicVaultRepo._reserveOfToken(token);
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        return MultiAssetBasicVaultRepo._reserves();
    }
}
