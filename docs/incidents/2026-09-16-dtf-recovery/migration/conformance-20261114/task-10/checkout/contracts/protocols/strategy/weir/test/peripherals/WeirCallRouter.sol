// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

/// @notice Opens a sync, calls while the manager is unlocked, or catches a nested call.
contract WeirCallRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;

    IPoolManager public immutable poolManager;

    error NotPoolManager();

    constructor(IPoolManager manager) {
        poolManager = manager;
    }

    receive() external payable {}

    function syncThen(Currency currency, address target, bytes calldata data, uint256 value)
        external
        payable
        returns (bool ok, bytes memory ret)
    {
        poolManager.sync(currency);
        (ok, ret) = target.call{value: value}(data);
    }

    function callWhileUnlocked(address target, bytes calldata data) external returns (bytes memory) {
        return poolManager.unlock(abi.encode(uint8(1), target, data));
    }

    function callCaught(address target, bytes calldata data) external returns (bool ok, bytes memory ret) {
        bytes memory raw = poolManager.unlock(abi.encode(uint8(2), target, data));
        return abi.decode(raw, (bool, bytes));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (uint8 op, address target, bytes memory inner) = abi.decode(data, (uint8, address, bytes));
        (bool ok, bytes memory ret) = target.call(inner);
        if (op == 1) {
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
            return ret;
        }
        return abi.encode(ok, ret);
    }
}
