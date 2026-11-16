// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopDetection_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopDetection_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA.
contract AaveCrossVersionLoopDetection_P9_R18 is AaveCrossVersionLoopDetection_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
