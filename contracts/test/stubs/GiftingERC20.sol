// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/**
 * @title GiftingERC20
 * @notice On transferFrom of `amount`, also moves `gift` extra to recipient (if sender funded).
 * @dev Used to produce pretransfer/pull surplus for refund/dust SE tests (non-SUT harness).
 */
contract GiftingERC20 is SimpleMintableERC20 {
    uint256 public gift;

    constructor(string memory name_, string memory symbol_) SimpleMintableERC20(name_, symbol_) {}

    function setGift(uint256 gift_) external {
        gift = gift_;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        if (gift > 0 && balanceOf[from] >= gift) {
            _transfer(from, to, gift);
        }
        return true;
    }
}
