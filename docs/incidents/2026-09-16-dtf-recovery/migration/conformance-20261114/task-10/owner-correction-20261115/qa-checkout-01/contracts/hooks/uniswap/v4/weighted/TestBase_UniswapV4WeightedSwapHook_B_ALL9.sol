// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4WeightedSwapHook_Decimals} from
    "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook_Decimals.sol";
/// @notice Book `B_ALL9`. pairToken (construction 0) 9-dec; next 9; remaining 9. After address sort slots permute.
abstract contract TestBase_UniswapV4WeightedSwapHook_B_ALL9 is TestBase_UniswapV4WeightedSwapHook_Decimals {
    function _bookDec(uint256 i) internal pure override returns (uint8) {
        if (i == 0) return 9;
        if (i == 1) return 9;
        return 9;
    }
}
