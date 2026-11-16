// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Migration-only settlement cursors; shares and backing remain in the common repos.
library UniswapV4DetfMigrationSYRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.sy"))) - 1);

    struct Storage {
        mapping(address => uint256) lastK;
        IUniswapV4DetfMigrationAccounting.AccountingPhase phase;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly { layoutStruct_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }
}
