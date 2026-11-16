// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/// @notice External token fixture that propagates an actual forbidden parent callback.
contract MigrationPermit2Callback is SimpleMintableERC20 {
    address public parent;
    address public bond;

    constructor() SimpleMintableERC20("External Permit2 callback fixture", "PCB") {}

    function arm(address parent_, address bond_) external { parent = parent_; bond = bond_; }

    function transferFrom(address from_, address to_, uint256 amount_) external override returns (bool) {
        uint256 allowed_ = allowance[from_][msg.sender];
        require(allowed_ >= amount_, "allowance");
        if (allowed_ != type(uint256).max) allowance[from_][msg.sender] = allowed_ - amount_;
        _transfer(from_, to_, amount_);
        if (msg.sender == parent && from_ == bond) {
            (bool ok_, bytes memory reason_) = parent.call(abi.encodeWithSignature("synchronizeRewards()"));
            require(!ok_, "forbidden token callback admitted");
            assembly ("memory-safe") { revert(add(reason_, 32), mload(reason_)) }
        }
        return true;
    }
}
