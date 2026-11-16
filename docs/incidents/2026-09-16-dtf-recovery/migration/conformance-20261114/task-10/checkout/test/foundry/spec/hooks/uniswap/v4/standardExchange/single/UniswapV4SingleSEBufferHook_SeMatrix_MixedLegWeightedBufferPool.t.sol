// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_MixedLegFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_MixedLegFixture.sol";
import {UniswapV4SingleSEBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice R10.3: UniswapV4SingleSEBufferHook x MixedLegWeightedBufferPool (GOLD). The Balancer V3 buffer-pool SE implements
///         IStandardExchangeTransitionQuote (0x185ec0ef / quoteState 0x844c633c) so the buffered hook
///         projects it for wei-exact previews, and D69 closed the execution gap this row was DEFERRED
///         for (single SE buffer hook unwrap legs now forceApprove the SE share for the pull-based BPT route), so every row control runs against the pool SE.
contract UniswapV4SingleSEBufferHook_SeMatrix_MixedLegWeightedBufferPool is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_MixedLegFixture(_ctx(), address(0));
    }
}
