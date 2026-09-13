// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchangeIn_Swap_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchangeIn_Swap_Decimals.sol";
/// @notice Combo `H9`. pairToken = tokenA at 9-dec; other token 9-dec.
contract CamelotV2StandardExchangeIn_Swap_H9 is CamelotV2StandardExchangeIn_Swap_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
