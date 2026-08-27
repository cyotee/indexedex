// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IUniswapV4SeBufferHook
 * @notice DETF-facing discovery, swap, and liquidity surface for Uni V4 SE buffer hooks.
 * @dev PRD DETF_INSTANCE_IO_ROUTING §15.12. Family deposit and boolean swap-preview names are not on this surface.
 */
interface IUniswapV4SeBufferHook {
    /* ---------------------------------------------------------------------- */
    /*                               Discovery                                */
    /* ---------------------------------------------------------------------- */

    function tokens() external view returns (address[] memory);

    function standardExchangeOf(address token) external view returns (address);

    function syntheticNumeraires() external view returns (address[] memory);

    function requiredFirstBondTokens() external view returns (address[] memory);

    function firstJoinMustBeFullBook() external view returns (bool);

    function isLive() external view returns (bool);

    function tradingFeeWad() external view returns (uint256);

    /* ---------------------------------------------------------------------- */
    /*                                  Swap                                  */
    /* ---------------------------------------------------------------------- */

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function ownerSwapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function ownerSwapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external returns (uint256 amountIn);

    /* ---------------------------------------------------------------------- */
    /*                               Liquidity                                */
    /* ---------------------------------------------------------------------- */

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

    function previewJoinUnbalanced(address[] calldata tokens, uint256[] calldata amounts)
        external
        view
        returns (uint256 shares);

    function joinUnbalanced(address[] calldata tokens, uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external
        returns (uint256 shares);

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

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts);

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

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
}
