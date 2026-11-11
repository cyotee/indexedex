// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Migration-only attribution. Physical gons, backing and index remain in DETFFundedStakingRepo.
library UniswapV4DetfMigrationStakedDETFRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration.staked"))) - 1);

    struct Storage {
        mapping(address account => uint256 principal) liquidBasis;
        mapping(uint8 domain => mapping(address beneficiary => uint256 gons)) deferred;
        uint256 deferredGons;
        uint256 tokenizedSyGons;
        uint256 selfHeldSyGons;
        uint8 phase;
    }

    /// @notice Resolve the attribution namespace at an explicit slot.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    /// @notice Resolve the canonical Migration attribution namespace.
    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }
}
