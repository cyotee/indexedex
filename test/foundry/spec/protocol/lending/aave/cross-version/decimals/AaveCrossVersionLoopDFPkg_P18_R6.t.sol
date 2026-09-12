// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopDFPkg_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopDFPkg_Decimals.sol";
/// @notice Combo `P18_R6`. pairToken = tokenA.
contract AaveCrossVersionLoopDFPkg_P18_R6 is AaveCrossVersionLoopDFPkg_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
