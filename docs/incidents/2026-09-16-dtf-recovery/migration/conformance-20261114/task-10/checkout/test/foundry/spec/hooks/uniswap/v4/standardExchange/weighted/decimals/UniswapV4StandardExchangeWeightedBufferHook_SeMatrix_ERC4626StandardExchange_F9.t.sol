// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_ERC4626Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice M14 decimal combination: weighted x ERC4626StandardExchange with a 9-decimal face token
///         (`_F9`). The matrix behavior binds every face leg to the fixture and redeploys the hook
///         through its package, so the face decimals are the fixture's; the family's `_Decimals`
///         TestBase only varies base-owned tokens the rows never bind (open item 1 PRD M14 / A10,
///         2026-09-23 record). Same ten row controls as the 18-decimal row.
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_ERC4626StandardExchange_F9 is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_ERC4626Fixture(_ctx(), erc4626StandardExchangeDFPkg, 9);
    }
}
