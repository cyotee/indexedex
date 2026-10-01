// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_BufferPoolFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BufferPoolFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual-CP x StandardExchangeBufferPool. Written under D60 acceptance A7 (2026-09-22), replacing the
///         M13 deferral: both legs (M4) bind an instance of the Balancer V3 standard-exchange buffer pool (its BPT is the SE share, D38),
///         each priced by a `StandardExchangeRateProvider` (the behavior's D60 `PkgArgs`). The same fixture
///         the single-CP host row uses; the ten row controls come from the behavior unchanged.
contract UniswapV4DualSEBCPHook_SeMatrix_StandardExchangeBufferPool is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_BufferPoolFixture(_ctx(), address(0));
    }
}
