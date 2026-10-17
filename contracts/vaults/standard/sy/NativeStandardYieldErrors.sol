// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

abstract contract NativeStandardYieldErrors {
    error InvalidSYToken(address token);
    error InvalidSYReceiver();
    error ZeroSYAmount();
    error UnsupportedNativePayment();
    error SYMinimumNotMet(uint256 minimum, uint256 received);
}
