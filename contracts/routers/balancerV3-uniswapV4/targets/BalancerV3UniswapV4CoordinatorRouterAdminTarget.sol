// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterCommon
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterRepo
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterRepo.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterAdminTarget
abstract contract BalancerV3UniswapV4CoordinatorRouterAdminTarget is BalancerV3UniswapV4CoordinatorRouterCommon {
    using SafeERC20 for IERC20;
    using BalancerV3UniswapV4CoordinatorRouterRepo for *;

    function registerRouter(address router, IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind) external onlyOwner {
        BalancerV3UniswapV4CoordinatorRouterRepo._registerRouter(router, kind);
        emit IBalancerV3UniswapV4CoordinatorRouter.RouterRegistered(router, kind);
    }

    function unregisterRouter(address router) external onlyOwner {
        BalancerV3UniswapV4CoordinatorRouterRepo._unregisterRouter(router);
        emit IBalancerV3UniswapV4CoordinatorRouter.RouterUnregistered(router);
    }

    function isRouterAllowed(address router) external view returns (bool) {
        return BalancerV3UniswapV4CoordinatorRouterRepo._isRouterAllowed(router);
    }

    function routerKind(address router) external view returns (IBalancerV3UniswapV4CoordinatorRouter.AdapterKind) {
        return BalancerV3UniswapV4CoordinatorRouterRepo._routerKind(router);
    }

    function allowedRouterCount() external view returns (uint256) {
        return BalancerV3UniswapV4CoordinatorRouterRepo._allowedRouterCount();
    }

    function allowedRouterAt(uint256 index) external view returns (address) {
        return BalancerV3UniswapV4CoordinatorRouterRepo._allowedRouterAt(index);
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0) || token == address(0)) {
            revert IBalancerV3UniswapV4CoordinatorRouter.ZeroAddress();
        }
        IERC20(token).safeTransfer(to, amount);
        emit IBalancerV3UniswapV4CoordinatorRouter.TokensRescued(token, to, amount);
    }

    function rescueETH(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert IBalancerV3UniswapV4CoordinatorRouter.ZeroAddress();
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH_RESCUE");
        emit IBalancerV3UniswapV4CoordinatorRouter.ETHRescued(to, amount);
    }
}
