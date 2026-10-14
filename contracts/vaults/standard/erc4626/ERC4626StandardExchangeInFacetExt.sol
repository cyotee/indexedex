// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    ERC4626StandardExchangeInTargetExt
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTargetExt.sol";

/// @dev Preview facet. CREATE3 salt is the contract name.
contract ERC4626StandardExchangeInFacetExt is ERC4626StandardExchangeInTargetExt, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(ERC4626StandardExchangeInFacetExt).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](8);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[5] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
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
