// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WeirRejectReceiver {
    error RejectedNative(bytes4 known);

    bytes4 public constant KNOWN = RejectedNative.selector;

    receive() external payable {
        revert RejectedNative(KNOWN);
    }
}
