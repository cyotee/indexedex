// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath as V3TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath as V4TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/// @dev Separately funded market participant; never edits pool/vault state through cheatcodes.
contract StandardExchangeMarketTrader is IUniswapV3SwapCallback, IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    address private activePool;
    IWETH private nativeWeth;
    receive() external payable {}
    function setNativeWeth(IWETH weth_) external { nativeWeth = weth_; }
    function tradeV3(IUniswapV3Pool pool, bool zeroForOne, uint256 amount) external {
        activePool = address(pool);
        pool.swap(address(this), zeroForOne, int256(amount),
            zeroForOne ? V3TickMath.MIN_SQRT_RATIO + 1 : V3TickMath.MAX_SQRT_RATIO - 1, "");
        activePool = address(0);
    }
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata) external {
        require(msg.sender == activePool, "pool");
        IUniswapV3Pool pool = IUniswapV3Pool(msg.sender);
        if (amount0 > 0) IERC20(pool.token0()).transfer(msg.sender, uint256(amount0));
        if (amount1 > 0) IERC20(pool.token1()).transfer(msg.sender, uint256(amount1));
    }
    function tradeV4(IPoolManager manager, PoolKey memory key, bool zeroForOne, uint256 amount) external {
        activePool = address(manager);
        manager.unlock(abi.encode(key, zeroForOne, amount));
        activePool = address(0);
    }
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == activePool, "manager");
        (PoolKey memory key, bool zeroForOne, uint256 amount) = abi.decode(data, (PoolKey, bool, uint256));
        IPoolManager manager = IPoolManager(msg.sender);
        BalanceDelta delta = manager.swap(key, SwapParams({zeroForOne: zeroForOne, amountSpecified: -int256(amount),
            sqrtPriceLimitX96: zeroForOne ? V4TickMath.MIN_SQRT_PRICE + 1 : V4TickMath.MAX_SQRT_PRICE - 1}), "");
        _settle(manager, key.currency0, delta.amount0());
        _settle(manager, key.currency1, delta.amount1());
        return "";
    }
    function _settle(IPoolManager manager, Currency currency, int128 delta) private {
        if (delta < 0) {
            if (Currency.unwrap(currency) == address(0)) {
                nativeWeth.withdraw(uint128(-delta));
                manager.settle{value: uint128(-delta)}();
            } else {
                manager.sync(currency);
                IERC20(Currency.unwrap(currency)).transfer(address(manager), uint128(-delta));
                manager.settle();
            }
        } else if (delta > 0) {
            manager.take(currency, address(this), uint128(delta));
            if (Currency.unwrap(currency) == address(0)) nativeWeth.deposit{value: uint128(delta)}();
        }
    }
}
