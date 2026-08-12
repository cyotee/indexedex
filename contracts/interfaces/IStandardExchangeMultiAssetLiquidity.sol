// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IStandardExchangeMultiAssetLiquidity
 * @notice Multi-token join/exit surface for Standard Exchange family products that own a weighted
 *         (or multi-asset) inventory book. Selectors/args are product-defined 1:1 with the host hook
 *         liquidity ABI when used by Uni V4 SE Weighted Buffer Hook (PRD Q19 / D55 / D55a).
 * @dev Canonical `IStandardExchangeIn` / `IStandardExchangeOut` remain **swap-only**. This interface
 *      is a separate liquidity extension — do not merge selectors into In/Out.
 */
interface IStandardExchangeMultiAssetLiquidity {
    /* ----------------------------- Proportional ----------------------------- */

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts);

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares, uint256[] memory usedAmounts);

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);

    function exitProportional(uint256 shares, address to, uint256[] calldata amountsMin, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    /* ----------------------------- Unbalanced ------------------------------- */

    function previewJoinUnbalanced(uint256[] calldata amounts) external view returns (uint256 shares);

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external
        returns (uint256 shares);

    /* ------------------------ Single-asset join/exit ------------------------ */

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256 amountIn);

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut);

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice Exact-token-out single-asset exit (D42a) — closed-form only; may be omitted if peer lacks it.
    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn);

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external returns (uint256 sharesIn);

    /* ------------------------------- Aliases -------------------------------- */

    /// @dev Alias of `joinSingleAssetExactIn` (no multi-leg rebalance).
    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external returns (uint256 shares);

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares);

    /// @dev Alias of `exitSingleAssetExactBptIn`.
    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut);

    /// @dev Alias of `exitSingleAssetExactTokenOut` when D42a ships.
    function withdrawSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external returns (uint256 sharesIn);

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn);
}
