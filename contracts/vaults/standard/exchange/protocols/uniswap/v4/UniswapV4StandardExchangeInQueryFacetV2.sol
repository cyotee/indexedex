// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeInQueryTargetV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4StandardExchangeInQueryTargetV2.sol";

contract UniswapV4StandardExchangeInQueryFacetV2 is UniswapV4StandardExchangeInQueryTargetV2, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV4StandardExchangeInQueryFacetV2).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[1] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](6);
        funcs[0] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[3] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[5] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
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
