// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Bit-identical to today's HooksTarget body (sorted currencies, bound tokens,
 *      DYNAMIC_FEE, Repo.TICK_SPACING, hooks == this). Imports Target only for errors.
 */
library UniswapV4StandardExchangeWeightedBufferHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4StandardExchangeWeightedBufferHookTarget.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPoolKey();
        Repo._indexOf(Repo._layout(), a);
        Repo._indexOf(Repo._layout(), b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPoolKey();
        }
        if (poolKey.tickSpacing != Repo.TICK_SPACING) {
            revert UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPoolKey();
        }
        if (address(poolKey.hooks) != address(this)) {
            revert UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPoolKey();
        }
        return IHooks.beforeInitialize.selector;
    }
}
