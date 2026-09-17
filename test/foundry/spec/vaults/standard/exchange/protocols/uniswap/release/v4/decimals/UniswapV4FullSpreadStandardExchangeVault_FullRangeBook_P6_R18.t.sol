// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadStandardExchangeVault_FullRangeBook_Decimals} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/decimals/UniswapV4FullSpreadStandardExchangeVault_FullRangeBook_Decimals.sol";
/// @notice Combo `P6_R18`. pairToken = tokenA.
contract UniswapV4FullSpreadStandardExchangeVault_FullRangeBook_P6_R18 is UniswapV4FullSpreadStandardExchangeVault_FullRangeBook_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
