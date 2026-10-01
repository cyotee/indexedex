// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_BufferPoolFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BufferPoolFixture.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice R10.3: UniswapV4StandardExchangeBalancerQuadStableBufferHook x StandardExchangeBufferPool (GOLD). The Balancer V3 buffer-pool SE implements
///         IStandardExchangeTransitionQuote (0x185ec0ef / quoteState 0x844c633c) so the buffered hook
///         projects it for wei-exact previews, and D69 closed the execution gap this row was DEFERRED
///         for (balancer-quad buffered-leg join sizing now floor-scales the provided face like the curve-quad join), so every row control runs against the pool SE.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_StandardExchangeBufferPool is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_BufferPoolFixture(_ctx(), address(0));
    }
}
