// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Imports                                  */
/* -------------------------------------------------------------------------- */

/* --------------------------- Imported Constants --------------------------- */

/* ----------------------------- Imported Types ----------------------------- */

/* ---------------------------- Imported Events ----------------------------- */

/* ----------------------------- Imported Errors ---------------------------- */

/* --------------------------- Imported Interfaces -------------------------- */

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";

/* --------------------------- Imported Libraries --------------------------- */

/* --------------------------- Imported Contracts --------------------------- */

contract StandardVaultTarget is IStandardVault {
    function vaultFeeTypeIds() public view returns (bytes32 vaultFeeTypeIds_) {}

    function contentsId() external view returns (bytes32 contentsId_) {}

    function vaultTypes() public view returns (bytes4[] memory vaultTypes_) {}

    function vaultConfig() public view returns (VaultConfig memory vaultConfig_) {}

}