// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Adversarial_UniswapV4SE_SecurePull_Decimals} from
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/adversarial/Adversarial_UniswapV4SE_SecurePull_Decimals.sol";
/// @notice Combo `P9_R18`. pairToken = tokenA.
contract Adversarial_UniswapV4SE_SecurePull_P9_R18 is Adversarial_UniswapV4SE_SecurePull_Decimals {
    function _tokenADecimals() internal pure override returns (uint8) { return 9; }
    function _tokenBDecimals() internal pure override returns (uint8) { return 18; }
}
