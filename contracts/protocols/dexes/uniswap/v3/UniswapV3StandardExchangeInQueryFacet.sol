// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInQueryTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryTarget.sol";

/**
 * @title UniswapV3StandardExchangeInQueryFacet
 * @notice Preview-only facet to keep mutate InFacet under EIP-170.
 */
contract UniswapV3StandardExchangeInQueryFacet is UniswapV3StandardExchangeInQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeInQueryFacet).name;
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
