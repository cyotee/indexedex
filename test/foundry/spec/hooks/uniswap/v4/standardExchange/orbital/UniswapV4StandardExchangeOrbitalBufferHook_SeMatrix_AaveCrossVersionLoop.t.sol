// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: orbital buffer hook x AaveCrossVersionLoop (COMPATIBLE). The former SE-interface
///         gap is closed: the loop SE now implements `IStandardExchangeTransitionQuote` (selector
///         0x844c633c) through a dedicated facet that projects the loop's conservative (D61 floor/ceil)
///         redemption / withdrawal / deposit math wei-for-wei, so orbital's `test_row_previewMatchesExecution`
///         projection equals execution. Each of the three orbital legs binds a distinct Aave loop market.
///         The ten row controls come from the behavior unchanged.
contract UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_AaveCrossVersionLoop is
    UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior
{
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 18);
    }
}
