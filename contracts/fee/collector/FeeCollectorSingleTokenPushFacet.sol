// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";
import {FeeCollectorSingleTokenPushTarget} from "contracts/fee/collector/FeeCollectorSingleTokenPushTarget.sol";

// tag::FeeCollectorSingleTokenPushFacet[]
/**
 * @title FeeCollectorSingleTokenPushFacet - IFacet declaration for IFeeCollectorSingleTokenPush
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Optional hook for vaults to push fees of a single token to the vault configured with this facet.
 */
contract FeeCollectorSingleTokenPushFacet is FeeCollectorSingleTokenPushTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */
    // tag::facetName()[]
    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(FeeCollectorSingleTokenPushFacet).name;
    }

    // end::facetName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IFeeCollectorSingleTokenPush).interfaceId;
        return interfaces;
    }

    // end::facetInterfaces()[]

    // tag::facetFuncs()[]
    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IFeeCollectorSingleTokenPush.pushSingleTokenFee.selector;
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
// end::FeeCollectorSingleTokenPushFacet[]
