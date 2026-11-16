// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV4FullSpreadStandardExchangeVaultMath as Math} from "./UniswapV4FullSpreadStandardExchangeVaultMath.sol";
import {UniswapV4FullSpreadStandardExchangeVaultProjection as Projection} from "./UniswapV4FullSpreadStandardExchangeVaultProjection.sol";
import {UniswapV4FullSpreadStandardExchangeVaultSwapProjection as SwapProjection} from "./UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol";
import {UniswapV4FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV4FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV4FullSpreadStandardExchangeVaultExecution as Execution} from "./UniswapV4FullSpreadStandardExchangeVaultExecution.sol";
import {UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation as ExecutionPreparation} from "./UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol";

interface IUniswapV4FullSpreadStandardExchangeVaultComponentBindings {
    function linkedComponents() external pure returns (address[6] memory);
}

abstract contract UniswapV4FullSpreadStandardExchangeVaultComponentBindings is
    IUniswapV4FullSpreadStandardExchangeVaultComponentBindings
{
    function linkedComponents() external pure returns (address[6] memory) {
        return [
            address(Math),
            address(Projection),
            address(SwapProjection),
            address(Planner),
            address(Execution),
            address(ExecutionPreparation)
        ];
    }
}
