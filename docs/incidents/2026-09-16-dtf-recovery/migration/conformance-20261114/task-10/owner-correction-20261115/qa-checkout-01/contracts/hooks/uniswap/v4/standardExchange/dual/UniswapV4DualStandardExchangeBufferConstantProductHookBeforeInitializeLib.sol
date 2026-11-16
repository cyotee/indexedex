// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon as Common
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet (F5).
 * @dev Bit-identical to today's HooksTarget: poolInitialized / AlreadyInitialized / fee == 0.
 *      Imports Common only for those error types. Does not inherit Target.
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal returns (bytes4) {
        Repo.Layout storage l = Repo._layout();
        if (msg.sender != l.poolManager) revert Common.NotPoolManager();
        if (l.poolInitialized) revert Common.AlreadyInitialized();

        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (!(a == l.currency0 && b == l.currency1)) revert Common.InvalidPoolToken();
        if (poolKey.fee != 0) revert Common.InvalidPoolFee();

        l.poolInitialized = true;
        return IHooks.beforeInitialize.selector;
    }
}
