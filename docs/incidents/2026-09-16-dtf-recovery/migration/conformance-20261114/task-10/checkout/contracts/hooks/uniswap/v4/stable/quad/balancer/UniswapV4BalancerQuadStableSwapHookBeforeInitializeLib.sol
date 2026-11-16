// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4BalancerQuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookRepo.sol";
import {
    UniswapV4BalancerQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookMath.sol";
import {
    UniswapV4BalancerQuadStableSwapHookTarget
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookTarget.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Bit-identical to today's Target body (sorted currencies, bound tokens,
 *      fee == stored lpFeePips, Math.TICK_SPACING, hooks == this).
 */
library UniswapV4BalancerQuadStableSwapHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4BalancerQuadStableSwapHookTarget.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert UniswapV4BalancerQuadStableSwapHookTarget.InvalidPoolKey();
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != Repo._layout().lpFeePips) {
            revert UniswapV4BalancerQuadStableSwapHookTarget.InvalidPoolKey();
        }
        if (poolKey.tickSpacing != int24(int256(Math.TICK_SPACING))) {
            revert UniswapV4BalancerQuadStableSwapHookTarget.InvalidPoolKey();
        }
        if (address(poolKey.hooks) != address(this)) {
            revert UniswapV4BalancerQuadStableSwapHookTarget.InvalidPoolKey();
        }
        return IHooks.beforeInitialize.selector;
    }

    function _tokenIndex(address token) private view {
        Repo.Layout storage l = Repo._layout();
        if (token == l.token0) return;
        if (token == l.token1) return;
        if (token == l.token2) return;
        if (token == l.token3) return;
        revert UniswapV4BalancerQuadStableSwapHookTarget.InvalidRoute();
    }
}
