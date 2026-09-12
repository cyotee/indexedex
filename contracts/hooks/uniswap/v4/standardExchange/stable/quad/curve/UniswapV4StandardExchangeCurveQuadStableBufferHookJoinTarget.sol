// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol";

/// @notice Liquidity execution entrypoints. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinTarget is UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore {
    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares, uint256[] memory usedAmounts) {
        return _entryJoinProportional(amounts, to, sharesMin, deadline);
    }

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        public
        returns (uint256 shares)
    {
        return _entryJoinUnbalanced(amounts, to, sharesMin, deadline);
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryJoinUnbalanced(tokensIn, amounts, to, sharesMin, deadline);
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) public returns (uint256 amountIn) {
        return _entryJoinSingleAssetExactOut(tokenIn, sharesOut, to, amountInMax, deadline);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryJoinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryDepositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function joinProportionalFlexible(
        uint256[] calldata amounts,
        bool[] calldata amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares, uint256[] memory usedAmounts) {
        return _entryJoinProportionalFlexible(amounts, amountIsSeShare, to, sharesMin, deadline);
    }

    function joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }

    function depositSingleFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryDepositSingleFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }

}
