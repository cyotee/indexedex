// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Bit-identical to today's HooksTarget body (sorted currencies, bound tokens,
 *      DYNAMIC_FEE_FLAG, TICK_SPACING, hooks == this).
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPoolKey();
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPoolKey();
        }
        if (poolKey.tickSpacing != Repo.TICK_SPACING) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPoolKey();
        }
        if (address(poolKey.hooks) != address(this)) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPoolKey();
        }
        return IHooks.beforeInitialize.selector;
    }

    function _tokenIndex(address token) private view {
        Repo._indexOf(Repo._layout(), token);
    }
}
