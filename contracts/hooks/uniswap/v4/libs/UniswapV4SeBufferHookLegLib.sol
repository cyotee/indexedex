// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

/**
 * @title UniswapV4SeBufferHookLegLib
 * @notice Classify join/swap addresses as DETF self-leg, pair, or Standard Exchange share.
 * @dev PRD §15.12.1. Membership is AddressSetRepo._contains only. Do not scan tokens().
 */
library UniswapV4SeBufferHookLegLib {
    using AddressSetRepo for AddressSet;

    enum LegKind {
        Unknown,
        Detf,
        Pair,
        StandardExchange
    }

    struct Layout {
        address detfToken;
        AddressSet pairTokens;
        AddressSet standardExchanges;
        mapping(address pair => address se) standardExchangeOf;
        mapping(address se => address pair) pairOfStandardExchange;
    }

    error ZeroAddress();
    error PairSeOverlap(address pair, address se);
    error DetfTokenInSets(address detfToken);
    error SeAlreadyBound(address se, address existingPair);

    function classify(Layout storage layoutStruct, address addr) internal view returns (LegKind) {
        address detfToken_ = layoutStruct.detfToken;
        if (detfToken_ != address(0) && addr == detfToken_) {
            return LegKind.Detf;
        }
        if (layoutStruct.pairTokens._contains(addr)) {
            return LegKind.Pair;
        }
        if (layoutStruct.standardExchanges._contains(addr)) {
            return LegKind.StandardExchange;
        }
        return LegKind.Unknown;
    }

    function addPairSe(Layout storage layoutStruct, address pair, address se) internal {
        if (pair == address(0) || se == address(0)) {
            revert ZeroAddress();
        }
        if (pair == se) {
            revert PairSeOverlap(pair, se);
        }
        address detfToken_ = layoutStruct.detfToken;
        if (pair == detfToken_ || se == detfToken_) {
            revert DetfTokenInSets(detfToken_);
        }
        if (layoutStruct.standardExchanges._contains(pair) || layoutStruct.pairTokens._contains(se)) {
            revert PairSeOverlap(pair, se);
        }
        address existingPair_ = layoutStruct.pairOfStandardExchange[se];
        if (existingPair_ != address(0) && existingPair_ != pair) {
            revert SeAlreadyBound(se, existingPair_);
        }
        layoutStruct.pairTokens._add(pair);
        layoutStruct.standardExchanges._add(se);
        layoutStruct.standardExchangeOf[pair] = se;
        layoutStruct.pairOfStandardExchange[se] = pair;
    }
}
