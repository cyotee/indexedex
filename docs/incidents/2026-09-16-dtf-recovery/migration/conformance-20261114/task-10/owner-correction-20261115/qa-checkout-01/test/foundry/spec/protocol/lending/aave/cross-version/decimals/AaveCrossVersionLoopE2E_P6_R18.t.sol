// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopE2E_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopE2E_Decimals.sol";
/// @notice Combo `P6_R18`. pairToken = tokenA.
contract AaveCrossVersionLoopE2E_P6_R18 is AaveCrossVersionLoopE2E_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
