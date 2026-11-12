// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {UniswapV4DetfMigrationSnapshotLib as SnapshotLib} from "./UniswapV4DetfMigrationSnapshotLib.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "./legacy/MigrationLegacyRecoveryLib.sol";

/// @notice Separate removable loader keeps both administration facets within EIP170.
contract UniswapV4DetfMigrationClaimVaultAllocationTarget is UniswapV4DetfMigrationPolicy {
    function configureHeldSeLpEntitlements(Migration.HeldSeLpEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.HeldSeLpEntitlementInput calldata input_ = inputs_[i_];
            Legacy.requireHeldSeLpSource(input_.source);
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidHeldSeLpEntitlement(original_);
            }
            _requireUnallocatedOrigin(original_, input_.source);
            Migration.HeldSeLpSurrender storage surrender_ = m_.heldSeLpSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.HeldSeLpIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.heldSeLpEntitlements[original_] = Migration.HeldSeLpEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.HeldSeLpEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.source, input_.originalUnits, credit_
            );
        }
    }

    function configureWeightedLiquidEntitlements(Migration.WeightedLiquidEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.WeightedLiquidEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.WEIGHTED_DETF) {
                revert Migration.UnsupportedWeightedLiquidSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidWeightedLiquidEntitlement(original_);
            }
            _requireUnallocatedOrigin(original_, input_.source);
            Migration.WeightedLiquidSurrender storage surrender_ = m_.weightedLiquidSurrenders[original_];
            // Surrender is closed throughout configuration. Never erase impossible execution facts.
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.WeightedLiquidIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.weightedLiquidEntitlements[original_] =
                Migration.WeightedLiquidEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.WeightedLiquidEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }
    modifier administration() {
        MultiStepOwnableRepo._onlyOwner();
        if (Repo._layoutStruct().activated) revert Migration.MigrationAlreadyActivated();
        _requireIdleChildren();
        _;
    }

    function _requireUnallocatedOrigin(bytes32 original_, address source_) private view {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
            || m_.nftOriginal[original_]
            || (source_ != Legacy.WEIGHTED_DETF && m_.weightedLiquidEntitlements[original_].configured)
            || m_.weightedSyEntitlements[original_].configured
            || m_.dtfCustodySeEntitlements[original_].configured
            || m_.claimVaultEntitlements[original_].configured
            || m_.weightedReceiptEntitlements[original_].configured
            || m_.earlierReceiptEntitlements[original_].configured
            || (source_ != Legacy.EARLIER_DETF && m_.earlierLiquidEntitlements[original_].configured)
            || (m_.heldSeLpEntitlements[original_].configured
                && m_.heldSeLpEntitlements[original_].original.source != source_)) {
            revert Migration.DuplicateOriginalEntitlement(original_);
        }
    }

    function configureEarlierLiquidEntitlements(Migration.EarlierLiquidEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.EarlierLiquidEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.EARLIER_DETF) {
                revert Migration.UnsupportedEarlierLiquidSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidEarlierLiquidEntitlement(original_);
            }
            _requireUnallocatedOrigin(original_, input_.source);
            Migration.EarlierLiquidSurrender storage surrender_ = m_.earlierLiquidSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.EarlierLiquidIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.earlierLiquidEntitlements[original_] =
                Migration.EarlierLiquidEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.EarlierLiquidEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }

    function configureClaimVaultEntitlements(Migration.ClaimVaultEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.ClaimVaultEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.CLAIM_VAULT) {
                revert Migration.UnsupportedClaimVaultSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidClaimVaultEntitlement(original_);
            }
            if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
                || m_.nftOriginal[original_] || m_.weightedLiquidEntitlements[original_].configured
                || m_.weightedSyEntitlements[original_].configured
                || m_.dtfCustodySeEntitlements[original_].configured
                || m_.weightedReceiptEntitlements[original_].configured
                || m_.earlierReceiptEntitlements[original_].configured
                || m_.earlierLiquidEntitlements[original_].configured
                || m_.heldSeLpEntitlements[original_].configured) {
                revert Migration.DuplicateOriginalEntitlement(original_);
            }
            Migration.ClaimVaultSurrender storage surrender_ = m_.claimVaultSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.ClaimVaultIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.claimVaultEntitlements[original_] = Migration.ClaimVaultEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.ClaimVaultEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }

    function configureWeightedReceiptEntitlements(Migration.WeightedReceiptEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.WeightedReceiptEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.WEIGHTED_RECEIPT) {
                revert Migration.UnsupportedWeightedReceiptSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidWeightedReceiptEntitlement(original_);
            }
            if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
                || m_.nftOriginal[original_] || m_.weightedLiquidEntitlements[original_].configured
                || m_.weightedSyEntitlements[original_].configured
                || m_.dtfCustodySeEntitlements[original_].configured
                || m_.claimVaultEntitlements[original_].configured
                || m_.earlierReceiptEntitlements[original_].configured
                || m_.earlierLiquidEntitlements[original_].configured
                || m_.heldSeLpEntitlements[original_].configured) {
                revert Migration.DuplicateOriginalEntitlement(original_);
            }
            Migration.WeightedReceiptSurrender storage surrender_ = m_.weightedReceiptSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.WeightedReceiptIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.weightedReceiptEntitlements[original_] =
                Migration.WeightedReceiptEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.WeightedReceiptEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }

    function configureEarlierReceiptEntitlements(Migration.EarlierReceiptEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.EarlierReceiptEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.EARLIER_RECEIPT) {
                revert Migration.UnsupportedEarlierReceiptSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidEarlierReceiptEntitlement(original_);
            }
            if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
                || m_.nftOriginal[original_] || m_.weightedLiquidEntitlements[original_].configured
                || m_.weightedSyEntitlements[original_].configured
                || m_.dtfCustodySeEntitlements[original_].configured
                || m_.claimVaultEntitlements[original_].configured
                || m_.weightedReceiptEntitlements[original_].configured
                || m_.earlierLiquidEntitlements[original_].configured
                || m_.heldSeLpEntitlements[original_].configured) {
                revert Migration.DuplicateOriginalEntitlement(original_);
            }
            Migration.EarlierReceiptSurrender storage surrender_ = m_.earlierReceiptSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.EarlierReceiptIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.earlierReceiptEntitlements[original_] =
                Migration.EarlierReceiptEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.EarlierReceiptEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }
}
