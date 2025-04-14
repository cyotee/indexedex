// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IBalancerV3StandardExchangeRouterPermit2Witness} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPermit2Witness.sol";
import {
    BalancerV3StandardExchangeRouterPermit2WitnessTarget
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterPermit2WitnessTarget.sol";

contract BalancerV3StandardExchangeRouterPermit2WitnessFacet is BalancerV3StandardExchangeRouterPermit2WitnessTarget, IFacet {
    /* -------------------------------------------------------------------------- */
    /*                                   IFacet                                   */
    /* -------------------------------------------------------------------------- */

    // tag::facetName()[]
    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(BalancerV3StandardExchangeRouterPermit2WitnessFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure override(IFacet) returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBalancerV3StandardExchangeRouterPermit2Witness).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IBalancerV3StandardExchangeRouterPermit2Witness.WITNESS_TYPE_STRING.selector;
        funcs[1] = IBalancerV3StandardExchangeRouterPermit2Witness.WITNESS_TYPEHASH.selector;
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
