// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Fixed execution bounds, separate from the preserved sleeve-policy interface.
interface IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection {
    function executionProtectionBps() external pure returns (uint16, uint16, uint16, uint16, uint16);
}
