// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_AaveCrossVersionLoop_SecurePull_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/Adversarial_AaveCrossVersionLoop_SecurePull_Decimals.sol";
/// @notice Combo `P9_R6`. pairToken = tokenA.
contract Adversarial_AaveCrossVersionLoop_SecurePull_P9_R6 is Adversarial_AaveCrossVersionLoop_SecurePull_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
