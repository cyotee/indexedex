// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeWeightedBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol";

/// @notice Flexible token/share joins.
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget is UniswapV4StandardExchangeWeightedBufferHookJoinCore {
    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public returns (uint256 shares) {
        return _entryJoinUnbalanced(tokensIn, amounts, to, sharesMin, deadline);
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
