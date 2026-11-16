// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4WeightedSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken 9-dec; rateAsset 18-dec. Hook LP stays 18.
abstract contract TestBase_UniswapV4WeightedSwapHook_P9_R18 is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 9; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }
}
