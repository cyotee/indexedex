// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Decimals} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA at 6-dec; other token 6-dec.
abstract contract TestBase_UniswapV4FullSpreadPonsFamilyHook_H6 is TestBase_UniswapV4FullSpreadPonsFamilyHook_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
