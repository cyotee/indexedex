// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchangeIn_SlippageProtection_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchangeIn_SlippageProtection_Decimals.sol";
/// @notice Combo `P9_R6`. pairToken = tokenA at 9-dec; other token 6-dec.
contract CamelotV2StandardExchangeIn_SlippageProtection_P9_R6 is CamelotV2StandardExchangeIn_SlippageProtection_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
