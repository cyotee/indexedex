// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV2StandardExchange_InOutInvariant_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchange_InOutInvariant_Decimals.sol";

/// @notice Combo `H6`. pairToken (tokenA) = 6 decimals; other (tokenB) = 6 decimals.
/// @dev After Uniswap pair address sort, token0/token1 may swap; roles stay pairToken vs other.
contract UniswapV2StandardExchange_InOutInvariant_H6 is UniswapV2StandardExchange_InOutInvariant_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 6;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 6;
    }
}
