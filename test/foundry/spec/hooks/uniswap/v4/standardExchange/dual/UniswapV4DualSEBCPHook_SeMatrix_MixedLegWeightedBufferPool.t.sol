// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_MixedLegFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_MixedLegFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual-CP x MixedLegWeightedBufferPool. Written under D60 acceptance A7 (2026-09-22), replacing the
///         M13 deferral: both legs (M4) bind an instance of the Balancer V3 mixed-leg weighted buffer pool,
///         each priced by a `StandardExchangeRateProvider` (the behavior's D60 `PkgArgs`). The same fixture
///         the single-CP host row uses; the ten row controls come from the behavior unchanged.
contract UniswapV4DualSEBCPHook_SeMatrix_MixedLegWeightedBufferPool is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_MixedLegFixture(_ctx(), address(0));
    }
}
