// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget.sol";

/**
 * @title AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet
 * @author cyotee doge <doge.cyotee>
 * @notice IFacet declaration for the cross-version loop's sequential transition-quote surface
 *         (IStandardExchangeTransitionQuote), so buffered-hook previews (e.g. the orbital LP) can
 *         project the loop SE wei-for-wei.
 */
contract AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet is
    AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget, IFacet
{
    function facetName() public pure returns (string memory) {
        return type(AaveCrossVersionLoopStandardExchangeTransitionQuoteFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
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
