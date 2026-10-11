// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_BufferPoolFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BufferPoolFixture.sol";
import {BalancerSeLiquidationBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/BalancerSeLiquidationBehavior.sol";

/// @notice R10.3: UniswapV4StandardExchangeWeightedBufferHook x StandardExchangeBufferPool (GOLD). The Balancer V3 buffer-pool SE now implements
///         IStandardExchangeTransitionQuote (0x185ec0ef / quoteState 0x844c633c), so the buffered
///         hook projects this SE for wei-exact previews instead of reverting NoTargetFor / degrading.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_StandardExchangeBufferPool is BalancerSeLiquidationBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_BufferPoolFixture(_ctx(), address(0));
    }
}
