// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
interface IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance {
    error RebalanceUnavailable();
    error NoRebalanceProgress();
    error RebalanceLossExceeded(uint256 beforeValue, uint256 afterValue, uint256 maximumLoss);
    event Rebalanced(uint256 beforeValue, uint256 afterValue, uint128 coreBefore, uint128 coreAfter);
    function rebalance(uint256 minimumValueAfter, uint256 deadline) external returns (uint256 valueAfter);
}
