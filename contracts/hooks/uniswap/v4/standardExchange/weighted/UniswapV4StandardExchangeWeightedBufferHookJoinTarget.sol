// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeWeightedBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol";

/// @notice Liquidity execution entrypoints. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinTarget is UniswapV4StandardExchangeWeightedBufferHookJoinCore {
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

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) public returns (uint256 amountIn) {
        return _entryJoinSingleAssetExactOut(tokenIn, sharesOut, to, amountInMax, deadline);
    }







}
