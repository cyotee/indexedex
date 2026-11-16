// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchangeIn_Swap_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchangeIn_Swap_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA at 6-dec; other token 6-dec.
contract CamelotV2StandardExchangeIn_Swap_H6 is CamelotV2StandardExchangeIn_Swap_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
