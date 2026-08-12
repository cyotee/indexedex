// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';

interface IComposedStableCommonDetfBonding {
    function acceptedBondTokens() external view returns (address[] memory tokens);
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
        external
        returns (uint256 tokenId, uint256 shares);

    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        returns (uint256 claimMinted);

    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);

    function closeBondMature(
        uint256 tokenId,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewCloseBondMature(uint256 tokenId, IERC20 tokenOut) external view returns (uint256 amountOut);

    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);

    function protocolBondOriginalShares() external view returns (uint256);
}