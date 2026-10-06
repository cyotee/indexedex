// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_Univ4SeNestedCaller_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_Univ4SeNestedCaller_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA.
contract UniswapV4StandardExchange_Univ4SeNestedCaller_P18_R6 is UniswapV4StandardExchange_Univ4SeNestedCaller_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
