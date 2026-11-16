// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4WeightedSwapHook_N2_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/weighted/decimals/UniswapV4WeightedSwapHook_N2_Decimals.sol";
/// @notice Combo `H6`. pairToken 6-dec; rateAsset 6-dec. After address sort t0/t1 may permute.
contract UniswapV4WeightedSwapHook_N2_H6 is UniswapV4WeightedSwapHook_N2_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 6; }
}
