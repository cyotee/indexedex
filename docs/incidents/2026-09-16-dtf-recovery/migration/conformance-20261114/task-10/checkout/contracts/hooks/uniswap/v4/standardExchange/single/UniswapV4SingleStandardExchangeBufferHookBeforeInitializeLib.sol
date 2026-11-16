// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferHookCommon as Common
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookCommon.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and PRODUCT_FACET (F5).
 * @dev Bit-identical to today's Target: view-only PoolManager / wrap-aware pair / fee == 0.
 *      No poolInitialized write. Does not inherit Target.
 */
library UniswapV4SingleStandardExchangeBufferHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        Repo.Layout storage l = Repo._layout();
        if (msg.sender != l.poolManager) revert Common.NotPoolManager();

        Currency pairC = Currency.wrap(l.pairToken);
        Currency seC = Currency.wrap(l.standardExchange);
        bool wrapZFO = l.wrapZeroForOne;
        bool isValidPair = wrapZFO
            ? (poolKey.currency0 == pairC && poolKey.currency1 == seC)
            : (poolKey.currency0 == seC && poolKey.currency1 == pairC);
        if (!isValidPair) revert Common.InvalidPoolToken();
        if (poolKey.fee != 0) revert Common.InvalidPoolFee();
        return IHooks.beforeInitialize.selector;
    }
}
