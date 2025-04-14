// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    BalancerV3StandardExchangeRouterPrepayTarget
} from "contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol";

contract BalancerV3StandardExchangeRouterPrepayFacet is BalancerV3StandardExchangeRouterPrepayTarget, IFacet {
    /* -------------------------------------------------------------------------- */
    /*                                   IFacet                                   */
    /* -------------------------------------------------------------------------- */

    // tag::facetName()[]
    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3StandardExchangeRouterPrepayFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeRouterPrepay).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IBalancerV3StandardExchangeRouterPrepay.isPrepaid.selector;
        funcs[1] = IBalancerV3StandardExchangeRouterPrepay.currentStandardExchange.selector;
        funcs[2] = IBalancerV3StandardExchangeRouterPrepay.prepayInitialize.selector;
        funcs[3] = IBalancerV3StandardExchangeRouterPrepay.prepayAddLiquidityUnbalanced.selector;
        funcs[4] = IBalancerV3StandardExchangeRouterPrepay.prepayRemoveLiquidityProportional.selector;
        funcs[5] = IBalancerV3StandardExchangeRouterPrepay.prepayRemoveLiquiditySingleTokenExactIn.selector;
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
