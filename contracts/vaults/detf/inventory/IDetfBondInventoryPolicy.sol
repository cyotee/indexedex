// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDetfBondInventoryPolicy {
    function protocolNFTId() external view returns (uint256 tokenId);

    function createPosition(uint256 shares, uint256 lockDuration, address recipient)
        external
        returns (uint256 tokenId);

    function sellPositionToProtocol(uint256 tokenId, address seller, address rewardsRecipient)
        external
        returns (uint256 principalShares, uint256 rewardsClaimed);

    function addToProtocolNFT(uint256 tokenId, uint256 shares) external;

    function reallocateProtocolRewards(address recipient) external returns (uint256 amount);
}