// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeOrbitalBufferHookDepositCore} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol";

/// @notice Single-token zap execution.
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositZapTarget is UniswapV4StandardExchangeOrbitalBufferHookDepositCore {
    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 shares) {
        return _entryDepositSingle(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares) {
        return _entryJoinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external returns (uint256 amountIn) {
        return _entryJoinSingleAssetExactOut(tokenIn, sharesOut, to, amountInMax, deadline);
    }
}
