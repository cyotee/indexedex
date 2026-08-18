// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookInit
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookInit.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPairPoolLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookBeforeInitializeLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon as Common
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookInitTarget
 * @notice Package-as-init door, door views, and bootstrap beforeInitialize (S58).
 * @dev Does not inherit Dual Target. finalizeInitialization body lives on DFPkg (I7).
 */
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookInitTarget is
    IUniswapV4DualStandardExchangeBufferConstantProductHookInit
{
    using PoolIdLibrary for PoolKey;

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) {
            revert Common.Reentrancy();
        }
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
    }

    function deployPair(address tokenA, address tokenB) external returns (PoolKey memory key) {
        (address c0, address c1) = _requireProductPair(tokenA, tokenB);
        Repo.Layout storage l = Repo._layout();
        key = PairPoolLib.pairKey(c0, c1, PairPoolLib.PRODUCT_TICK_SPACING, IHooks(address(this)));
        IPoolManager pm = IPoolManager(l.poolManager);
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        bool wasLive = PairPoolLib.isPoolLive(pm, key);
        // V4 Hooks.noSelfCall skips beforeInitialize when this proxy calls initialize,
        // so the one-shot flag must be enforced and written here (D69 / F5).
        if (l.poolInitialized && !wasLive) revert Common.AlreadyInitialized();
        PairPoolLib.initIfNeeded(pm, key, price);
        l.poolInitialized = true;
        if (!wasLive) {
            emit PairPoolDeployed(address(this), c0, c1, PoolId.unwrap(key.toId()));
        }
    }

    function isPairPoolLive(address tokenA, address tokenB) public view returns (bool) {
        return PairPoolLib.isPoolLive(
            IPoolManager(Repo._layout().poolManager), pairPoolKey(tokenA, tokenB)
        );
    }

    function pairPoolKey(address tokenA, address tokenB) public view returns (PoolKey memory) {
        (address c0, address c1) = _requireProductPair(tokenA, tokenB);
        return PairPoolLib.pairKey(c0, c1, PairPoolLib.PRODUCT_TICK_SPACING, IHooks(address(this)));
    }

    function isInitializationFinalized() public view returns (bool) {
        return Repo._layout().initializationFinalized;
    }

    function _requireProductPair(address tokenA, address tokenB)
        private
        view
        returns (address c0, address c1)
    {
        if (tokenA == address(0) || tokenB == address(0) || tokenA == tokenB) {
            revert Common.InvalidPoolToken();
        }
        (c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        Repo.Layout storage l = Repo._layout();
        if (c0 != l.currency0 || c1 != l.currency1) {
            revert Common.InvalidPoolToken();
        }
    }
}
