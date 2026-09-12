// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {CamelotV2StandardExchangeIn_VaultDeposit_Decimals} from
    "test/foundry/spec/protocol/dexes/camelot/v2/decimals/CamelotV2StandardExchangeIn_VaultDeposit_Decimals.sol";
/// @notice Combo `P6_R9`. pairToken = tokenA at 6-dec; other token 9-dec.
contract CamelotV2StandardExchangeIn_VaultDeposit_P6_R9 is CamelotV2StandardExchangeIn_VaultDeposit_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
