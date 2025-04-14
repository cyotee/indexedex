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
    CamelotV2StandardExchangeOutTarget
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol";

contract CamelotV2StandardExchangeOutFacet is CamelotV2StandardExchangeOutTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(CamelotV2StandardExchangeOutFacet).name;
    }

    function facetInterfaces()
        public
        pure
        virtual
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
        virtual
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
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}
