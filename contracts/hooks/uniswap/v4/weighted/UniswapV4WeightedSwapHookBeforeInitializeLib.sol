// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookCommon
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";

/**
 * @title UniswapV4WeightedSwapHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Bit-identical to today's HooksTarget body (sorted currencies, bound tokens,
 *      DYNAMIC_FEE, Math.TICK_SPACING, hooks == this). Imports Common only for errors.
 */
library UniswapV4WeightedSwapHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4WeightedSwapHookCommon.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (a >= b) revert UniswapV4WeightedSwapHookCommon.InvalidPoolKey();
        _tokenIndex(a);
        _tokenIndex(b);
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert UniswapV4WeightedSwapHookCommon.InvalidPoolKey();
        }
        if (poolKey.tickSpacing != int24(int256(Math.TICK_SPACING))) {
            revert UniswapV4WeightedSwapHookCommon.InvalidPoolKey();
        }
        if (address(poolKey.hooks) != address(this)) {
            revert UniswapV4WeightedSwapHookCommon.InvalidPoolKey();
        }
        return IHooks.beforeInitialize.selector;
    }

    function _tokenIndex(address token_) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.tokens[i] == token_) return i;
        }
        revert UniswapV4WeightedSwapHookCommon.InvalidPair();
    }
}
