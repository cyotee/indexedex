// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    SlipstreamStandardExchangeOutTarget
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol";

/**
 * @title SlipstreamStandardExchangeOutFacet - Facet for Slipstream exchange out operations.
 * @author cyotee doge <doge.cyotee>
 * @notice Diamond facet implementing IStandardExchangeOut for Slipstream vaults.
 */
contract SlipstreamStandardExchangeOutFacet is SlipstreamStandardExchangeOutTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(SlipstreamStandardExchangeOutFacet).name;
    }

    function facetInterfaces()
        public
        pure
        override
        returns (
            // override
            bytes4[] memory interfaces
        )
    {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
    }

    function facetFuncs()
        public
        pure
        override
        returns (
            // override
            bytes4[] memory funcs
        )
    {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeOut.exchangeOut.selector;
    }

    function facetMetadata()
        external
        pure
        override
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
