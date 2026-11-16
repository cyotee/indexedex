// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol";

/// @notice M14 decimal combination: AaveV3StataStandardExchange on a 9-decimal face token (`_F9`). The fixture
///         stands up the family's Crane Aave market at the listed 9-decimal NINE reserve; the matrix behavior binds every
///         face leg to the fixture and redeploys the hook through its package, so the face decimals are
///         the fixture's. The SE vaultShare stays 18. Same ten row controls as the 18-decimal row.
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_AaveV3StataStandardExchange_F9 is UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 9);
    }
}
