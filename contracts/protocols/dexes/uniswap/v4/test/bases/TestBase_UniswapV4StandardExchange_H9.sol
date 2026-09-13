// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4StandardExchange_Decimals} from
    "contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange_Decimals.sol";
/// @notice Combo `H9`. pairToken = tokenA at 9-dec; other token 9-dec.
abstract contract TestBase_UniswapV4StandardExchange_H9 is TestBase_UniswapV4StandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
