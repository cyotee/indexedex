// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol";
import {SafeERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

/// @title WeirBase
/// @notice Shared plumbing for contracts that act on the V4 PoolManager directly:
/// pulling funds from users, paying and taking balances inside an unlock, and refunds.
/// Native ETH is a first-class currency (Currency address(0)); nothing is wrapped.
abstract contract WeirBase is IUnlockCallback {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    IPoolManager public immutable poolManager;

    error NotPoolManager();
    error Expired();
    error BadNativeAmount();
    error NativeTransferFailed();

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /// @dev Native ETH arrives from users and from PoolManager.take.
    receive() external payable {}

    /// @dev Pull `amount` of `c` from `from` into this contract. Native must come as msg.value;
    /// the caller checks the total msg.value against every native leg.
    function _pull(Currency c, address from, uint256 amount) internal {
        if (amount == 0 || c.isAddressZero()) return;
        IERC20(Currency.unwrap(c)).safeTransferFrom(from, address(this), amount);
    }

    /// @dev msg.value must equal exactly the native legs of a call, never more, never less.
    function _checkNative(Currency c0, uint256 a0, Currency c1, uint256 a1) internal view {
        uint256 expected = (c0.isAddressZero() ? a0 : 0) + (c1.isAddressZero() ? a1 : 0);
        if (msg.value != expected) revert BadNativeAmount();
    }

    /// @dev Pay `amount` of `c` that this contract owes the PoolManager, from its own balance.
    function _pay(Currency c, uint256 amount) internal {
        if (amount == 0) return;
        if (c.isAddressZero()) {
            poolManager.settle{value: amount}();
        } else {
            poolManager.sync(c);
            IERC20(Currency.unwrap(c)).safeTransfer(address(poolManager), amount);
            poolManager.settle();
        }
    }

    /// @dev Take `amount` of `c` that the PoolManager owes this contract, straight to `to`.
    function _take(Currency c, address to, uint256 amount) internal {
        if (amount > 0) poolManager.take(c, to, amount);
    }

    /// @dev Zero out a net delta: pay what is owed, take what is credited (to `to`).
    function _settle(Currency c, int256 net, address to) internal {
        if (net < 0) _pay(c, uint256(-net));
        else if (net > 0) _take(c, to, uint256(net));
    }

    /// @dev Send funds held by this contract.
    function _send(Currency c, address to, uint256 amount) internal {
        if (amount == 0) return;
        if (c.isAddressZero()) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert NativeTransferFailed();
        } else {
            IERC20(Currency.unwrap(c)).safeTransfer(to, amount);
        }
    }
}
