// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    BalancerV3StandardExchangeBatchRouterExactOutTarget
} from "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactOutTarget.sol";

contract BalancerV3StandardExchangeBatchRouterExactOutFacet is
    BalancerV3StandardExchangeBatchRouterExactOutTarget,
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
        return type(BalancerV3StandardExchangeBatchRouterExactOutFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeBatchRouterExactOut).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOut.selector;
        funcs[1] = IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOutWithPermit.selector;
        funcs[2] = IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOutHook.selector;
        funcs[3] = IBalancerV3StandardExchangeBatchRouterExactOut.querySwapExactOut.selector;
        funcs[4] = IBalancerV3StandardExchangeBatchRouterExactOut.querySwapExactOutHook.selector;
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
