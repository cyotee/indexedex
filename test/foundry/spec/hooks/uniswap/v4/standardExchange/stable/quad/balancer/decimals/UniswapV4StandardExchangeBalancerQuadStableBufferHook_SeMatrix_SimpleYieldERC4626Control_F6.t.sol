// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_SimpleYieldERC4626ControlFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_ERC4626Fixture.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice M14 decimal combination: stable/quad/balancer x SimpleYieldERC4626Control with a 6-decimal face token
///         (`_F6`). The matrix behavior binds every face leg to the fixture and redeploys the hook
///         through its package, so the face decimals are the fixture's; the family's `_Decimals`
///         TestBase only varies base-owned tokens the rows never bind (open item 1 PRD M14 / A10,
///         2026-09-23 record). Same ten row controls as the 18-decimal row.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F6 is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_SimpleYieldERC4626ControlFixture(_ctx(), erc4626StandardExchangeDFPkg, 6);
    }
}
