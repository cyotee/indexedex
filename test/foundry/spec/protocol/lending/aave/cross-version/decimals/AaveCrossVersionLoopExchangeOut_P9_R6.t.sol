// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopExchangeOut_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopExchangeOut_Decimals.sol";
/// @notice Combo `P9_R6`.
contract AaveCrossVersionLoopExchangeOut_P9_R6 is AaveCrossVersionLoopExchangeOut_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
