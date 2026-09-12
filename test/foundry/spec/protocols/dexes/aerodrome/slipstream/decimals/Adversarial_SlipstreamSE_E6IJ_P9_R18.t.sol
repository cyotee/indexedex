// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_SlipstreamSE_E6IJ_Decimals} from
    "test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/Adversarial_SlipstreamSE_E6IJ_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA.
contract Adversarial_SlipstreamSE_E6IJ_P9_R18 is Adversarial_SlipstreamSE_E6IJ_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
