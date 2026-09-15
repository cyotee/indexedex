// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @dev External test asset with real balances, allowances, optional transfer fee
/// and a callback. No vault/pool/accounting code is mocked.
contract DeliveryTestToken {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public chargeFee;
    address public callbackTarget;
    bytes public callbackData;
    bytes public callbackError;
    constructor(string memory n, string memory s, uint8 d, address recipient, uint256 initial) {
        name = n; symbol = s; decimals = d; _mint(recipient, initial);
    }
    function mint(address to, uint256 amount) external returns (bool) { _mint(to, amount); return true; }
    function _mint(address to, uint256 amount) private { balanceOf[to] += amount; totalSupply += amount; }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount; return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount); return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        if (callbackTarget != address(0)) {
            (bool ok, bytes memory reason) = callbackTarget.call(callbackData);
            require(!ok, "reentry unexpectedly succeeded");
            callbackError = reason;
        }
        return true;
    }
    function _transfer(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount;
        uint256 fee = chargeFee ? amount / 100 : 0;
        balanceOf[to] += amount - fee;
        totalSupply -= fee;
    }
    function setFee(bool enabled) external { chargeFee = enabled; }
    function setCallback(address target, bytes calldata data) external { callbackTarget = target; callbackData = data; }
}
