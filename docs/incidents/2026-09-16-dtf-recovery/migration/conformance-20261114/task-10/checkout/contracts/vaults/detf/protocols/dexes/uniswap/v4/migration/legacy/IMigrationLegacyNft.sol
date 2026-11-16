// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Historical chain-4663 proxy ABI admitted by migration/nft/source-verification/report.md.
/// @dev Both deployed sources call the receiver BEFORE changing ownership or checking approval.
interface IMigrationLegacyNft {
    function ownerOf(uint256 tokenId_) external view returns (address);
    function safeTransferFrom(address from_, address to_, uint256 tokenId_) external;
}

interface IMigrationWeightedNft is IMigrationLegacyNft {
    struct Position {
        uint256 principal;
        uint256 claimedPrincipal;
        uint256 stakingGons;
        uint256 startTimestamp;
        uint256 vestingDuration;
    }
    function positionOf(uint256 tokenId_) external view returns (Position memory);
}

interface IMigrationEarlierNft is IMigrationLegacyNft {
    struct Position {
        uint256 originalShares;
        uint256 effectiveShares;
        uint256 bonusMultiplier;
        uint256 unlockTime;
        uint256 rewardDebt;
    }
    function getPosition(uint256 tokenId_) external view returns (Position memory);
}
