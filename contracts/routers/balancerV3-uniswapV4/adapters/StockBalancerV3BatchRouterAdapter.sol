// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    SwapPathExactAmountIn
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/BatchRouterTypes.sol";
import {IBatchRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBatchRouter.sol";
import {
    IBatchRouterQueries
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBatchRouterQueries.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title StockBalancerV3BatchRouterAdapter
/// @dev Single-root only (paths.length == 1).
library StockBalancerV3BatchRouterAdapter {
    function execute(address router, uint256 amountIn, uint256 deadline, bytes memory data) public {
        (SwapPathExactAmountIn[] memory paths, bool wethIsEth, bytes memory userData) =
            abi.decode(data, (SwapPathExactAmountIn[], bool, bytes));
        if (paths.length != 1) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        }
        paths[0].exactAmountIn = amountIn;
        IBatchRouter(router).swapExactIn(paths, deadline, wethIsEth, userData);
    }

    function query(address router, uint256 amountIn, bytes memory data) public returns (uint256 amountOut) {
        (SwapPathExactAmountIn[] memory paths,, bytes memory userData) =
            abi.decode(data, (SwapPathExactAmountIn[], bool, bytes));
        if (paths.length != 1) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidStepData();
        }
        paths[0].exactAmountIn = amountIn;
        (uint256[] memory pathAmountsOut,,) =
            IBatchRouterQueries(router).querySwapExactIn(paths, address(this), userData);
        amountOut = pathAmountsOut[0];
    }
}
