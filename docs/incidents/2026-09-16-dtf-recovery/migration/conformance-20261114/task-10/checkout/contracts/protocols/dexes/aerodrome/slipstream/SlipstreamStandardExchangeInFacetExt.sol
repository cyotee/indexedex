// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    SlipstreamStandardExchangeInTargetExt
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTargetExt.sol";

/// @dev D19 Ext facet: `previewExchangeIn` only. CREATE3 salt is the contract name.
contract SlipstreamStandardExchangeInFacetExt is SlipstreamStandardExchangeInTargetExt, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(SlipstreamStandardExchangeInFacetExt).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
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
