// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Non-SUT dependency failure fixtures for the APEX 2026-09-17 D30/D34 propagation controls.
/// @dev These stand in for an underlying protocol dependency, never for a production SUT.

/// @dev A Rocket deposit pool that publishes open capacity but rejects the operative `deposit`
///      with custom revert bytes, proving the SE propagates the dependency's own error after its
///      prechecks pass (D30/D34) instead of catching and booking.
contract FailingRocketDepositPool {
    error DependencyRejected(uint256 value, bytes32 tag);

    bytes32 public constant TAG = keccak256("APEX-D34-rocket-deposit");

    function getMaximumDepositAmount() external pure returns (uint256) {
        return type(uint256).max;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getExcessBalance() external pure returns (uint256) {
        return 0;
    }

    function deposit() external payable {
        revert DependencyRejected(msg.value, TAG);
    }

    receive() external payable {}
}
