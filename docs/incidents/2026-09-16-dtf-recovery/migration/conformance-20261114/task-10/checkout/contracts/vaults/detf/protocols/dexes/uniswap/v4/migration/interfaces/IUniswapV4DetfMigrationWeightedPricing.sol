// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeFrozenQuoteInputs} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";

/// @notice Complete manual Weighted pricing; no entitlement, custody or activation ABI.
interface IUniswapV4DetfMigrationWeightedPricing {
    enum LegMode { Raw, RawRate, DisabledBuffer, EnabledV3Buffer }

    struct Leg {
        address token;
        address standardExchange;
        LegMode mode;
        uint256 rawReserve;
        uint256 seReserve;
        uint256 weight;
        uint256 invScale;
        uint256 ratedScale;
        uint256 rate;
        IStandardExchangeFrozenQuoteInputs.Inputs deposit;
    }

    struct Inputs {
        uint256 swapFeeWad;
        uint256 seigniorage;
        uint256 ethIndex;
        uint256 dtfIndex;
        uint256 detfIndex;
        Leg[] legs;
    }

    struct Book {
        uint256 version;
        uint256 chainId;
        address consumer;
        address weth;
        address originalDtf;
        bytes32 id;
        Inputs inputs;
    }

    struct Result {
        uint256 pairEquivalent;
        uint256 boosted;
        uint256 net;
        uint256 ratedInflow;
        uint256 gross;
        uint256 user;
    }

    error MigrationWeightedPricingNotSet();
    error MigrationWeightedPricingInvalid();
    error MigrationWeightedPricingBookMismatch(bytes32 expected, bytes32 actual);
    event MigrationWeightedPricingSet(bytes32 indexed bookId);
}
