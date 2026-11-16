// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV2StandardExchangeOut_PassThrough_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchangeOut_PassThrough_Decimals.sol";

/// @notice Combo `P18_R9`. pairToken (tokenA) = 18 decimals; other (tokenB) = 9 decimals.
/// @dev After Uniswap pair address sort, token0/token1 may swap; roles stay pairToken vs other.
contract UniswapV2StandardExchangeOut_PassThrough_P18_R9 is UniswapV2StandardExchangeOut_PassThrough_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) {
        return 18;
    }

    function _tokenBDecimals() internal pure override returns (uint8) {
        return 9;
    }
}
