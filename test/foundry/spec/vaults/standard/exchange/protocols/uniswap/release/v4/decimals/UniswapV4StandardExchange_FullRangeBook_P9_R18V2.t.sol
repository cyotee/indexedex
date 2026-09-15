// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_FullRangeBook_DecimalsV2} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/decimals/UniswapV4StandardExchange_FullRangeBook_DecimalsV2.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA.
contract UniswapV4StandardExchange_FullRangeBook_P9_R18V2 is UniswapV4StandardExchange_FullRangeBook_DecimalsV2 {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
