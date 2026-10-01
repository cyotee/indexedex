// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: dual-CP buffer hook x AaveCrossVersionLoop. The M13 deferral (this heavy family
///         on the single-CP hook only) is lifted: the loop fixture now discriminates its package salt by
///         the fixture address, so both dual legs bind a distinct Aave market, loop package and SE. The
///         ten row controls come from the behavior unchanged.
contract UniswapV4DualSEBCPHook_SeMatrix_AaveCrossVersionLoop is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 18);
    }
}
