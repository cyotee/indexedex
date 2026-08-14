// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/**
 * @title FeeOnTransferERC20
 * @notice Non-SUT harness: `transfer` and `transferFrom` deliver `amount − fee`.
 * @dev IndexedEx forbids FoT as a configured underlying. Use only as the configured
 *      token in `test_L2_FoT_forbidden`. Not a product and not a mock SUT.
 */
contract FeeOnTransferERC20 is SimpleMintableERC20 {
    uint256 public immutable feeBps;

    constructor(string memory name_, string memory symbol_, uint256 feeBps_)
        SimpleMintableERC20(name_, symbol_)
    {
        require(feeBps_ > 0 && feeBps_ < 10_000, "fee");
        feeBps = feeBps_;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transferWithFee(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transferWithFee(from, to, amount);
        return true;
    }

    function _transferWithFee(address from, address to, uint256 amount) internal {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 send = amount - fee;
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += send;
        emit Transfer(from, to, send);
    }
}
