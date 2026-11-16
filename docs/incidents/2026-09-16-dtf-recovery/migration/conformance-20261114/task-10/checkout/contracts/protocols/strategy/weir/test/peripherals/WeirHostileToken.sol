// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WeirHostileToken {
    string public name = "Hostile";
    string public symbol = "HSTL";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    enum Mode { NORMAL, FALSE_RETURN, EMPTY_RETURN, EXPLICIT_REVERT, SHORT, ZERO, CALLBACK }
    Mode public mode;
    address public callbackTarget;
    bytes public callbackData;
    uint256 public shortBy = 1;

    error HostileExplicit();

    function setMode(Mode next) external {
        mode = next;
    }

    function setCallback(address target, bytes calldata data) external {
        callbackTarget = target;
        callbackData = data;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _move(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        return _move(from, to, amount);
    }

    function _move(address from, address to, uint256 amount) internal returns (bool) {
        if (mode == Mode.EXPLICIT_REVERT) revert HostileExplicit();
        if (mode == Mode.CALLBACK && callbackTarget != address(0)) {
            (bool ok, bytes memory ret) = callbackTarget.call(callbackData);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
        uint256 delivered = amount;
        if (mode == Mode.SHORT) delivered = amount > shortBy ? amount - shortBy : 0;
        if (mode == Mode.ZERO) delivered = 0;
        if (delivered > 0) {
            balanceOf[from] -= delivered;
            balanceOf[to] += delivered;
        }
        if (mode == Mode.FALSE_RETURN) {
            assembly {
                mstore(0, 0)
                return(0, 32)
            }
        }
        if (mode == Mode.EMPTY_RETURN) {
            assembly {
                return(0, 0)
            }
        }
        return true;
    }
}
