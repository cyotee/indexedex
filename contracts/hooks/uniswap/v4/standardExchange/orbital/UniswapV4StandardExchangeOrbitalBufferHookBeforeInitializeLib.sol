// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib
 * @notice Shared beforeInitialize checks for package-as-init and the hooks facet.
 * @dev Imports Common only for its three error types. Does not inherit Common.
 */
library UniswapV4StandardExchangeOrbitalBufferHookBeforeInitializeLib {
    function beforeInitialize(PoolKey calldata poolKey) internal view returns (bytes4) {
        if (msg.sender != Repo._layout().poolManager) {
            revert UniswapV4StandardExchangeOrbitalBufferHookCommon.NotPoolManager();
        }
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (!_isBound(a) || !_isBound(b) || a == b) {
            revert UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolToken();
        }
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) {
            revert UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolFee();
        }
        return IHooks.beforeInitialize.selector;
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.token0 || token == l.token1 || token == l.token2;
    }
}
