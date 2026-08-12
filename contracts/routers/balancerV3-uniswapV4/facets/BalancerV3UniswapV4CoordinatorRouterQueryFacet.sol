// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterQueryTarget
} from "contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol";

contract BalancerV3UniswapV4CoordinatorRouterQueryFacet is BalancerV3UniswapV4CoordinatorRouterQueryTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3UniswapV4CoordinatorRouterQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3UniswapV4CoordinatorRouter).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IBalancerV3UniswapV4CoordinatorRouter.queryExactIn.selector;
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
