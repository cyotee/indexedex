// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeWeightedBufferHookExitCore} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol";

/// @notice Liquidity execution entrypoints. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeWeightedBufferHookExitTarget is UniswapV4StandardExchangeWeightedBufferHookExitCore {
    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) public returns (uint256[] memory amounts) {
        return _entryExitProportional(shares, to, amountsMin, deadline);
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public returns (uint256 amountOut) {
        return _entryExitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public returns (uint256 amountOut) {
        return _entryWithdrawSingle(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public returns (uint256 sharesIn) {
        return _entryExitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function withdrawSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public returns (uint256 sharesIn) {
        return _entryWithdrawSingleExactOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function exitProportionalFlexible(
        uint256 shares,
        address to,
        bool[] calldata receiveSeShare,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) public returns (uint256[] memory amounts) {
        return _entryExitProportionalFlexible(shares, to, receiveSeShare, amountsMin, deadline);
    }

    function exitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public returns (uint256 amountOut) {
        return _entryExitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline);
    }

    function withdrawSingleFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public returns (uint256 amountOut) {
        return _entryWithdrawSingleFlexible(tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline);
    }

}
