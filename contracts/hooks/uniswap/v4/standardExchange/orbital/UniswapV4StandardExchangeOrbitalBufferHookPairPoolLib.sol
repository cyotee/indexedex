// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib
 * @notice Ensure three pair doors (01, 12, 02) with DYNAMIC_FEE_FLAG (D60).
 */
library UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function ensureThreePairPools(
        IPoolManager poolManager,
        address hook,
        address token0,
        address token1,
        address token2,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    )
        internal
        returns (PoolKey memory poolKey01, PoolKey memory poolKey12, PoolKey memory poolKey02)
    {
        int24 spacing = tickSpacing == 0 ? int24(60) : tickSpacing;
        uint160 price = sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : sqrtPriceX96;
        IHooks h = IHooks(hook);

        poolKey01 = pairKey(token0, token1, spacing, h);
        poolKey12 = pairKey(token1, token2, spacing, h);
        poolKey02 = pairKey(token0, token2, spacing, h);

        initIfNeeded(poolManager, poolKey01, price);
        initIfNeeded(poolManager, poolKey12, price);
        initIfNeeded(poolManager, poolKey02, price);
    }

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

    function initIfNeeded(IPoolManager poolManager, PoolKey memory key, uint160 sqrtPriceX96)
        internal
    {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        if (liveSqrt != 0) return;
        poolManager.initialize(key, sqrtPriceX96);
    }

    function isPoolLive(IPoolManager poolManager, PoolKey memory key) internal view returns (bool) {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        return liveSqrt != 0;
    }
}
