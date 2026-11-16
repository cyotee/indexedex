// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopExchangeIn_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopExchangeIn_Decimals.sol";
/// @notice Combo `P6_R18`.
contract AaveCrossVersionLoopExchangeIn_P6_R18 is AaveCrossVersionLoopExchangeIn_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
