// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_StataFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_StataFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20 / R10.3: dual-CP buffer hook x AaveV3StataStandardExchange. The M13 deferral (this heavy
///         family on the single-CP hook only) is lifted: the stata fixture now discriminates its package
///         salt by the fixture address, so both dual legs stand up a distinct Aave market, stata and SE.
///         The ten row controls come from the behavior unchanged.
contract UniswapV4DualSEBCPHook_SeMatrix_AaveV3StataStandardExchange is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    function _newFixture() internal override returns (SeMatrixFixture) {
        return new SeMatrix_StataFixture(_ctx(), address(0), 18);
    }
}
