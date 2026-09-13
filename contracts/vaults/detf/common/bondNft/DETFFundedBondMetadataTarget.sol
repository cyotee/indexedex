// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC721MetadataRepo} from "@crane/contracts/tokens/ERC721/ERC721MetadataRepo.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedBondRepo} from "contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol";
import {DETFFundedBondMetadata} from "contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol";

/// @title DETFFundedBondMetadataTarget
/// @notice Read-only renderer, separated from funded custody to keep each facet deployable.
contract DETFFundedBondMetadataTarget {
    function name() external view returns (string memory) { return ERC721MetadataRepo._name(); }
    function symbol() external view returns (string memory) { return ERC721MetadataRepo._symbol(); }

    /// @notice Derive image and JSON from the canonical funded position views.
    function tokenURI(uint256 tokenId_) external view returns (string memory) {
        IDetfBondNFT bond_ = IDetfBondNFT(address(this));
        IERC20Metadata detf_ = IERC20Metadata(DETFFundedBondRepo._layoutStruct().detf);
        DETFFundedBondMetadata.View memory v_;
        v_.position = bond_.positionOf(tokenId_);
        v_.claim = bond_.previewClaim(tokenId_);
        v_.detfName = detf_.name();
        v_.detfSymbol = detf_.symbol();
        v_.tokenId = tokenId_;
        v_.timestamp = block.timestamp;
        return DETFFundedBondMetadata._uri(v_);
    }
}
