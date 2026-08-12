// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from
    "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title WrapperExactOutRouter
 * @notice Test router for Uni V4 wrapper hooks: settle-before-swap for exact-out so
 *         hook `_take` during beforeSwap has physical tokens on the PoolManager.
 * @dev Exact-in also settles before swap (same as Crane TestRouter).
 *      Exact-out: caller supplies `maxAmountIn`; router settles that first, swaps exact-out,
 *      then refunds any unused input credit and delivers output.
 */
contract WrapperExactOutRouter is IUnlockCallback {
    using TransientStateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;

    IPoolManager public immutable manager;

    error ExactOutRequiresPositiveAmount();
    error ZeroMaxIn();

    struct CallbackData {
        address sender;
        PoolKey key;
        SwapParams params;
        bytes hookData;
        uint256 maxAmountIn; // required for exact-out; ignored for exact-in
    }

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    function swapExactIn(PoolKey memory key, SwapParams memory params, bytes memory hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        require(params.amountSpecified < 0, "exact-in only");
        delta = abi.decode(
            manager.unlock(abi.encode(CallbackData(msg.sender, key, params, hookData, 0))), (BalanceDelta)
        );
    }

    /// @notice Exact-out swap with settle-before-take. `maxAmountIn` must cover previewed input.
    function swapExactOut(
        PoolKey memory key,
        SwapParams memory params,
        uint256 maxAmountIn,
        bytes memory hookData
    ) external payable returns (BalanceDelta delta) {
        if (params.amountSpecified <= 0) revert ExactOutRequiresPositiveAmount();
        if (maxAmountIn == 0) revert ZeroMaxIn();
        delta = abi.decode(
            manager.unlock(abi.encode(CallbackData(msg.sender, key, params, hookData, maxAmountIn))),
            (BalanceDelta)
        );
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager), "not manager");
        CallbackData memory data = abi.decode(rawData, (CallbackData));

        (Currency inputCurrency, Currency outputCurrency) = data.params.zeroForOne
            ? (data.key.currency0, data.key.currency1)
            : (data.key.currency1, data.key.currency0);

        if (data.params.amountSpecified < 0) {
            // exact-in: settle specified input, swap, take output
            uint256 amountIn = uint256(-data.params.amountSpecified);
            _settle(inputCurrency, data.sender, amountIn);
            BalanceDelta delta = manager.swap(data.key, data.params, data.hookData);
            _takeCredit(outputCurrency, data.sender);
            return abi.encode(delta);
        }

        // exact-out: settle max input first so hook can take amountIn during beforeSwap
        _settle(inputCurrency, data.sender, data.maxAmountIn);
        BalanceDelta delta = manager.swap(data.key, data.params, data.hookData);
        // Deliver output credit to user
        _takeCredit(outputCurrency, data.sender);
        // Refund unused input (maxAmountIn - spent) if still credited to this router
        _takeCredit(inputCurrency, data.sender);
        return abi.encode(delta);
    }

    function _settle(Currency currency, address payer, uint256 amount) internal {
        if (amount == 0) return;
        manager.sync(currency);
        address token = Currency.unwrap(currency);
        if (payer != address(this)) {
            IERC20(token).transferFrom(payer, address(manager), amount);
        } else {
            IERC20(token).transfer(address(manager), amount);
        }
        manager.settle();
    }

    function _takeCredit(Currency currency, address to) internal {
        int256 delta = manager.currencyDelta(address(this), currency);
        if (delta > 0) {
            manager.take(currency, to, uint256(delta));
        }
    }
}
