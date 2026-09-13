// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Adversarial_SecRemediation_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/Adversarial_SecRemediation_Decimals.sol";

/// @notice Combo `P9_R18`: pairToken (tokenA) 9-dec, other (tokenB) 18-dec. After pool address sort, `_u0`/`_u1` follow token0/token1.
contract Adversarial_SecRemediation_P9_R18 is Adversarial_SecRemediation_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
