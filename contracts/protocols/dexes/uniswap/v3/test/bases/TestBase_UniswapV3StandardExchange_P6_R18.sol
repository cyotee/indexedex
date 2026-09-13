// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV3StandardExchange_Decimals} from
    "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";

/// @notice Combo `P6_R18`: pairToken (tokenA) 6-dec, other (tokenB) 18-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
abstract contract TestBase_UniswapV3StandardExchange_P6_R18 is TestBase_UniswapV3StandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
