// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: balancer quad-stable buffer hook x AaveCrossVersionLoop (COMPATIBLE). The M13
///         deferral is lifted and the former SE-capability gap is closed: the loop SE OUT facet now offers
///         a wrap exact-out (mint) route (tokenA in for exact loop shares out) through the same D61
///         conservative leverage executor, so the exact-out swap rows route end to end. Each quad leg
///         binds a distinct Aave loop market. Row controls come from the behavior unchanged.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_AaveCrossVersionLoop is
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 18);
    }
}
