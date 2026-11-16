// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_UniV2Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_UniV2Fixture.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice D20: Balancer-quad × UniswapV2StandardExchange. Face: 18-decimal pair token A of a seeded hermetic Uni V2 pair; SE shares 18 decimals.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV2StandardExchange is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_UniV2Fixture f = new SeMatrix_UniV2Fixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }
}
