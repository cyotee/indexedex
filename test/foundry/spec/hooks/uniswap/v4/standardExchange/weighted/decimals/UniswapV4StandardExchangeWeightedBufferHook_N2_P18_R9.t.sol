// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/decimals/UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals.sol";
/// @notice Combo `P18_R9`. pairToken 18-dec; rateAsset 9-dec. After address sort t0/t1 may permute.
contract UniswapV4StandardExchangeWeightedBufferHook_N2_P18_R9 is
    UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals
{
    function _pairDecimals() internal pure override returns (uint8) { return 18; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
