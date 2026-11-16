// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals.sol";
/// @notice n=8 smoke book `B_P6_R18`. pairToken 6-dec; remaining 18.
contract UniswapV4StandardExchangeWeightedBufferHook_N8_B_P6_R18 is
    UniswapV4StandardExchangeWeightedBufferHook_N8_Decimals
{
    function _bookDec(uint256 i) internal pure override returns (uint8) {
        if (i == 0) return 6;
        if (i == 1) return 18;
        return 18;
    }
}
