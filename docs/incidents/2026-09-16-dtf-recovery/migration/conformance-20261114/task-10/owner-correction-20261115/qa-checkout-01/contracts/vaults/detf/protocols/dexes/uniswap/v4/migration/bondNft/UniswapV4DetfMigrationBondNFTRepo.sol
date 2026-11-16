// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationAccounting as Accounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Migration policy only; canonical funded bond storage owns every position and gon.
library UniswapV4DetfMigrationBondNFTRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.bonds"))) - 1);

    struct Storage {
        mapping(uint256 tokenId => bool) migrationPosition;
        Accounting.AccountingPhase phase;
    }

    /// @notice Bind an explicit policy namespace.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly { layoutStruct_.slot := slot_ }
    }

    /// @notice Bind the canonical Migration bond policy namespace.
    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }
}
