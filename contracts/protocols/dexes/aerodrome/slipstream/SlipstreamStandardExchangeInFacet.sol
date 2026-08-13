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
import {
    ICLMintCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLMintCallback.sol";
import {
    ICLSwapCallback
} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/callback/ICLSwapCallback.sol";
import {
    SlipstreamStandardExchangeInTarget
} from "contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol";

/**
 * @title SlipstreamStandardExchangeInFacet - Facet for Slipstream exchange in operations.
 * @author cyotee doge <doge.cyotee>
 * @notice Diamond facet implementing IStandardExchangeIn for Slipstream vaults.
 */
contract SlipstreamStandardExchangeInFacet is SlipstreamStandardExchangeInTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(SlipstreamStandardExchangeInFacet).name;
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
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(ICLMintCallback).interfaceId;
        interfaces[2] = type(ICLSwapCallback).interfaceId;
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
        funcs = new bytes4[](4);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = ICLMintCallback.uniswapV3MintCallback.selector;
        funcs[3] = ICLSwapCallback.uniswapV3SwapCallback.selector;
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
