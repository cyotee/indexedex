// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";

/// @notice Migration lifecycle and configuration, separate from canonical supply and execution history.
library UniswapV4DetfMigrationRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration"))) - 1);

    struct Storage {
        bool activated;
        address weth;
        address originalDtf;
        address rewardToken;
        address expectedSynchronizer;
        uint256 bootstrapSelfMinted;
        bytes frozen;
        mapping(address => uint256) donationInventory;
        mapping(address => uint256) residualInventory;
        mapping(address => uint256) operationFloor;
        bool budgetOpen;
        mapping(address => Migration.IndependentAllocation) allocations;
        mapping(address => Migration.IndependentIssuance) issuances;
        mapping(bytes32 => address) configuredOriginal;
        mapping(bytes32 => address) issuedOriginal;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _snapshot() internal view returns (Snapshot.Snapshot memory) {
        bytes memory frozen_ = _layoutStruct().frozen;
        if (frozen_.length == 0) revert Snapshot.SnapshotNotCaptured();
        return abi.decode(frozen_, (Snapshot.Snapshot));
    }
}
