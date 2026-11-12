// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationRecoveryTarget} from "./UniswapV4DetfMigrationRecoveryTarget.sol";

/// @notice Persistent finite recovery surface; no removable administration selectors.
contract UniswapV4DetfMigrationRecoveryFacet is UniswapV4DetfMigrationRecoveryTarget, IFacet {
    function facetName() public pure returns (string memory) { return "UniswapV4DetfMigrationRecoveryFacet"; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(Recovery).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](17);
        funcs_[0] = Recovery.recoverMigrationNfts.selector;
        funcs_[1] = Recovery.migrationRecoveryInventory.selector;
        funcs_[2] = Recovery.migrationRecoveryGons.selector;
        funcs_[3] = Recovery.migrationNftRecovery.selector;
        funcs_[4] = Migration.claimVaultEntitlement.selector;
        funcs_[5] = Migration.claimVaultSurrender.selector;
        funcs_[6] = Migration.previewClaimVaultSurrender.selector;
        funcs_[7] = Migration.surrenderMigrationClaimVault.selector;
        funcs_[8] = Migration.weightedReceiptEntitlement.selector;
        funcs_[9] = Migration.weightedReceiptSurrender.selector;
        funcs_[10] = Migration.previewWeightedReceiptSurrender.selector;
        funcs_[11] = Migration.surrenderMigrationWeightedReceipt.selector;
        funcs_[12] = Recovery.migrationEarlierReceiptInternalShares.selector;
        funcs_[13] = Migration.earlierReceiptEntitlement.selector;
        funcs_[14] = Migration.earlierReceiptSurrender.selector;
        funcs_[15] = Migration.previewEarlierReceiptSurrender.selector;
        funcs_[16] = Migration.surrenderMigrationEarlierReceipt.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
