// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV3StandardExchange_Import_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/UniswapV3StandardExchange_Import_Decimals.sol";

/// @notice Combo `H9`: both tokens 9-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract UniswapV3StandardExchange_Import_H9 is UniswapV3StandardExchange_Import_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
