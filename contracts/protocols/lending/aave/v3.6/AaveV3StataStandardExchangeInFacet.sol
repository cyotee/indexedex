// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {AaveV3StataStandardExchangeInTarget} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol";

// tag::AaveV3StataStandardExchangeInFacet[]
/**
 * @title AaveV3StataStandardExchangeInFacet - IFacet declaration for IStandardExchangeIn.
 * @notice Exposes the "exchange in" surface (deposit/zap routes) for the Aave v3 Stata wrapper vault.
 */
contract AaveV3StataStandardExchangeInFacet is AaveV3StataStandardExchangeInTarget, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc IFacet
     */
    function facetName() public pure returns (string memory name) {
        return type(AaveV3StataStandardExchangeInFacet).name;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](3);
        interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;
        return interfaces;
    }

    /**
     * @inheritdoc IFacet
     */
    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](9);
        funcs[0] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[8] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        return funcs;
    }

    /**
     * @inheritdoc IFacet
     */
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
// end::AaveV3StataStandardExchangeInFacet[]
