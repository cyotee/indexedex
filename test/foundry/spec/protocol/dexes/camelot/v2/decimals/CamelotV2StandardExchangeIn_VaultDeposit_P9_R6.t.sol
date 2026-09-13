// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchangeIn_VaultDeposit_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchangeIn_VaultDeposit_Decimals.sol";
/// @notice Combo `P9_R6`. pairToken = tokenA at 9-dec; other token 6-dec.
contract CamelotV2StandardExchangeIn_VaultDeposit_P9_R6 is CamelotV2StandardExchangeIn_VaultDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
