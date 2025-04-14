// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {
    AerodromeStandardExchangeInTarget
} from "contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeInTarget.sol";

contract AerodromeStandardExchangeInFacet is AerodromeStandardExchangeInTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(AerodromeStandardExchangeInFacet).name;
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

        interfaces[0] = type(IStandardExchangeIn).interfaceId;
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
        funcs = new bytes4[](3);

        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = bytes4(keccak256("heldExcessTokens()"));
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
