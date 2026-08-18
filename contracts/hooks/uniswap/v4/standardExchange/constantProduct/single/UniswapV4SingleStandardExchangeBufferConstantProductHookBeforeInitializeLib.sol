// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and SE_FACET (F5).
 * @dev Bit-identical to today's SeTarget/Target: PoolManager, exact currencies,
 *      fee == 0, poolInitialized / AlreadyInitialized. Error selectors match SeTarget.
 *      Does not inherit Target (avoids a SeTarget ↔ lib import cycle).
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookBeforeInitializeLib {
    error NotPoolManager();
    error AlreadyInitialized();
    error InvalidPoolToken();
    error InvalidPoolFee();

    function beforeInitialize(PoolKey calldata poolKey) internal returns (bytes4) {
        Repo.Layout storage l = Repo._layout();
        if (msg.sender != l.poolManager) revert NotPoolManager();
        if (l.poolInitialized) revert AlreadyInitialized();

        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (!(a == l.currency0 && b == l.currency1)) revert InvalidPoolToken();
        if (poolKey.fee != 0) revert InvalidPoolFee();

        l.poolInitialized = true;
        return IHooks.beforeInitialize.selector;
    }
}
