// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4WeightedSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
/// @notice Book `B_P6_R18`. pairToken (construction 0) 6-dec; next 18; remaining 18. After address sort slots permute.
abstract contract TestBase_UniswapV4WeightedSwapHook_B_P6_R18 is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function _bookDec(uint256 i) internal pure override returns (uint8) {
        if (i == 0) return 6;
        if (i == 1) return 18;
        return 18;
    }
}
