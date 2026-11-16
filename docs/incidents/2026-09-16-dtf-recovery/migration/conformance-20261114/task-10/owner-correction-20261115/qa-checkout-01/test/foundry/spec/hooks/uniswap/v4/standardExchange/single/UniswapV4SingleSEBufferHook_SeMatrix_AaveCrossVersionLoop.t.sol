// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: single SE buffer hook (non-CP) x AaveCrossVersionLoop (COMPATIBLE). The M13
///         deferral is lifted and the former SE-capability gap is closed: the loop SE OUT facet now
///         offers a wrap exact-out (mint) route (tokenA in for exact loop shares out), routed through the
///         same D61 conservative leverage executor as the deposit path, so the hook's pure wrap/unwrap
///         hop runs end to end. The ten row controls come from the behavior unchanged.
contract UniswapV4SingleSEBufferHook_SeMatrix_AaveCrossVersionLoop is
    UniswapV4SingleSEBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 18);
    }
}
