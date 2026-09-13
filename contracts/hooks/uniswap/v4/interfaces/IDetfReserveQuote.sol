// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IDetfReserveQuote
 * @notice DETF quote views on every Uni V4 SE buffer hook. Hook does not read DETF storage.
 * @dev PRD DETF_INSTANCE_IO_ROUTING H18 / §15.12.
 */
interface IDetfReserveQuote {
    struct DetfQuoteCtx {
        uint256 detfTotalSupply; // Human DETF supply scaled to WAD, independent of token decimals.
        uint256 pendingExpansion; // Additional supply in the same WAD unit, if explicitly simulated.
        uint256 ownedLp;
        uint256 creationPairPerDetfWad;
    }

    /// @notice Quote an external SE conversion followed by its pair-to-raw reserve swap.
    /// @dev Uses the projected SE book after exchanging tokenIn into pairToken.
    function previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        external view returns (uint256 amountOut);

    /// @notice Quote a custom payment wrapped into newly issued SE shares,
    /// followed by the family's existing single-asset liquidity join.
    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256 sharesOut);

    /// @notice Purchased and matching-liquidity DETF quotes at the SE book after
    /// wrapping a custom bond payment. The duration multiplier applies once.
    /// @dev An inactive reserve returns the received pair value for linear opening pricing.
    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf);

    function previewSynthetic(DetfQuoteCtx calldata ctx, address numeraire)
        external
        view
        returns (uint256 wad);

    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut);
}
