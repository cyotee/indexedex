// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AaveV3StataStandardExchangeOutTarget} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol";

// tag::AaveV3StataStandardExchangeOutFacet[]
/**
 * @title AaveV3StataStandardExchangeOutFacet - IFacet declaration for IStandardExchangeOut.
 * @notice Exposes the "exchange out" surface (withdraw/unzap routes) for the Aave v3 Stata wrapper vault.
 */
contract AaveV3StataStandardExchangeOutFacet is AaveV3StataStandardExchangeOutTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(AaveV3StataStandardExchangeOutFacet).name;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
        return interfaces;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeOut.exchangeOut.selector;
        return funcs;
    }

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
}
// end::AaveV3StataStandardExchangeOutFacet[]
