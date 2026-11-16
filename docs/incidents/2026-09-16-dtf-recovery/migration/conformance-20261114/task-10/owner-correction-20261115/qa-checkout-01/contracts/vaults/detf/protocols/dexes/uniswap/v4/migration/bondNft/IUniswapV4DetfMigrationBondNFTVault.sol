// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Funded bond ABI plus fresh Migration cliffs; reuse canonical BondPosition/BondClaim types.
/// @dev Extend IDetfBondNFT, not the historical LP-ledger IDETFNFTVault. Preserve all three guarded
/// ERC721 transfers, donation/Permit2 routes and parent-only foreign-token custody. Ordinary active
/// createFundedPosition remains unmarked and linear; marked rewards/combined claims reject while closed.
interface IUniswapV4DetfMigrationBondNFTVault is
    IDetfBondNFT,
    IDetfNftReserveDonation,
    IUniswapV4DetfMigrationAccounting
{
    event MigrationPositionCreated(
        uint256 indexed tokenId, address indexed recipient, uint256 principal, uint256 start, uint256 unlockTime
    );

    /// @notice Fixed parent only: pull/stake exact native DETF and open a fresh 90-day cliff from now.
    /// @dev No caller-selected old timestamp, duration or credit policy. Both parent issuance routes
    /// use this exact-funded path. Contract recipients must accept the fully opened marked NFT;
    /// callback failure rolls back all funding and any outer legacy custody.
    function createMigrationPosition(uint256 principal_, address recipient_) external returns (uint256 tokenId_);

    /// @notice Marker selecting cliff policy and metadata; not an additional position/principal ledger.
    function isMigrationPosition(uint256 tokenId_) external view returns (bool);

    /// @notice Canonical aggregate attributed position gons, including post-debit state during delivery/retirement.
    function attributedBondGons() external view returns (uint256);
}
