// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Bit-identical to today's HooksTarget body (sorted currencies, bound tokens,
 *      DYNAMIC_FEE_FLAG, TICK_SPACING=1, hooks == this).
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPoolKey();
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPoolKey();
        }
        if (poolKey.tickSpacing != Repo.TICK_SPACING) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPoolKey();
        }
        if (address(poolKey.hooks) != address(this)) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPoolKey();
        }
        return IHooks.beforeInitialize.selector;
    }

    function _tokenIndex(address token) private view {
        Repo._indexOf(Repo._layout(), token);
    }
}
