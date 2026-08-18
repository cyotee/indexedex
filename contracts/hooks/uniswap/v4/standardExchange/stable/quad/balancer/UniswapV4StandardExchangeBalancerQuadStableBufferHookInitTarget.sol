// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookInit
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookInit.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookBeforeInitializeLib.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookInitTarget
 * @notice Package-as-init doors, door views, and bootstrap beforeInitialize (S58).
 * @dev Does not inherit UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.
 *      finalizeInitialization body lives on DFPkg.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookInitTarget is
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookInit
{
    using PoolIdLibrary for PoolKey;

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.Reentrancy();
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
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPair();
        }
        (c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (!_isBound(c0) || !_isBound(c1)) {
            revert UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPair();
        }
    }

    function _isBound(address token) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.tokens[0] || token == l.tokens[1] || token == l.tokens[2]
            || token == l.tokens[3];
    }
}
