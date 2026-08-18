// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookPairPoolLib
 * @notice Product PoolKey construction and skip-if-live initialize for the wrap-aware door.
 * @dev Product key: address-sorted wrap-aware pair, fee = 0, family tick, hooks = proxy.
 */
library UniswapV4SingleStandardExchangeBufferHookPairPoolLib {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    int24 internal constant PRODUCT_TICK_SPACING = 60;

    /// @notice Pure pool key for the wrap-aware product pair (currency-sorted, fee 0).
    function pairKey(address a, address b, int24 spacing, IHooks hooks)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 0,
            tickSpacing: spacing,
            hooks: hooks
        });
    }

    /// @notice Initialize only when uninited; reverts on any failure that is not "already live".
    function initIfNeeded(IPoolManager poolManager, PoolKey memory key, uint160 sqrtPriceX96)
        internal
    {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        if (liveSqrt != 0) return;
        poolManager.initialize(key, sqrtPriceX96);
    }

    /// @notice True iff PoolManager reports a non-zero sqrt price for the door.
    function isPoolLive(IPoolManager poolManager, PoolKey memory key) internal view returns (bool) {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        return liveSqrt != 0;
    }
}
