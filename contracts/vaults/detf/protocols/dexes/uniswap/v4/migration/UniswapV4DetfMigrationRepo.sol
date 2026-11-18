// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {UniswapV4DetfMigrationWeightedPricingLib as PricingLib} from "./UniswapV4DetfMigrationWeightedPricingLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Migration lifecycle and configuration, separate from canonical supply and execution history.
library UniswapV4DetfMigrationRepo {
    using BetterSafeERC20 for IERC20;
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration"))) - 1);

    struct Storage {
        bool activated;
        address weth;
        address originalDtf;
        address rewardToken;
        address expectedSynchronizer;
        uint256 bootstrapSelfMinted;
        bytes weightedPricing;
        mapping(address => uint256) donationInventory;
        mapping(address => uint256) residualInventory;
        mapping(address => uint256) operationFloor;
        bool budgetOpen;
        mapping(address => Migration.IndependentAllocation) allocations;
        mapping(address => Migration.IndependentIssuance) issuances;
        mapping(bytes32 => address) configuredOriginal;
        mapping(bytes32 => address) issuedOriginal;
        mapping(address => mapping(uint256 => Migration.NftEntitlement)) nftEntitlements;
        mapping(address => mapping(uint256 => Migration.NftSurrender)) nftSurrenders;
        mapping(address => mapping(uint256 => Migration.NftCustody)) nftCustodies;
        mapping(bytes32 => bool) nftOriginal;
        NftReceipt expectedNft;
        mapping(bytes32 => Migration.WeightedLiquidEntitlement) weightedLiquidEntitlements;
        mapping(bytes32 => Migration.WeightedLiquidSurrender) weightedLiquidSurrenders;
        uint256 ownerFirstBondTokenId;
        mapping(bytes32 => Migration.WeightedSyEntitlement) weightedSyEntitlements;
        mapping(bytes32 => Migration.WeightedSySurrender) weightedSySurrenders;
        mapping(bytes32 => Migration.DtfCustodySeEntitlement) dtfCustodySeEntitlements;
        mapping(bytes32 => Migration.DtfCustodySeSurrender) dtfCustodySeSurrenders;
        mapping(bytes32 => Migration.ClaimVaultEntitlement) claimVaultEntitlements;
        mapping(bytes32 => Migration.ClaimVaultSurrender) claimVaultSurrenders;
        mapping(bytes32 => Migration.WeightedReceiptEntitlement) weightedReceiptEntitlements;
        mapping(bytes32 => Migration.WeightedReceiptSurrender) weightedReceiptSurrenders;
        mapping(bytes32 => Migration.EarlierReceiptEntitlement) earlierReceiptEntitlements;
        mapping(bytes32 => Migration.EarlierReceiptSurrender) earlierReceiptSurrenders;
        mapping(bytes32 => Migration.EarlierLiquidEntitlement) earlierLiquidEntitlements;
        mapping(bytes32 => Migration.EarlierLiquidSurrender) earlierLiquidSurrenders;
        mapping(bytes32 => Migration.HeldSeLpEntitlement) heldSeLpEntitlements;
        mapping(bytes32 => Migration.HeldSeLpSurrender) heldSeLpSurrenders;
        mapping(address => mapping(uint256 => Migration.NftContribution[])) nftContributions;
        mapping(address => mapping(uint256 => Migration.NftContributionSurrender[])) nftContributionSurrenders;
        mapping(bytes32 => Migration.ClaimedSyWeights) claimedSyWeights;
        // Append only. Zero with nonempty historical bytes denotes legacy version two.
        uint256 weightedPricingVersion;
    }

    struct NftReceipt {
        address collection;
        address holder;
        uint256 tokenId;
        bool accepted;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _legacyWeightedPricing() internal view returns (Pricing.Book memory book_) {
        Storage storage m_ = _layoutStruct();
        uint256 version_ = _weightedPricingVersion(m_);
        if (version_ != 2) revert Pricing.MigrationWeightedPricingVersionMismatch(2, version_);
        book_ = abi.decode(m_.weightedPricing, (Pricing.Book));
        if (book_.version != 2) revert Pricing.MigrationWeightedPricingVersionMismatch(2, book_.version);
    }

    /// @notice Decode the recorded encoding, then normalize legacy operands without rehashing their id.
    function _weightedPricing() internal view returns (Pricing.BookV3 memory book_) {
        Storage storage m_ = _layoutStruct();
        uint256 version_ = _weightedPricingVersion(m_);
        if (version_ == 2) return PricingLib.normalize(_legacyWeightedPricing());
        book_ = abi.decode(m_.weightedPricing, (Pricing.BookV3));
        if (book_.version != 3) revert Pricing.MigrationWeightedPricingVersionMismatch(3, book_.version);
    }

    function _weightedPricingVersion(Storage storage m_) private view returns (uint256 version_) {
        if (m_.weightedPricing.length == 0) revert Pricing.MigrationWeightedPricingNotSet();
        version_ = m_.weightedPricingVersion;
        if (version_ == 0) return 2;
        if (version_ != 2 && version_ != 3) revert Pricing.MigrationWeightedPricingInvalid();
    }

    /// @notice Bind loading to the exact book prepared by the caller, even for an empty batch.
    function _weightedPricing(bytes32 expectedBookId_) internal view returns (Pricing.BookV3 memory book_) {
        book_ = _weightedPricing();
        if (expectedBookId_ != book_.id) {
            revert Pricing.MigrationWeightedPricingBookMismatch(expectedBookId_, book_.id);
        }
    }

    /// @dev Both parent issuance routes settle participation under the parent lock BEFORE this call.
    /// Reuse the sole child exact-pull/stake/gons path, then remove operation-local approval.
    function _fundBond(uint256 credit_, address recipient_) internal returns (uint256 id_) {
        Storage storage m_ = _layoutStruct();
        address bond_ = address(ParentRepo._layoutStruct().bondNftVault);
        ERC20Repo._mint(address(this), credit_);
        IERC20(address(this)).forceApprove(bond_, credit_);
        m_.expectedSynchronizer = bond_;
        id_ = IUniswapV4DetfMigrationBondNFTVault(bond_).createMigrationPosition(credit_, recipient_);
        delete m_.expectedSynchronizer;
        IERC20(address(this)).forceApprove(bond_, 0);
    }
}
