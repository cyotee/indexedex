// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4StandardExchangeOutQueryTarget
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol";

/// @notice Preview-only exchangeOut surface (Option 1b view/execute split).
contract UniswapV4StandardExchangeOutQueryFacet is UniswapV4StandardExchangeOutQueryTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4StandardExchangeOutQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](0);
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeOut.previewExchangeOut.selector;
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
