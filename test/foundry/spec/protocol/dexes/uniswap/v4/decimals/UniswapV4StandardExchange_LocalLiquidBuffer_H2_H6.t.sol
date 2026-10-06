// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchange_LocalLiquidBuffer_H2_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_LocalLiquidBuffer_H2_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA.
contract UniswapV4StandardExchange_LocalLiquidBuffer_H2_H6 is UniswapV4StandardExchange_LocalLiquidBuffer_H2_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
