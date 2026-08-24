// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutQueryTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutQueryTarget.sol";

/// @notice Preview-only exchangeOut surface. Mutate lives on OutFacet.
contract UniswapV3StandardExchangeOutQueryFacet is UniswapV3StandardExchangeOutQueryTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV3StandardExchangeOutQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeOut).interfaceId;
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
