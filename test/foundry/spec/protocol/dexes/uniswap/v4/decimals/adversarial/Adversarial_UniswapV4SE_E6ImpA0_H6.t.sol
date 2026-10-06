// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_UniswapV4SE_E6ImpA0_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/adversarial/Adversarial_UniswapV4SE_E6ImpA0_Decimals.sol";
/// @notice Combo `H6`. pairToken = tokenA.
contract Adversarial_UniswapV4SE_E6ImpA0_H6 is Adversarial_UniswapV4SE_E6ImpA0_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 6; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 6; }
}
