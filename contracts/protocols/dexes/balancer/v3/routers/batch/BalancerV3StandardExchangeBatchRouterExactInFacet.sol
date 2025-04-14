// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    BalancerV3StandardExchangeBatchRouterExactInTarget
} from "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol";

contract BalancerV3StandardExchangeBatchRouterExactInFacet is
    BalancerV3StandardExchangeBatchRouterExactInTarget,
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
        return type(BalancerV3StandardExchangeBatchRouterExactInFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeBatchRouterExactIn).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IBalancerV3StandardExchangeBatchRouterExactIn.swapExactIn.selector;
        funcs[1] = IBalancerV3StandardExchangeBatchRouterExactIn.swapExactInWithPermit.selector;
        funcs[2] = IBalancerV3StandardExchangeBatchRouterExactIn.swapExactInHook.selector;
        funcs[3] = IBalancerV3StandardExchangeBatchRouterExactIn.querySwapExactIn.selector;
        funcs[4] = IBalancerV3StandardExchangeBatchRouterExactIn.querySwapExactInHook.selector;
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
