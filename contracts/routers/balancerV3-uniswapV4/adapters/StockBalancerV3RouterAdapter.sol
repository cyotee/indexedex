// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";

/// @title StockBalancerV3RouterAdapter
library StockBalancerV3RouterAdapter {
    function execute(address router, uint256 amountIn, uint256 deadline, bytes memory data)
        public
        returns (
            uint256 /*unused*/
        )
    {
        (address pool, address tokenIn, address tokenOut, uint256 minAmountOut, bool wethIsEth, bytes memory userData) =
            abi.decode(data, (address, address, address, uint256, bool, bytes));

        IRouter(router)
            .swapSingleTokenExactIn(
                pool, IERC20(tokenIn), IERC20(tokenOut), amountIn, minAmountOut, deadline, wethIsEth, userData
            );
        return 0;
    }

    function query(address router, uint256 amountIn, bytes memory data) public returns (uint256 amountOut) {
        (address pool, address tokenIn, address tokenOut,,, bytes memory userData) =
            abi.decode(data, (address, address, address, uint256, bool, bytes));
        // Balancer V3 queries are NOT true EVM staticcalls: Vault.quote mutates transient
        // storage. Static-mode is enforced by `tx.origin == address(0)` (EVMCallModeHelpers).
        // Call via eth_call / Foundry `vm.prank(address(0), address(0))` so NotStaticCall passes
        // without StateChangeDuringStaticCall.
        amountOut = IRouter(router)
            .querySwapSingleTokenExactIn(pool, IERC20(tokenIn), IERC20(tokenOut), amountIn, address(this), userData);
    }
}
