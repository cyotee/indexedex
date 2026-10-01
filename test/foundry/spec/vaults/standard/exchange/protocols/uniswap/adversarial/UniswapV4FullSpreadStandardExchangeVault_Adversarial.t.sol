// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial} from "./TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol";
/// @dev K1: live-book donor loss. M1/M2: no arbitrary target/calldata. N1: no bond hook.
/// O1/O2: no Permit2 deposit entry; share permit negatives remain in release tests.
contract UniswapV4FullSpreadStandardExchangeVault_Adversarial is TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial {
}
