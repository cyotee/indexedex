// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";

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

    /// @notice Explicit encoding: zero is absent, one is legacy Inputs, two is SwapDepositV2.
    struct VersionedInputs {
        uint256 version;
        bytes data;
    }

    /// @notice Manual operands for the new V3 liquidity-based deposit preview.
    /// @dev The complete pool snapshot is required; custody and decimals do not set share issuance.
    struct SwapDepositV2 {
        address exchange;
        Request request;
        address pool;
        address token0;
        address token1;
        uint256 supply;
        uint128 positionLiquidity;
        uint256 usageFeeWad;
        address feeTo;
        UniswapV3Quoter.PoolSnapshot poolState;
    }

    error UnsupportedFrozenVersion(uint256 version);
    error InvalidFrozenDeposit();
    error UnsupportedFrozenQuote(address exchange, address tokenIn, address tokenOut, Mode mode);

    function captureFrozenQuoteInputs(Request calldata request) external view returns (Inputs memory);
}
