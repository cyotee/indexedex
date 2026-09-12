// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_PonsV2Pool_Decimals} from
    "test/foundry/spec/protocols/dexes/uniswap/v4/pons/decimals/UniswapV4StandardExchange_PonsV2Pool_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA.
contract UniswapV4StandardExchange_PonsV2Pool_P18_R6 is UniswapV4StandardExchange_PonsV2Pool_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
