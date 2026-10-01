// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AerodromeFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AerodromeFixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × AerodromeStandardExchange. Face: 18-decimal pair token A of a seeded volatile Aerodrome V1 pool; SE shares 18 decimals.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_AerodromeStandardExchange is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_AerodromeFixture f = new SeMatrix_AerodromeFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }
}
