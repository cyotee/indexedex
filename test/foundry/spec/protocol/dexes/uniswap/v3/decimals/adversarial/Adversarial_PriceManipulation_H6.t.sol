// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_PriceManipulation_Decimals_ProDexUniV3} from
    "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/Adversarial_PriceManipulation_Decimals.sol";

/// @notice Combo `H6`: both tokens 6-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract Adversarial_PriceManipulation_H6 is Adversarial_PriceManipulation_Decimals_ProDexUniV3 {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
