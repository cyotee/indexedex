// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Local uninstrumented outer router, not a full ERC-4337 EntryPoint.
/// @dev Deliberately performs NO balance, supply or state observations.
contract MigrationIndirectClaimFixture {
    error WalletCallFailed(bytes reason);

    function forward(address wallet_, bytes calldata data_) external returns (bytes memory result_) {
        bool success_;
        (success_, result_) = wallet_.call(data_);
        if (!success_) revert WalletCallFailed(result_);
    }
}
