// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

import {RebasingAwareStandardExchangeQuoteTarget} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeQuoteTarget.sol";

contract RebasingAwareStandardExchangeQuoteFacet is RebasingAwareStandardExchangeQuoteTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(RebasingAwareStandardExchangeQuoteFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[1] = type(IStandardExchangeExternalQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeRateQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[5] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        funcs[6] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[7] = IStandardExchangeRateQuote.quoteRate.selector;
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
