// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Closed ordinary deposit state. This is not a generic ERC4626 model claim.
interface IStandardExchangeFrozenQuoteInputs {
    enum Model { Unsupported, UniswapV3PairDeposit }
    enum Mode { OrdinaryConversion, OrdinaryDeposit, OrdinaryRedemption, TransitionRedemption }

    struct Request {
        address tokenIn;
        address tokenOut;
        address holder;
        Mode mode;
    }

    struct Inputs {
        Model model;
        address exchange;
        Request request;
        address token0;
        address token1;
        uint256 supply;
        uint256 reserve0;
        uint256 reserve1;
        uint256 minimumLiquidity;
    }

    error UnsupportedFrozenQuote(address exchange, address tokenIn, address tokenOut, Mode mode);

    function captureFrozenQuoteInputs(Request calldata request) external view returns (Inputs memory);
}
