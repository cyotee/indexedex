// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Non-SUT rebasing ERC20 with no DETF API. Optional transfer-triggered supply change.
contract RebasingERC20Harness {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    int256 public rebaseOnTransfer;
    address public rebaseRecipient;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setRebaseOnTransfer(int256 delta, address recipient) external {
        rebaseOnTransfer = delta;
        rebaseRecipient = recipient;
    }

    function rebase(address holder, int256 delta) external {
        _apply(holder, delta);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        _maybeRebase();
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _move(from, to, amount);
        _maybeRebase();
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _maybeRebase() internal {
        if (rebaseOnTransfer == 0) return;
        address target = rebaseRecipient == address(0) ? address(this) : rebaseRecipient;
        _apply(target, rebaseOnTransfer);
    }

    function _apply(address holder, int256 delta) internal {
        if (delta > 0) {
            uint256 amt = uint256(delta);
            totalSupply += amt;
            balanceOf[holder] += amt;
            emit Transfer(address(0), holder, amt);
        } else if (delta < 0) {
            uint256 amt = uint256(-delta);
            uint256 bal = balanceOf[holder];
            if (amt > bal) amt = bal;
            balanceOf[holder] -= amt;
            totalSupply -= amt;
            emit Transfer(holder, address(0), amt);
        }
    }
}
