// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";

/// @notice Read-only acquisition in the hook's caller context, never an evaluation callback.
interface IUniswapV4StandardExchangeWeightedBufferHookCapture {
    struct Outcome {
        bool success;
        bytes data;
    }

    struct Leg {
        address token;
        address standardExchange;
        address provider;
        uint256 weight;
        uint256 invScale;
        uint256 ratedScale;
        uint256 rawReserve;
        uint256 seReserve;
        Outcome rate;
        Outcome registration;
        Outcome disabled;
        bool depositSupported;
        Frozen.Inputs deposit;
        bytes depositError;
        address captureFacet;
        bytes32 captureCodeHash;
        address previewFacet;
        bytes32 previewCodeHash;
    }

    struct Book {
        address hook;
        address registry;
        address feeOracle;
        Outcome fee;
        Leg[] legs;
    }

    function captureWeightedMintBook() external view returns (Book memory);
}
