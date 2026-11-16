// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: weighted buffer hook x AaveV3StataStandardExchange. The M13 deferral (this heavy
///         family on the single-CP hook only) is lifted: the stata fixture now discriminates its package
///         salt by the fixture address, so each weighted leg stands up a distinct Aave market, stata and
///         SE. The row controls come from the behavior unchanged.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AaveV3StataStandardExchange is
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 18);
    }
}
