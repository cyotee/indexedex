// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";

/**
 * @title UniswapV4WeightedSwapHookPairPoolLib
 * @notice Product PoolKey construction and skip-if-live initialize for weighted pair doors.
 * @dev Idempotent via getSlot0: skip if sqrtPriceX96 != 0; otherwise initialize.
 *      No bulk ensure (F5). Callers open each unordered pair via deployPair.
 */
library UniswapV4WeightedSwapHookPairPoolLib {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /// @notice Pure pool key for a binding pair (currency-sorted, DYNAMIC_FEE, shared hooks).
    function pairKey(address a, address b, int24 spacing, IHooks hooks)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: spacing,
            hooks: hooks
        });
    }

    /// @notice Compute keys without initializing (tests / views).
    function computePairKeys(address[] memory tokens, address hook, int24 tickSpacing)
        internal
        pure
        returns (PoolKey[] memory keys)
    {
        int24 spacing = tickSpacing == 0 ? int24(int256(Math.TICK_SPACING)) : tickSpacing;
        IHooks h = IHooks(hook);
        uint256 n = tokens.length;
        uint256 pairCount = (n * (n - 1)) / 2;
        keys = new PoolKey[](pairCount);
        uint256 k;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                keys[k] = pairKey(tokens[i], tokens[j], spacing, h);
                ++k;
            }
        }
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
