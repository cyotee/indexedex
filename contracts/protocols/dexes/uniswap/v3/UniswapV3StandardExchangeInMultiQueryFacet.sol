// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    UniswapV3StandardExchangeInMultiQueryTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInMultiQueryTarget.sol";

contract UniswapV3StandardExchangeInMultiQueryFacet is UniswapV3StandardExchangeInMultiQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeInMultiQueryFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeInMulti).interfaceId;
        interfaces[1] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](2);
        funcs[0] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector;
        funcs[1] = IStandardExchangeIn.previewExchangeIn.selector;
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
