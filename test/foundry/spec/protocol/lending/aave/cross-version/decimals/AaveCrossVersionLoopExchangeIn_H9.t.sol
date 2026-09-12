// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {AaveCrossVersionLoopExchangeIn_Decimals} from
    "test/foundry/spec/protocol/lending/aave/cross-version/decimals/AaveCrossVersionLoopExchangeIn_Decimals.sol";
/// @notice Combo `H9`.
contract AaveCrossVersionLoopExchangeIn_H9 is AaveCrossVersionLoopExchangeIn_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
