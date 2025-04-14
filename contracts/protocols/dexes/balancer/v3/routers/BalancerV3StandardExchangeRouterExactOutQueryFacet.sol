// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {
    BalancerV3StandardExchangeRouterExactOutQueryTarget
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutQueryTarget.sol";

contract BalancerV3StandardExchangeRouterExactOutQueryFacet is
    BalancerV3StandardExchangeRouterExactOutQueryTarget,
    IFacet
{
    /* -------------------------------------------------------------------------- */
    /*                                   IFacet                                   */
    /* -------------------------------------------------------------------------- */

    // tag::facetName()[]
    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3StandardExchangeRouterExactOutQueryFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeRouterExactOutSwapQuery).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IBalancerV3StandardExchangeRouterExactOutSwapQuery.querySwapSingleTokenExactOut.selector;
        funcs[1] = IBalancerV3StandardExchangeRouterExactOutSwapQuery.querySwapSingleTokenExactOutHook.selector;
        return funcs;
    }

    // end::facetFuncs()[]

    // tag::facetMetadata()[]
    /**
     * @inheritdoc IFacet
     */
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
