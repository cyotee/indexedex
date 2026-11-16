// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/IERC20.sol";
import {SafeERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/utils/SafeERC20.sol";

/// @notice Owned unlock router for donations, external liquidity, and exact-input swaps.
/// The caller approves this router. Native value is sent with the call and unused value is refunded.
contract WeirPoolRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using SafeERC20 for IERC20;

    enum Op { DONATE, ADD, SWAP }

    IPoolManager public immutable poolManager;

    error NotPoolManager();

    constructor(IPoolManager manager) {
        poolManager = manager;
    }

    receive() external payable {}

    function donate(PoolKey calldata key, uint256 amount0, uint256 amount1) external payable returns (BalanceDelta) {
        bytes memory raw = poolManager.unlock(abi.encode(Op.DONATE, msg.sender, key, amount0, amount1, int24(0), int24(0), int256(0), false, uint256(0), bytes("")));
        _refundNative(msg.sender);
        return abi.decode(raw, (BalanceDelta));
    }

    function addLiquidity(
        PoolKey calldata key,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes calldata hookData
    ) external payable returns (BalanceDelta) {
        bytes memory raw = poolManager.unlock(
            abi.encode(Op.ADD, msg.sender, key, uint256(0), uint256(0), tickLower, tickUpper, liquidityDelta, false, uint256(0), hookData)
        );
        _refundNative(msg.sender);
        return abi.decode(raw, (BalanceDelta));
    }

    function swapExactIn(PoolKey calldata key, bool zeroForOne, uint256 amountIn, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta)
    {
        bytes memory raw = poolManager.unlock(
            abi.encode(Op.SWAP, msg.sender, key, uint256(0), uint256(0), int24(0), int24(0), int256(0), zeroForOne, amountIn, hookData)
        );
        _refundNative(msg.sender);
        return abi.decode(raw, (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (
            Op op,
            address payer,
            PoolKey memory key,
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper,
            int256 liquidityDelta,
            bool zeroForOne,
            uint256 amountIn,
            bytes memory hookData
        ) = abi.decode(data, (Op, address, PoolKey, uint256, uint256, int24, int24, int256, bool, uint256, bytes));
        BalanceDelta delta;
        if (op == Op.DONATE) {
            delta = poolManager.donate(key, amount0, amount1, hookData);
        } else if (op == Op.ADD) {
            (delta,) = poolManager.modifyLiquidity(
                key, ModifyLiquidityParams({tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: liquidityDelta, salt: bytes32(0)}), hookData
            );
        } else {
            delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: -int256(amountIn),
                    sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                hookData
            );
        }
        _settle(key.currency0, delta.amount0(), payer);
        _settle(key.currency1, delta.amount1(), payer);
        return abi.encode(delta);
    }

    function _settle(Currency currency, int128 net, address payer) internal {
        if (net < 0) {
            uint256 owed = uint256(uint128(-net));
            if (!currency.isAddressZero()) {
                IERC20(Currency.unwrap(currency)).safeTransferFrom(payer, address(this), owed);
            }
            _pay(currency, owed);
        } else if (net > 0) {
            poolManager.take(currency, payer, uint256(uint128(net)));
        }
    }

    function _pay(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        if (currency.isAddressZero()) {
            poolManager.settle{value: amount}();
        } else {
            poolManager.sync(currency);
            IERC20(Currency.unwrap(currency)).safeTransfer(address(poolManager), amount);
            poolManager.settle();
        }
    }

    function _refundNative(address payer) internal {
        uint256 leftover = address(this).balance;
        if (leftover == 0) return;
        (bool ok,) = payer.call{value: leftover}("");
        require(ok, "native refund");
    }
}
