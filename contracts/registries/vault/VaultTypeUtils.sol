// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {Bytes32} from "@crane/contracts/utils/Bytes32.sol";

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

library VaultTypeUtils {
    function _decodeAllVaultFeeTypes(bytes32 feeTypeIds_) internal pure returns (bytes4[] memory) {
        return Bytes32._equalPartitions(feeTypeIds_);
    }

    function _decodeVaultFeeType(bytes32 feeTypeIds_, VaultFeeType feeType_) internal pure returns (bytes4) {
        return Bytes32._extractEqPartition(feeTypeIds_, uint256(uint8(feeType_)));
    }

    function _insertFeeTypeId(bytes32 feeTypeIds_, VaultFeeType feeType_, bytes4 feeTypeId_)
        internal
        pure
        returns (bytes32)
    {
        return Bytes32._insertEqPartition(feeTypeIds_, feeTypeId_, uint256(uint8(feeType_)));
    }

    function _encodeAllVaultFeeTypes(bytes4[] memory feeTypeIds_) internal pure returns (bytes32 packedFeeTypeIds_) {
        return Bytes32._packEqualPartitions(feeTypeIds_);
    }

    // Assuming this is added to your VaultTypeUtils library or a suitable location.
    // It uses your existing _decodeVaultFeeType function for each field.
    // This avoids creating an intermediate array (as would happen with _decodeAllVaultFeeTypes),
    // which saves gas by eliminating array allocation and iteration.
    // Instead, it directly extracts each value using bit shifts internally (via _decodeVaultFeeType).
    // For an even more optimized version, you could inline the bit shift logic here without
    // function calls, but the compiler may inline them anyway, and this keeps the code DRY.

    function _decodeVaultFeeTypeIds(bytes32 feeTypeIds_) internal pure returns (VaultFeeTypeIds memory ids) {
        ids.usage = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.USAGE);
        ids.dex = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.DEX);
        ids.bond = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.BOND);
        ids.seigniorage = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.SEIGNIORAGE);
        ids.lending = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.LENDING);
        // ids.tbd0 = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.TBD0);
        // ids.tbd1 = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.TBD1);
        // ids.tbd2 = _decodeVaultFeeType(feeTypeIds_, VaultFeeType.TBD2);
    }
}
