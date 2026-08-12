// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title HostileReentrantERC20
 * @notice Non-SUT mintable ERC20 that reenters `target` on transferFrom and records nested outcome
 *         without bubbling (outer pull can complete). Nested failure proves the SUT reentrancy guard.
 */
contract HostileReentrantERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok, bytes memory ret) = target.call(reentryCall);
            nestedCallSucceeded = ok;
            if (!ok && ret.length >= 4) {
                nestedErrorSelector = bytes4(ret[0]) | (bytes4(ret[1]) >> 8) | (bytes4(ret[2]) >> 16)
                    | (bytes4(ret[3]) >> 24);
                // portable extract first 4 bytes
                bytes4 sel;
                assembly {
                    sel := mload(add(ret, 32))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
            // do not bubble — outer transfer completes so test can assert nested outcome
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
