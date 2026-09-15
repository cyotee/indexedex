// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {
    UniswapV4StandardExchangeOutMultiQueryTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTargetV2.sol";

contract UniswapV4StandardExchangeOutMultiQueryFacetV2 is UniswapV4StandardExchangeOutMultiQueryTargetV2, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(UniswapV4StandardExchangeOutMultiQueryFacetV2).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeOutMulti).interfaceId;
        interfaces[1] = type(IStandardizedYield).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;
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
