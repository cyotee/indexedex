// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterAdminTarget
} from "contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterAdminTarget.sol";

contract BalancerV3UniswapV4CoordinatorRouterAdminFacet is BalancerV3UniswapV4CoordinatorRouterAdminTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3UniswapV4CoordinatorRouterAdminFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3UniswapV4CoordinatorRouter).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IBalancerV3UniswapV4CoordinatorRouter.registerRouter.selector;
        funcs[1] = IBalancerV3UniswapV4CoordinatorRouter.unregisterRouter.selector;
        funcs[2] = IBalancerV3UniswapV4CoordinatorRouter.isRouterAllowed.selector;
        funcs[3] = IBalancerV3UniswapV4CoordinatorRouter.routerKind.selector;
        funcs[4] = IBalancerV3UniswapV4CoordinatorRouter.allowedRouterCount.selector;
        funcs[5] = IBalancerV3UniswapV4CoordinatorRouter.allowedRouterAt.selector;
        funcs[6] = IBalancerV3UniswapV4CoordinatorRouter.rescueTokens.selector;
        funcs[7] = IBalancerV3UniswapV4CoordinatorRouter.rescueETH.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
