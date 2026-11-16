// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_MixedLegFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_MixedLegFixture.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice R10.3: UniswapV4StandardExchangeOrbitalBufferHook x MixedLegWeightedBufferPool (GOLD). The Balancer V3 buffer-pool SE now implements
///         IStandardExchangeTransitionQuote (0x185ec0ef / quoteState 0x844c633c), so the buffered
///         hook projects this SE for wei-exact previews instead of reverting NoTargetFor / degrading.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_MixedLegWeightedBufferPool is UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_MixedLegFixture(_ctx(), address(0));
    }
}
