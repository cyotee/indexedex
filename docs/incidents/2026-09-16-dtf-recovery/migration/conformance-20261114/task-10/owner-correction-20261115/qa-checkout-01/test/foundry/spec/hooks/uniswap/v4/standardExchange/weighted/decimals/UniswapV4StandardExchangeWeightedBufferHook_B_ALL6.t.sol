// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals.sol";
/// @notice Book `B_ALL6`. pairToken (construction 0) 6-dec; next 6; remaining 6. After address sort slots permute.
contract UniswapV4StandardExchangeWeightedBufferHook_B_ALL6 is
    UniswapV4StandardExchangeWeightedBufferHook_NLeg_Decimals
{
    function _bookDec(uint256 i) internal pure override returns (uint8) {
        if (i == 0) return 6;
        if (i == 1) return 6;
        return 6;
    }
}
