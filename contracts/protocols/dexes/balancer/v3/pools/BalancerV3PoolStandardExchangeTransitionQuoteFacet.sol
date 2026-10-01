// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {BalancerV3PoolStandardExchangeTransitionQuoteTarget} from
    "contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTransitionQuoteTarget.sol";

/**
 * @title BalancerV3PoolStandardExchangeTransitionQuoteFacet
 * @notice Lean facet exposing `IStandardExchangeTransitionQuote` for every Balancer V3
 *         buffer-pool Standard Exchange family. Shared verbatim across all six packages; the
 *         projection delegates the pool math to `IBasePool(address(this))`, so it needs no
 *         family-specific code.
 */
contract BalancerV3PoolStandardExchangeTransitionQuoteFacet is
    BalancerV3PoolStandardExchangeTransitionQuoteTarget,
    IFacet
{
    function facetName() public pure returns (string memory) {
        return type(BalancerV3PoolStandardExchangeTransitionQuoteFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](1);
        ifaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](5);
        funcs[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[1] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
    }

    function facetMetadata() external pure returns (string memory n, bytes4[] memory i, bytes4[] memory f) {
        n = facetName();
        i = facetInterfaces();
        f = facetFuncs();
    }
}
