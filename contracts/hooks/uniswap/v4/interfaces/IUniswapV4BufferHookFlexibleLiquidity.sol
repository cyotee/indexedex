// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Existing buffer-hook routes selecting the SE share of a named pair-token leg.
interface IUniswapV4BufferHookFlexibleLiquidity {
    function previewJoinSingleAssetExactInFlexible(address pair, uint256 amount, bool asSeShare) external view returns (uint256);
    function joinSingleAssetExactInFlexible(address pair, uint256 amount, bool asSeShare, address recipient, uint256 minimum, uint256 deadline) external returns (uint256);
    function previewExitSingleAssetExactBptInFlexible(address pair, uint256 shares, bool asSeShare) external view returns (uint256);
    function exitSingleAssetExactBptInFlexible(address pair, uint256 shares, bool asSeShare, address recipient, uint256 minimum, uint256 deadline) external returns (uint256);
}
