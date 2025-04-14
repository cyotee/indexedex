// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {FeeCollectorManagerTarget} from "contracts/fee/collector/FeeCollectorManagerTarget.sol";

// tag::FeeCollectorManagerFacet[]
/**
 * @title FeeCollectorManagerFacet - IFacet declaration for IFeeCollectorManager
 * @author cyotee doge <not_cyotee@proton.me>
 */
contract FeeCollectorManagerFacet is FeeCollectorManagerTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */
    // tag::facetName()[]
    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(FeeCollectorManagerFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IFeeCollectorManager).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IFeeCollectorManager.syncReserve.selector;
        funcs[1] = IFeeCollectorManager.syncReserves.selector;
        funcs[2] = IFeeCollectorManager.pullFee.selector;
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
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
    // end::facetMetadata()[]
}
// end::FeeCollectorManagerFacet[]
