// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol";

/// @notice Join execution through the shared reserve accounting.
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityTarget is UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore {
    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public  returns (uint256 shares, uint256[] memory usedAmounts) {
        return _entryJoinProportional(amounts, to, sharesMin, deadline);
    }

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        public  returns (uint256 shares) {
        return _entryJoinUnbalanced(amounts, to, sharesMin, deadline);
    }

    function joinSingleAssetExactOut(address tokenIn, uint256 sharesOut, address to, uint256 amountInMax, uint256 deadline)
        public  returns (uint256 amountIn) {
        return _entryJoinSingleAssetExactOut(tokenIn, sharesOut, to, amountInMax, deadline);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public  returns (uint256 shares) {
        return _entryJoinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public  returns (uint256 shares) {
        return _entryDepositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function joinProportionalFlexible(uint256[] calldata amounts, bool[] calldata sharesIn, address to, uint256 minimum, uint256 deadline)
        external  returns (uint256 shares, uint256[] memory used) {
        return _entryJoinProportionalFlexible(amounts, sharesIn, to, minimum, deadline);
    }

    function joinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        external  returns (uint256 shares) {
        return _entryJoinUnbalanced(tokens_, amounts, to, minimum, deadline);
    }
}
