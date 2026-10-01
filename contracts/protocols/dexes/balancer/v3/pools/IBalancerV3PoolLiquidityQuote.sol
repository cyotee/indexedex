// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Optional pool-owned math and hook state for sequential SE liquidity quotes.
/// @dev The SE adapter carries state without interpreting the pool family's virtual book.
interface IBalancerV3PoolLiquidityQuote {
    struct LiquidityQuoteParams {
        uint256[] balancesLiveScaled18;
        uint256 index;
        uint256 amountScaled18;
        uint256 supply;
        uint256 swapFee;
        bool joining;
        bool exactOut;
    }

    function quotePoolState(uint256[] calldata scalingFactors, uint256[] calldata rates)
        external view returns (bytes memory state);

    /// @return result BPT for exact-in adds / exact-out removes, scaled token amount otherwise.
    /// @return swapFeesScaled18 Per-token swap fees before the Vault's aggregate-fee split.
    function quotePoolLiquidity(bytes calldata state, LiquidityQuoteParams calldata params)
        external view returns (uint256 result, uint256[] memory swapFeesScaled18);

    /// @dev Only physical-token unbalanced adds and single-token removes are supported.
    function quotePoolStateAfterLiquidity(bytes calldata state, bool joining, uint256 bptAmount, uint256 supplyBefore)
        external view returns (bytes memory nextState);
}
