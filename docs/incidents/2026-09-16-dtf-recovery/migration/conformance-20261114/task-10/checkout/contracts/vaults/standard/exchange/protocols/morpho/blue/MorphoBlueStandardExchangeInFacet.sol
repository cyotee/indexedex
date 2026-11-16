// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {
    MorphoBlueStandardExchangeInTarget
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeInTarget.sol";

contract MorphoBlueStandardExchangeInFacet is MorphoBlueStandardExchangeInTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(MorphoBlueStandardExchangeInFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](7);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
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
