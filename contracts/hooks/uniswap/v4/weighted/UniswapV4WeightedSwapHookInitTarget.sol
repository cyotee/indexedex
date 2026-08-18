// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    IUniswapV4WeightedSwapHookInit
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookInit.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";
import {
    UniswapV4WeightedSwapHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookBeforeInitializeLib.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookCommon
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";

/**
 * @title UniswapV4WeightedSwapHookInitTarget
 * @notice Package-as-init doors, door views, and bootstrap beforeInitialize (S58).
 * @dev Does not inherit UniswapV4WeightedSwapHookTarget. finalizeInitialization body lives on DFPkg.
 */
abstract contract UniswapV4WeightedSwapHookInitTarget is IUniswapV4WeightedSwapHookInit {
    using PoolIdLibrary for PoolKey;

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) {
            revert UniswapV4WeightedSwapHookCommon.Reentrancy();
        }
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        returns (bytes4)
    {
        return BeforeInitializeLib.beforeInitialize(poolKey);
    }

    function deployPair(address tokenA, address tokenB) external returns (PoolKey memory key) {
        (address c0, address c1) = _requireProductPair(tokenA, tokenB);
        Repo.Layout storage l = Repo._layout();
        key = PairPoolLib.pairKey(c0, c1, _productSpacing(l), IHooks(address(this)));
        IPoolManager pm = IPoolManager(l.poolManager);
        uint160 price = _productPrice(l);
        bool wasLive = PairPoolLib.isPoolLive(pm, key);
        PairPoolLib.initIfNeeded(pm, key, price);
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
        Repo.Layout storage l = Repo._layout();
        return PairPoolLib.pairKey(c0, c1, _productSpacing(l), IHooks(address(this)));
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
            revert UniswapV4WeightedSwapHookCommon.InvalidPair();
        }
        (c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (!_isBound(c0) || !_isBound(c1)) {
            revert UniswapV4WeightedSwapHookCommon.InvalidPair();
        }
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.tokens[i] == token) return true;
        }
        return false;
    }

    function _productSpacing(Repo.Layout storage l) private view returns (int24) {
        return l.tickSpacing == 0 ? int24(int256(Math.TICK_SPACING)) : l.tickSpacing;
    }

    function _productPrice(Repo.Layout storage l) private view returns (uint160) {
        return l.sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : l.sqrtPriceX96;
    }
}
