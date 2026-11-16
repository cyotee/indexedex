// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

// import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {

    // BondTerms,
    // DexTerms,
    // KinkLendingTerms,
    VaultFeeType,
    VaultFeeTypeIds
} from "contracts/interfaces/VaultFeeTypes.sol";

/**
 * @custom:interfaceid 0xc4b98bb0
 */
interface IStandardVaultPkg {
    struct VaultPkgDeclaration {
        string name;
        bytes32 vaultFeeTypeIds;
        bytes4[] vaultTypes;
    }

    /**
     * @custom:selector 0x06fdde03
     */
    function name() external view returns (string memory);

    function vaultFeeTypeIds() external view returns (bytes32);

    /**
     * @custom:selector 0x36abf3dc
     */
    function vaultTypes() external view returns (bytes4[] memory typeIDs);

    /**
     * @custom:selector 0xf4efa66f
     */
    function vaultDeclaration() external view returns (VaultPkgDeclaration memory);
}
