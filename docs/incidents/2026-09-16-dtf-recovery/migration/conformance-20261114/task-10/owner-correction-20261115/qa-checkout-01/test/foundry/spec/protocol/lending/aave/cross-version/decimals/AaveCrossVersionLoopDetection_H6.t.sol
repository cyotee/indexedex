// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopDetection_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopDetection_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA.
contract AaveCrossVersionLoopDetection_H6 is AaveCrossVersionLoopDetection_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
