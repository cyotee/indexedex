// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopV3Market_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopV3Market_Decimals.sol";
/// @notice Combo `P9_R6`. pairToken = tokenA.
contract AaveCrossVersionLoopV3Market_P9_R6 is AaveCrossVersionLoopV3Market_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
