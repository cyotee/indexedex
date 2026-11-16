// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/// @notice External payment token that probes the real caller's lock during a pull.
contract HostileCallbackERC20 is MintableERC20Decimals {
    address public target;
    bytes public callback;
    uint256 public attempts;
    bool public succeeded;
    bytes4 public errorSelector;
    bool private armed;
    constructor(uint8 decimals_) MintableERC20Decimals("Callback payment", "CALL", decimals_) {}

    function arm(address target_, bytes memory callback_) external {
        target = target_;
        callback = callback_;
        armed = true;
        attempts = 0;
        succeeded = false;
        errorSelector = bytes4(0);
    }

    function transferFrom(address from_, address to_, uint256 amount_) external override returns (bool) {
        if (armed && msg.sender == target && to_ == target) {
            armed = false;
            ++attempts;
            bytes memory result_;
            (succeeded, result_) = target.call(callback);
            if (result_.length >= 4) errorSelector = bytes4(result_);
        }
        uint256 allowed_ = allowance[from_][msg.sender];
        if (allowed_ != type(uint256).max) {
            require(allowed_ >= amount_, "allowance");
            allowance[from_][msg.sender] = allowed_ - amount_;
        }
        _transfer(from_, to_, amount_);
        return true;
    }
}
