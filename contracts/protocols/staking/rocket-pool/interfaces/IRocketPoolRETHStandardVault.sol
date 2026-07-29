// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IRocketPoolRETHStandardVault
 * @notice Marker + views for Rocket Pool rETH Standard Exchange vaults.
 * @dev Interface id keys usage fee type and liquid-reserve type resolution.
 *      Route errors use IStandardExchangeErrors.InvalidRoute(tokenIn, tokenOut).
 */
interface IRocketPoolRETHStandardVault {
    /// @notice Liquid WETH sleeve cannot satisfy the requested amount (after optional burn).
    error InsufficientLiquidReserve(uint256 requested, uint256 available);

    error InsufficientLockedReserve(uint256 requested, uint256 available);

    /// @notice Hard stake path: deposit pool cannot take the requested ETH amount.
    error InsufficientDepositCapacity(uint256 maxDeposit, uint256 requested);

    error ZeroAmount();
    error ZeroAddress();
    error Slippage();
    error DeadlineExpired();
    error InsufficientDeposit(uint256 requested, uint256 actual);

    function rETH() external view returns (address);
    function weth() external view returns (address);
    function depositPool() external view returns (address);

    function liquidReserveEth() external view returns (uint256);
    function lockedReserveEth() external view returns (uint256);
    function totalReserveEth() external view returns (uint256);
    function actualLiquidReservePercentage() external view returns (uint256);
    function targetLiquidReservePercentage() external view returns (uint256);
}

interface IRocketPoolRETHRebalance {
    /// @notice Permissionless rebalance toward oracle liquid target (stake excess / burn deficit).
    function rebalance() external;
}
