// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_FullRangeBook_DecimalsV2} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/decimals/UniswapV4StandardExchange_FullRangeBook_DecimalsV2.sol";
/// @notice Combo `H6`. pairToken = tokenA.
contract UniswapV4StandardExchange_FullRangeBook_H6V2 is UniswapV4StandardExchange_FullRangeBook_DecimalsV2 {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
