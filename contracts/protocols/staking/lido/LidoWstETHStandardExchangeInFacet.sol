// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";


import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {LidoWstETHStandardExchangeInTarget} from "contracts/protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol";

contract LidoWstETHStandardExchangeInFacet is LidoWstETHStandardExchangeInTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(LidoWstETHStandardExchangeInFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](10);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = this.exchangeInEth.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[7] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[8] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        funcs[9] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
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
