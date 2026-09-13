// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ConstantProductStandardYieldTarget} from "contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    CamelotV2StandardExchangeInTarget
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInTarget.sol";

contract CamelotV2StandardExchangeInFacet is CamelotV2StandardExchangeInTarget, ConstantProductStandardYieldTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(CamelotV2StandardExchangeInFacet).name;
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
        interfaces = new bytes4[](2);
        interfaces[1] = type(IStandardizedYield).interfaceId;

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
        funcs = new bytes4[](2);

        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs = NativeStandardYieldSelectors._append(funcs);
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
