// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeDFPkg_Deploy_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchangeDFPkg_Deploy_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA.
contract UniswapV4StandardExchangeDFPkg_Deploy_H6 is UniswapV4StandardExchangeDFPkg_Deploy_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
