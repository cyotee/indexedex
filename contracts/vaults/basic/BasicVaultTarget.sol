// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {BasicVaultRepo} from 'contracts/vaults/basic/BasicVaultRepo.sol';

contract BasicVaultTarget is IBasicVault {

    /* ---------------------------------------------------------------------- */
    /*                               IBasicVault                              */
    /* ---------------------------------------------------------------------- */

    function vaultTokens() external view returns (address[] memory tokens_) {
        return BasicVaultRepo._vaultTokens();
    }

    function reserveOfToken(address token) external view returns (uint256 reserve_) {
        return BasicVaultRepo._reserveOfToken(token);
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        return BasicVaultRepo._reserves();
    }
}