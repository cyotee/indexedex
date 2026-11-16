// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CamelotFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CamelotFixture.sol";
import {
    UniswapV4DualSEBCPHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol";

/// @notice D20: dual-CP × CamelotV2StandardExchange. Face: 18-decimal pair token A of a seeded hermetic Camelot V2 pair; SE shares 27 decimals (reserve 18 + 9).
contract UniswapV4DualSEBCPHook_SeMatrix_CamelotV2StandardExchange is UniswapV4DualSEBCPHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_CamelotFixture f = new SeMatrix_CamelotFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }
}
