// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV3StandardExchange_Previews_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/UniswapV3StandardExchange_Previews_Decimals.sol";

/// @notice Combo `P6_R18`: pairToken (tokenA) 6-dec, other (tokenB) 18-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract UniswapV3StandardExchange_Previews_P6_R18 is UniswapV3StandardExchange_Previews_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
