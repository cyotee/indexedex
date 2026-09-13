// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Non-SUT fee-on-transfer token. Wrapper settlement must reject it.
contract TaxedERC20Harness {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public taxBps;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 taxBps_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        taxBps = taxBps_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setTaxBps(uint256 value) external {
        require(value <= 10_000, "invalid tax");
        taxBps = value;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _taxedMove(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _taxedMove(from, to, amount);
        return true;
    }

    function _taxedMove(address from, address to, uint256 amount) internal {
        uint256 tax = (amount * taxBps) / 10_000;
        uint256 sent = amount - tax;
        balanceOf[from] -= amount;
        balanceOf[to] += sent;
        if (tax > 0) totalSupply -= tax;
        emit Transfer(from, to, sent);
        if (tax > 0) emit Transfer(from, address(0), tax);
    }
}
