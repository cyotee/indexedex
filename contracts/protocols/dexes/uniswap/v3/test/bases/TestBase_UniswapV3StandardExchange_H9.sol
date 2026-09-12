// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV3StandardExchange_Decimals} from
    "contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_Decimals.sol";

/// @notice Combo `H9`: both tokens 9-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract TestBase_UniswapV3StandardExchange_H9 is TestBase_UniswapV3StandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
