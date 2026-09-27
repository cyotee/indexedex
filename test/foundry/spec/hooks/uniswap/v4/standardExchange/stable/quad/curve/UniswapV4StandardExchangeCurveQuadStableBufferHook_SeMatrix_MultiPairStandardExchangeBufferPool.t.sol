// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_MultiPairFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_MultiPairFixture.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice R10.3: UniswapV4StandardExchangeCurveQuadStableBufferHook x MultiPairStandardExchangeBufferPool (GOLD). The Balancer V3 buffer-pool SE now implements
///         IStandardExchangeTransitionQuote (0x185ec0ef / quoteState 0x844c633c), so the buffered
///         hook projects this SE for wei-exact previews instead of reverting NoTargetFor / degrading.
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool is UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_MultiPairFixture(_ctx(), address(0));
    }
}
