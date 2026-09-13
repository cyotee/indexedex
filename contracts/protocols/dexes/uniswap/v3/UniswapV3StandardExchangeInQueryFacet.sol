// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV3StandardExchangeInQueryTarget
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInQueryTarget.sol";

/**
 * @title UniswapV3StandardExchangeInQueryFacet
 * @notice Inventory-transition queries; split from standard previews to remain under EIP-170.
 */
contract UniswapV3StandardExchangeInQueryFacet is UniswapV3StandardExchangeInQueryTarget, IFacet {
    function facetName() public pure override returns (string memory name) {
        return type(UniswapV3StandardExchangeInQueryFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[1] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function facetFuncs() public pure override returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[4] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[6] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
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
