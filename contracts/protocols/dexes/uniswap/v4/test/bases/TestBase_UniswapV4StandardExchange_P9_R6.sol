// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4StandardExchange_Decimals} from
    "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange_Decimals.sol";
/// @notice Combo `P9_R6`. pairToken = tokenA at 9-dec; other token 6-dec.
abstract contract TestBase_UniswapV4StandardExchange_P9_R6 is TestBase_UniswapV4StandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
