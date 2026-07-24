// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title ILidoWithdrawalQueue
 * @notice Minimal WithdrawalQueue surface for Lido SE rebalance.
 */
interface ILidoWithdrawalQueue {
    function requestWithdrawalsWstETH(uint256[] calldata amounts, address owner)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawal(uint256 requestId) external;

    function isPaused() external view returns (bool);

    /// @dev Optional status helper; hermetic queue implements simplified form.
    function isFinalized(uint256 requestId) external view returns (bool);

    function isClaimed(uint256 requestId) external view returns (bool);
}
