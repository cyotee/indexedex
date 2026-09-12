// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_FullRangeBook_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol";
/// @notice Combo `P6_R9`. pairToken = tokenA.
contract UniswapV4StandardExchange_FullRangeBook_P6_R9 is UniswapV4StandardExchange_FullRangeBook_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
