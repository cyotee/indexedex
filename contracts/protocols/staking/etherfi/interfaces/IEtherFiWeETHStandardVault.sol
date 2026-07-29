// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IEtherFiWeETHStandardVault
 * @notice Marker + views for ether.fi weETH Standard Exchange vaults.
 * @dev Interface id keys usage fee type and liquid-reserve type resolution.
 *      Route errors use IStandardExchangeErrors.InvalidRoute(tokenIn, tokenOut).
 */
interface IEtherFiWeETHStandardVault {
    /// @notice Liquid WETH sleeve cannot satisfy the requested amount (after optional redeem).
    error InsufficientLiquidReserve(uint256 requested, uint256 available);

    error InsufficientLockedReserve(uint256 requested, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error Slippage();
    error DeadlineExpired();

    function weETH() external view returns (address);
    function eETH() external view returns (address);
    function weth() external view returns (address);
    function liquidityPool() external view returns (address);
    function withdrawRequestNFT() external view returns (address);
    function redemptionManager() external view returns (address);

    function liquidReserveEth() external view returns (uint256);
    function lockedReserveEth() external view returns (uint256);
    function totalReserveEth() external view returns (uint256);
    function actualLiquidReservePercentage() external view returns (uint256);
    function targetLiquidReservePercentage() external view returns (uint256);
}

interface IEtherFiWeETHRebalance {
    /// @notice Permissionless rebalance toward oracle liquid target.
    function rebalance() external;
}
