// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Existing diamond callbacks used for atomic best-effort operations and quotes.
/// @dev State-changing callbacks remain self-only on the maintenance target.
interface IUniswapV4DetfSelfCall {
    /// @notice Quotes an input token amount in its configured vault's reserve-pair units.
    function peekPairEq(address vault, address tokenIn, uint256 amountIn) external view returns (uint256);
    /// @notice Executes one atomic dust-sweep attempt; only the diamond itself may call.
    function sweepDustAtomic() external;
    /// @notice Wraps residual pair tokens through their SE vault; only the diamond itself may call.
    function sweepPairToShare(address standardExchange, address pairToken, uint256 amount)
        external
        returns (uint256 shares);
}
