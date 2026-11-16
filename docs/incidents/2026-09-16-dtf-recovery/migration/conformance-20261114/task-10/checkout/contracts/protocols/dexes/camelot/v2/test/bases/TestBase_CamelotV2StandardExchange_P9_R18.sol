// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA at 9-dec; other token 18-dec.
abstract contract TestBase_CamelotV2StandardExchange_P9_R18 is TestBase_CamelotV2StandardExchange_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
