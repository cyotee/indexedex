// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchange_InOutInvariant_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchange_InOutInvariant_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA at 18-dec; other token 6-dec.
/// forge-config: default.fuzz.runs = 64
contract CamelotV2StandardExchange_InOutInvariant_P18_R6 is CamelotV2StandardExchange_InOutInvariant_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
