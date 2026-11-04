// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "./UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {
    UniswapV4PairTokenStandardExchangeVaultProjection as Projection,
    UniswapV4PairTokenStandardExchangeVaultSwapProjection as SwapProjection
} from "./UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "./UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {
    UniswapV4PairTokenStandardExchangeVaultExecution as Execution,
    UniswapV4PairTokenStandardExchangeVaultExecutionPreparation as ExecutionPreparation
} from "./UniswapV4PairTokenStandardExchangeVaultExecution.sol";

/// @notice Implementation metadata only; this selector is never installed on a vault.
interface IUniswapV4PairTokenStandardExchangeVaultComponentBindings {
    // tag::linkedComponents-21e1016f[]
    /// @custom:signature linkedComponents()
    /// @custom:selector 0x21e1016f
    function linkedComponents() external pure returns (address[6] memory);
    // end::linkedComponents-21e1016f[]
}

/// @notice Fixed compiler links, not caller-selected delegation destinations.
abstract contract UniswapV4PairTokenStandardExchangeVaultComponentBindings is
    IUniswapV4PairTokenStandardExchangeVaultComponentBindings
{
    // tag::linkedComponents-21e1016f[]
    /// @custom:signature linkedComponents()
    /// @custom:selector 0x21e1016f
    function linkedComponents() external pure returns (address[6] memory) {
        return [
            address(Math), address(Projection), address(SwapProjection),
            address(Planner), address(Execution), address(ExecutionPreparation)
        ];
    }
    // end::linkedComponents-21e1016f[]
}
