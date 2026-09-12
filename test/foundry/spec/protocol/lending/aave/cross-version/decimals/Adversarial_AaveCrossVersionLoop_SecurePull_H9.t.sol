// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_AaveCrossVersionLoop_SecurePull_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/Adversarial_AaveCrossVersionLoop_SecurePull_Decimals.sol";
/// @notice Combo `H9`. pairToken = tokenA.
contract Adversarial_AaveCrossVersionLoop_SecurePull_H9 is Adversarial_AaveCrossVersionLoop_SecurePull_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
