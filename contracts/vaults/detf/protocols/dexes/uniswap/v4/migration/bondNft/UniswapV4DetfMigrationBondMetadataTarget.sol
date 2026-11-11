// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC721MetadataRepo} from "@crane/contracts/tokens/ERC721/ERC721MetadataRepo.sol";
import {DETFFundedBondRepo} from "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";
import {DETFFundedBondMetadata} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol";
import {IUniswapV4DetfMigration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Metadata reads actual proxy position, policy and finalized parent gate; no projected yield.
contract UniswapV4DetfMigrationBondMetadataTarget {
    /// @notice Existing child collection name.
    function name() external view returns (string memory) { return ERC721MetadataRepo._name(); }

    /// @notice Existing child collection symbol.
    function symbol() external view returns (string memory) { return ERC721MetadataRepo._symbol(); }

    /// @notice A truthful cliff image and JSON; ordinary purchased positions use the ordinary renderer.
    function tokenURI(uint256 tokenId_) external view returns (string memory) {
        IUniswapV4DetfMigrationBondNFTVault bond_ = IUniswapV4DetfMigrationBondNFTVault(address(this));
        address parent_ = DETFFundedBondRepo._layoutStruct().detf;
        DETFFundedBondMetadata.View memory v_;
        v_.position = bond_.positionOf(tokenId_);
        v_.claim = bond_.previewClaim(tokenId_);
        v_.detfName = IERC20Metadata(parent_).name();
        v_.detfSymbol = IERC20Metadata(parent_).symbol();
        v_.tokenId = tokenId_;
        v_.timestamp = block.timestamp;
        v_.migrationCliff = bond_.isMigrationPosition(tokenId_);
        v_.migrationPresentation = v_.migrationCliff || tokenId_ < 3;
        v_.rewardsClosed = v_.migrationPresentation && !IUniswapV4DetfMigration(parent_).migrationActivated();
        return DETFFundedBondMetadata._uri(v_);
    }
}
