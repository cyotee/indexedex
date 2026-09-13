// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_Griefing_Decimals_ProDexUniV3} from
    "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/Adversarial_Griefing_Decimals.sol";

/// @notice Combo `P6_R9`: pairToken (tokenA) 6-dec, other (tokenB) 9-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract Adversarial_Griefing_P6_R9 is Adversarial_Griefing_Decimals_ProDexUniV3 {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
