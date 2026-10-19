// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TevmCounter {
    uint256 public value;

    constructor(uint256 initialValue) {
        value = initialValue;
    }

    function set(uint256 nextValue) external {
        value = nextValue;
    }
}
