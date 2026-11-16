// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4WeightedSwapHook_N2_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/weighted/decimals/UniswapV4WeightedSwapHook_N2_Decimals.sol";
/// @notice Combo `H9`. pairToken 9-dec; rateAsset 9-dec. After address sort t0/t1 may permute.
contract UniswapV4WeightedSwapHook_N2_H9 is UniswapV4WeightedSwapHook_N2_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 9; }
}
