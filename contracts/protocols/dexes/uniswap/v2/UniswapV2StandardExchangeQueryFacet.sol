// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV2StandardExchangeQuoteTarget} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol";

/// @notice Projected SE and pool accounting, isolated from execution to meet EIP-170.
contract UniswapV2StandardExchangeQueryFacet is UniswapV2StandardExchangeQuoteTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV2StandardExchangeQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[1] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[5] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[6] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
    }

    function facetMetadata() external pure returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
