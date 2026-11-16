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
    modifier administration() {
        MultiStepOwnableRepo._onlyOwner();
        if (Repo._layoutStruct().activated) revert Migration.MigrationAlreadyActivated();
        _requireIdleChildren();
        _;
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
                || m_.dtfCustodySeEntitlements[original_].configured) {
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

}
