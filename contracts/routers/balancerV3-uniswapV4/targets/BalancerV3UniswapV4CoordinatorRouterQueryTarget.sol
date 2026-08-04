// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterCommon
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterRepo
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterRepo.sol";
import {
    StockBalancerV3RouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol";
import {
    StockBalancerV3BatchRouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3BatchRouterAdapter.sol";
import {IndexedExSERouterAdapter} from "contracts/routers/balancerV3-uniswapV4/adapters/IndexedExSERouterAdapter.sol";
import {
    UniswapV4UniversalRouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/UniswapV4UniversalRouterAdapter.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterQueryTarget
abstract contract BalancerV3UniswapV4CoordinatorRouterQueryTarget is BalancerV3UniswapV4CoordinatorRouterCommon {
    using BalancerV3UniswapV4CoordinatorRouterRepo for *;

    function queryExactIn(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        _validateParams(params);
        uint256 amountForStep = params.amountIn;
        uint256 len = params.steps.length;
        for (uint256 i; i < len; ++i) {
            IBalancerV3UniswapV4CoordinatorRouter.RouteStep calldata step = params.steps[i];
            IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind =
                BalancerV3UniswapV4CoordinatorRouterRepo._routerKind(step.router);
            amountForStep = _dispatchQuery(kind, step.router, amountForStep, step.data);
        }
        amountOut = amountForStep;
    }

    function _dispatchQuery(
        IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind,
        address router,
        uint256 amountIn,
        bytes memory data
    ) internal returns (uint256 amountOut) {
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router) {
            return StockBalancerV3RouterAdapter.query(router, amountIn, data);
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3BatchRouter) {
            return StockBalancerV3BatchRouterAdapter.query(router, amountIn, data);
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter) {
            return IndexedExSERouterAdapter.query(router, amountIn, data);
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter) {
            return
                UniswapV4UniversalRouterAdapter.query(
                    BalancerV3UniswapV4CoordinatorRouterRepo._v4Quoter(), amountIn, data
                );
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidRouterKind();
    }
}
