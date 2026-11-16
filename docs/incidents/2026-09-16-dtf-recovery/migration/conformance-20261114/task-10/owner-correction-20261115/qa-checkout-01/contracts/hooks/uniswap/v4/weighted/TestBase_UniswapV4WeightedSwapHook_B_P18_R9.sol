// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4WeightedSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
/// @notice Book `B_P18_R9`. pairToken (construction 0) 18-dec; next 9; remaining 18. After address sort slots permute.
abstract contract TestBase_UniswapV4WeightedSwapHook_B_P18_R9 is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function _bookDec(uint256 i) internal pure override returns (uint8) {
        if (i == 0) return 18;
        if (i == 1) return 9;
        return 18;
    }
}
