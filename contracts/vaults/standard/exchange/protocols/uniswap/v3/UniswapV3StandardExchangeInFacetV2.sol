// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangePretransfer} from "../IStandardExchangePretransfer.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3StandardExchangeInTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeInTargetV2.sol";

/**
 * @title UniswapV3StandardExchangeInFacetV2
 * @notice Facet for exchange-in routes and Uni V3 mint/swap callbacks. Constructor-injected CREATE3 delegate.
 */
contract UniswapV3StandardExchangeInFacetV2 is UniswapV3StandardExchangeInTargetV2, IFacet {
    constructor(address executionDelegate) UniswapV3StandardExchangeInTargetV2(executionDelegate) {}

    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeInFacetV2).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](4);
        interfaces[3] = type(IStandardExchangePretransfer).interfaceId;
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IUniswapV3MintCallback).interfaceId;
        interfaces[2] = type(IUniswapV3SwapCallback).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[3] = IStandardExchangePretransfer.preparePretransfer.selector;
        funcs[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs[1] = IUniswapV3MintCallback.uniswapV3MintCallback.selector;
        funcs[2] = IUniswapV3SwapCallback.uniswapV3SwapCallback.selector;
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
