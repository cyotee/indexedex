// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopV4Market_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopV4Market_Decimals.sol";
/// @notice Combo `P18_R9`. pairToken = tokenA.
contract AaveCrossVersionLoopV4Market_P18_R9 is AaveCrossVersionLoopV4Market_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
