// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title ILidoWstETHStandardVault
 * @notice Marker + views for Lido wstETH Standard Exchange vaults.
 * @dev Interface id keys usage fee type and liquid-reserve type resolution.
 *      Route errors use IStandardExchangeErrors.InvalidRoute(tokenIn, tokenOut).
 */
interface ILidoWstETHStandardVault {
    /// @notice Liquid WETH sleeve cannot satisfy the requested amount.
    error InsufficientLiquidReserve(uint256 requested, uint256 available);

    error InsufficientLockedReserve(uint256 requested, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error Slippage();
    error DeadlineExpired();

    function wstETH() external view returns (address);
    function stETH() external view returns (address);
    function weth() external view returns (address);
    function withdrawalQueue() external view returns (address);

    function liquidReserveEth() external view returns (uint256);
    function lockedReserveEth() external view returns (uint256);
    function totalReserveEth() external view returns (uint256);
    function actualLiquidReservePercentage() external view returns (uint256);
    function targetLiquidReservePercentage() external view returns (uint256);
}

interface ILidoWstETHRebalance {
    /// @notice Permissionless rebalance toward oracle liquid target.
    function rebalance() external;
}
