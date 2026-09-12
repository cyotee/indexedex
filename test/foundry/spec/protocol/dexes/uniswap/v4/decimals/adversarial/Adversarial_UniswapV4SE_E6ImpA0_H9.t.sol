// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_UniswapV4SE_E6ImpA0_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/adversarial/Adversarial_UniswapV4SE_E6ImpA0_Decimals.sol";
/// @notice Combo `H9`. pairToken = tokenA.
contract Adversarial_UniswapV4SE_E6ImpA0_H9 is Adversarial_UniswapV4SE_E6ImpA0_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 9; }
}
