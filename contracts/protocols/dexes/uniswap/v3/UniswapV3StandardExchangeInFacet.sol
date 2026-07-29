// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IUniswapV3MintCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {
    IUniswapV3SwapCallback
} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {
    UniswapV3StandardExchangeInTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInTarget.sol";

/**
 * @title UniswapV3StandardExchangeInFacet
 * @notice Facet for exchange-in routes and Uni V3 mint/swap callbacks.
 */
contract UniswapV3StandardExchangeInFacet is UniswapV3StandardExchangeInTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeInFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IUniswapV3MintCallback).interfaceId;
        interfaces[2] = type(IUniswapV3SwapCallback).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        // previewExchangeIn lives on InQueryFacet (EIP-170 size split).
        funcs = new bytes4[](3);
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
