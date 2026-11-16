// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {
    UniswapV4BalancerQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookMath.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookPairPoolLib
 * @notice Product PoolKey construction and skip-if-live initialize for Balancer quad pair doors.
 * @dev Idempotent via getSlot0: skip if already live; otherwise initialize.
 *      PoolKey: fee = lpFeePips, tickSpacing = Math.TICK_SPACING, hooks = proxy.
 *      No bulk ensure (F5). Callers open each unordered pair via deployPair.
 */
library UniswapV4BalancerQuadStableSwapHookPairPoolLib {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function computeKeys(
        address hook,
        address t0,
        address t1,
        address t2,
        address t3,
        uint24 fee
    ) internal pure returns (PoolKey[6] memory keys) {
        // pairs: (0,1)(0,2)(0,3)(1,2)(1,3)(2,3) — binding order is address-sorted
        keys[0] = pairKey(hook, t0, t1, fee);
        keys[1] = pairKey(hook, t0, t2, fee);
        keys[2] = pairKey(hook, t0, t3, fee);
        keys[3] = pairKey(hook, t1, t2, fee);
        keys[4] = pairKey(hook, t1, t3, fee);
        keys[5] = pairKey(hook, t2, t3, fee);
    }

    function pairKey(address hook, address a, address b, uint24 fee)
        internal
        pure
        returns (PoolKey memory)
    {
        // callers must pass ascending pair; binding order already sorted
        return PoolKey({
            currency0: Currency.wrap(a),
            currency1: Currency.wrap(b),
            fee: fee,
            tickSpacing: int24(int256(Math.TICK_SPACING)),
            hooks: IHooks(hook)
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

    function isPoolLive(IPoolManager poolManager, PoolKey memory key) internal view returns (bool) {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        return liveSqrt != 0;
    }
}
