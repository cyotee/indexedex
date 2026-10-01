// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Decimals} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/test/bases/TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA at 18-dec; other token 6-dec.
abstract contract TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_P18_R6 is TestBase_UniswapV4FullSpreadHooklessStandardExchangeVault_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
