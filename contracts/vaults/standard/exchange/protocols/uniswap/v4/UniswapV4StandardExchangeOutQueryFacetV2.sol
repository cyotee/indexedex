// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOutQueryTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutQueryTargetV2.sol";

/// @notice Preview-only exchangeOut surface (Option 1b view/execute split).
contract UniswapV4StandardExchangeOutQueryFacetV2 is UniswapV4StandardExchangeOutQueryTargetV2, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4StandardExchangeOutQueryFacetV2).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;
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
