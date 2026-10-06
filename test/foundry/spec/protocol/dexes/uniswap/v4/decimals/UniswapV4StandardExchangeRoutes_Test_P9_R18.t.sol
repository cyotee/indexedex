// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeRoutes_Test_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchangeRoutes_Test_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA.
contract UniswapV4StandardExchangeRoutes_Test_P9_R18 is UniswapV4StandardExchangeRoutes_Test_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
