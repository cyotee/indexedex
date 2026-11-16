// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {UniswapV4SingleSEBufferHook_SeMatrixBehavior} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol";

/// @notice M14 decimal combination: AaveCrossVersionLoop on a 9-decimal face token (`_F9`). The fixture
///         stands up the family's Crane Aave market at tokenA (the face) at 9 decimals; the matrix behavior binds every
///         face leg to the fixture and redeploys the hook through its package, so the face decimals are
///         the fixture's. The SE vaultShare stays 18. Same ten row controls as the 18-decimal row.
contract UniswapV4SingleSEBufferHook_SeMatrix_AaveCrossVersionLoop_F9 is UniswapV4SingleSEBufferHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 9);
    }
}
