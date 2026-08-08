// SPDX-License-Identifier: BUSL-1.1
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
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib
 * @notice Ensure all 6 pair doors for fixed n=4 with DYNAMIC_FEE_FLAG, tickSpacing=1, hooks=this.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    int24 internal constant TICK_SPACING = 1;
    uint256 internal constant N_TOKENS = 4;
    uint256 internal constant PAIR_DOOR_COUNT = 6; // binom(4,2)

    /// @notice Initialize every unordered pair among fixed 4 tokens (address-sorted currencies).
    /// @return doorsEnsured Count of pools newly initialized (already-live doors skipped).
    function ensureAllPairPools(
        IPoolManager poolManager,
        address hook,
        address[4] memory tokens,
        uint160 sqrtPriceX96
    ) internal returns (uint256 doorsEnsured) {
        uint160 price = sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : sqrtPriceX96;
        IHooks h = IHooks(hook);
        for (uint256 i; i < N_TOKENS; ++i) {
            for (uint256 j = i + 1; j < N_TOKENS; ++j) {
                PoolKey memory key = pairKey(tokens[i], tokens[j], TICK_SPACING, h);
                if (initIfNeeded(poolManager, key, price)) {
                    unchecked {
                        ++doorsEnsured;
                    }
                }
            }
        }
    }

    /// @notice Dynamic-array convenience (binding tokens view).
    function ensureAllPairPools(
        IPoolManager poolManager,
        address hook,
        address[] memory tokens,
        uint160 sqrtPriceX96
    ) internal returns (uint256 doorsEnsured) {
        require(tokens.length == N_TOKENS, "n");
        address[4] memory fixed_;
        fixed_[0] = tokens[0];
        fixed_[1] = tokens[1];
        fixed_[2] = tokens[2];
        fixed_[3] = tokens[3];
        return ensureAllPairPools(poolManager, hook, fixed_, sqrtPriceX96);
    }

    function pairDoorCount() internal pure returns (uint256) {
        return PAIR_DOOR_COUNT;
    }

    function pairDoorCount(uint256 n) internal pure returns (uint256) {
        // binom(n,2) = n*(n-1)/2
        return (n * (n - 1)) / 2;
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

    /// @return newlyInitialized true if pool was just initialized
    function initIfNeeded(IPoolManager poolManager, PoolKey memory key, uint160 sqrtPriceX96)
        internal
        returns (bool newlyInitialized)
    {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        if (liveSqrt != 0) return false;
        poolManager.initialize(key, sqrtPriceX96);
        return true;
    }

    function isPoolLive(IPoolManager poolManager, PoolKey memory key) internal view returns (bool) {
        (uint160 liveSqrt,,,) = poolManager.getSlot0(key.toId());
        return liveSqrt != 0;
    }
}
