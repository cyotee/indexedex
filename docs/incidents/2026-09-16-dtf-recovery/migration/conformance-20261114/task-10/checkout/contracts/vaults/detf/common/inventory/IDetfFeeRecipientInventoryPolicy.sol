// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IDetfFeeRecipientInventoryPolicy {
    function feeRecipientNFTId() external view returns (uint256 tokenId);

    function addToFeeRecipientNFT(uint256 tokenId, uint256 shares) external;
}