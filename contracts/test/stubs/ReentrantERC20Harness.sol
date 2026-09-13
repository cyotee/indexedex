// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Non-SUT token that optionally reenters a target during transferFrom.
contract ReentrantERC20Harness {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public reenterTarget;
    bytes public reenterPayload;
    bool public callbackOnTransfer;

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

    function setReenter(address target, bytes calldata payload) external {
        reenterTarget = target;
        reenterPayload = payload;
    }

    function setCallbackOnTransfer(bool enabled) external {
        callbackOnTransfer = enabled;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        if (callbackOnTransfer) _callback();
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _move(from, to, amount);
        _callback();
        return true;
    }

    function _callback() private {
        if (reenterTarget != address(0) && reenterPayload.length > 0) {
            (bool ok,) = reenterTarget.call(reenterPayload);
            require(ok, "reenter-failed");
        }
    }

    function _move(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
