// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Liquidity vectors use binding order; a true flag selects that leg's SE shares.
interface IUniswapV4BalancerStableLiquidityUnits {
    event JoinFlexible(address indexed sender, address indexed to, uint256 shares, uint256[] amounts, bool[] amountIsSeShare);
    event ExitFlexible(address indexed sender, address indexed to, uint256 shares, uint256[] amounts, bool[] receiveSeShare);

    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        external view returns (uint256 shares, uint256[] memory usedAmounts);
    function joinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare, address to, uint256 sharesMin, uint256 deadline)
        external returns (uint256 shares, uint256[] memory usedAmounts);
    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        external view returns (uint256[] memory amounts);
    function exitProportionalFlexible(uint256 shares, address to, bool[] calldata receiveSeShare, uint256[] calldata amountsMin, uint256 deadline)
        external returns (uint256[] memory amounts);
    function previewJoinUnbalanced(address[] calldata tokens, uint256[] calldata amounts) external view returns (uint256 shares);
    function joinUnbalanced(address[] calldata tokens, uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        external returns (uint256 shares);
}
