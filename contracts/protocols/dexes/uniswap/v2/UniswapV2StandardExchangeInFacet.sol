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
    UniswapV2StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol";

contract UniswapV2StandardExchangeInFacet is UniswapV2StandardExchangeInTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV2StandardExchangeInFacet).name;
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
        funcs = new bytes4[](2);

        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
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
