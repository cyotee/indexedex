// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "../UniswapV4DetfMigrationRepo.sol";
import {IMigrationLegacyNft, IMigrationWeightedNft, IMigrationEarlierNft} from "./IMigrationLegacyNft.sol";

/// @notice Two fixed historical sources, not a mutable source registry or ABI autodetector.
library MigrationLegacyNftLib {
    address internal constant WEIGHTED = 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E;
    address internal constant EARLIER = 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391;

    function requireSource(address collection_) internal view {
        if (block.chainid != 4663 || (collection_ != WEIGHTED && collection_ != EARLIER)) {
            revert Migration.UnsupportedMigrationNft(block.chainid, collection_);
        }
    }

    function originalId(address collection_, uint256 tokenId_) internal view returns (bytes32) {
        requireSource(collection_);
        return keccak256(abi.encode("migration.nft", block.chainid, address(this),
            collection_, tokenId_));
    }

    /// @dev The returned fingerprint checks all five weighted fields, but only earlier original
    /// shares: reward debt/weight and physical LP value are not eligible earlier principal.
    function position(address collection_, uint256 tokenId_, uint256 originalUnits_)
        internal view returns (uint256 remaining_, bytes32 fingerprint_)
    {
        requireSource(collection_);
        if (collection_ == WEIGHTED) {
            IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(collection_).positionOf(tokenId_);
            if (p_.principal != originalUnits_ || p_.claimedPrincipal > p_.principal) {
                revert Migration.InvalidNftEntitlement(collection_, tokenId_);
            }
            remaining_ = p_.principal - p_.claimedPrincipal;
            fingerprint_ = keccak256(abi.encode(p_));
        } else {
            uint256 shares_ = IMigrationEarlierNft(collection_).getPosition(tokenId_).originalShares;
            if (shares_ != originalUnits_) revert Migration.InvalidNftEntitlement(collection_, tokenId_);
            remaining_ = shares_;
            fingerprint_ = keccak256(abi.encode(shares_));
        }
        if (remaining_ == 0) revert Migration.InvalidNftEntitlement(collection_, tokenId_);
    }

    function preview(address collection_, uint256 tokenId_)
        internal view returns (address holder_, uint256 remaining_, uint256 credit_, bytes32 fingerprint_)
    {
        requireSource(collection_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.nftSurrenders[collection_][tokenId_].consumed) {
            revert Migration.NftAlreadyConsumed(collection_, tokenId_);
        }
        Migration.NftEntitlement storage config_ = m_.nftEntitlements[collection_][tokenId_];
        if (tokenId_ < 3 || config_.configurationId == bytes32(0)) {
            revert Migration.InvalidNftEntitlement(collection_, tokenId_);
        }
        holder_ = IMigrationLegacyNft(collection_).ownerOf(tokenId_);
        if (holder_ == address(0)) revert Migration.InvalidNftEntitlement(collection_, tokenId_);
        (remaining_, fingerprint_) = position(collection_, tokenId_, config_.original.originalUnits);
        uint256[] memory credits_ = contributionCredits(collection_, tokenId_, remaining_);
        for (uint256 i_; i_ < credits_.length; ++i_) credit_ += credits_[i_];
    }

    function contributionCredits(address collection_, uint256 tokenId_, uint256 remaining_)
        internal view returns (uint256[] memory credits_)
    {
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.NftContribution[] storage originals_ = m_.nftContributions[collection_][tokenId_];
        uint256 originalUnits_ = m_.nftEntitlements[collection_][tokenId_].original.originalUnits;
        credits_ = new uint256[](originals_.length);
        for (uint256 i_; i_ < originals_.length; ++i_) {
            credits_[i_] = Math.mulDiv(originals_[i_].credit, remaining_, originalUnits_);
            if (credits_[i_] == 0) revert Migration.InvalidNftEntitlement(collection_, tokenId_);
        }
    }
}
