// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CamelotFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CamelotFixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: UniswapV4StandardExchangeBalancerQuadStableBufferHook x CamelotV2StandardExchange. Face: 18-decimal Camelot V2 pair token A; SE shares 27 decimals (reserve 18 + 9). Compatible under D65 (2026-09-23): the quad packages
///         accept SE share decimals 6..36, so this SE's shares bind to a hook leg.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_CamelotV2StandardExchange is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_CamelotFixture f = new SeMatrix_CamelotFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }
}
