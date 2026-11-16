// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopExchangeIn_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopExchangeIn_Decimals.sol";
/// @notice Combo `P18_R9`.
contract AaveCrossVersionLoopExchangeIn_P18_R9 is AaveCrossVersionLoopExchangeIn_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 18; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
