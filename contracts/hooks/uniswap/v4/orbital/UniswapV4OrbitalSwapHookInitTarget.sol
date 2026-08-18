// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    IUniswapV4OrbitalSwapHookInit
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookInit.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookPairPoolLib.sol";
import {
    UniswapV4OrbitalSwapHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookBeforeInitializeLib.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";

/**
 * @title UniswapV4OrbitalSwapHookInitTarget
 * @notice Package-as-init doors, door views, and bootstrap beforeInitialize (S58).
 * @dev Does not inherit UniswapV4OrbitalSwapHookTarget. finalizeInitialization body lives on DFPkg (I7).
 */
abstract contract UniswapV4OrbitalSwapHookInitTarget is IUniswapV4OrbitalSwapHookInit {
    using PoolIdLibrary for PoolKey;

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) {
            revert UniswapV4OrbitalSwapHookTarget.Reentrancy();
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
            revert UniswapV4OrbitalSwapHookTarget.InvalidPoolToken();
        }
        (c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (!_isBound(c0) || !_isBound(c1)) {
            revert UniswapV4OrbitalSwapHookTarget.InvalidPoolToken();
        }
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.token0 || token == l.token1 || token == l.token2;
    }

    function _productSpacing(Repo.Layout storage l) private view returns (int24) {
        return l.tickSpacing == 0 ? int24(60) : l.tickSpacing;
    }

    function _productPrice(Repo.Layout storage l) private view returns (uint160) {
        return l.sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : l.sqrtPriceX96;
    }
}
