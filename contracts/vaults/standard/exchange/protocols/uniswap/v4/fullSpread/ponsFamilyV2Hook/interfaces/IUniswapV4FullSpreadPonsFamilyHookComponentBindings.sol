// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Read-only constructor bindings used to validate occupied CREATE3 identities.
interface IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding {
    function UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE() external view returns (address);
}

interface IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding {
    function UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE() external view returns (address);
}
