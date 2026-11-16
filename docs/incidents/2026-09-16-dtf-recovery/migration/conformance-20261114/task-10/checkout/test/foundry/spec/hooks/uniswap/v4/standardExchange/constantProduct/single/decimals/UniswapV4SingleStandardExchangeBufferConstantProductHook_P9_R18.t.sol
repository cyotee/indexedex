// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/decimals/UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol";

/// @notice Combo `P9_R18`. pairToken 9-dec, rawToken 18-dec.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_P9_R18 is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals
{
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rawDecimals() internal pure override returns (uint8) { return 18; }
}
