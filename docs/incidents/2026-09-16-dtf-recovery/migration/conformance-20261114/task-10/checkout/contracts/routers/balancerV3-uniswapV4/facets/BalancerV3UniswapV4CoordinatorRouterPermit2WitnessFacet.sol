// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget
} from "contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget.sol";

contract BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet is
    BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget,
    IFacet
{
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3UniswapV4CoordinatorRouter).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IBalancerV3UniswapV4CoordinatorRouter.WITNESS_TYPE_STRING.selector;
        funcs[1] = IBalancerV3UniswapV4CoordinatorRouter.WITNESS_TYPEHASH.selector;
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
