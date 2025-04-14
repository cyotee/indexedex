// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {
    BalancerV3StandardExchangeRouterExactOutSwapTarget
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterExactOutSwapTarget.sol";

contract BalancerV3StandardExchangeRouterExactOutSwapFacet is
    BalancerV3StandardExchangeRouterExactOutSwapTarget,
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
        return type(BalancerV3StandardExchangeRouterExactOutSwapFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeRouterExactOutSwap).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOut.selector;
        funcs[1] = IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOutWithPermit.selector;
        funcs[2] = IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOutHook.selector;
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
    // end::facetMetadata()[]
}
