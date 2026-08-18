// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookInit
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookInit.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookBeforeInitializeLib.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookInitTarget
 * @notice Package-as-init doors, door views, and bootstrap beforeInitialize (S58).
 * @dev Does not inherit UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.
 *      finalizeInitialization body lives on DFPkg.
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookInitTarget is
    IUniswapV4StandardExchangeCurveQuadStableBufferHookInit
{
    using PoolIdLibrary for PoolKey;

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.Reentrancy();
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
        key = PairPoolLib.pairKey(c0, c1, PairPoolLib.TICK_SPACING, IHooks(address(this)));
        IPoolManager pm = IPoolManager(Repo._layout().poolManager);
        uint160 price = TickMath.getSqrtPriceAtTick(0);
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
        return PairPoolLib.pairKey(c0, c1, PairPoolLib.TICK_SPACING, IHooks(address(this)));
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
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPair();
        }
        (c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (!_isBound(c0) || !_isBound(c1)) {
            revert UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.InvalidPair();
        }
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.tokens[0] || token == l.tokens[1] || token == l.tokens[2]
            || token == l.tokens[3];
    }
}
