// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AaveV3StataStandardExchangeInTarget} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol";

// tag::AaveV3StataStandardExchangeInFacet[]
/**
 * @title AaveV3StataStandardExchangeInFacet - IFacet declaration for IStandardExchangeIn.
 * @notice Exposes the "exchange in" surface (deposit/zap routes) for the Aave v3 Stata wrapper vault.
 */
contract AaveV3StataStandardExchangeInFacet is AaveV3StataStandardExchangeInTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(AaveV3StataStandardExchangeInFacet).name;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        return interfaces;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
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
// end::AaveV3StataStandardExchangeInFacet[]
