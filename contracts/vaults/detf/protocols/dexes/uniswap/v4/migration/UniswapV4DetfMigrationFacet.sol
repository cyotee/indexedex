// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationTarget} from "./UniswapV4DetfMigrationTarget.sol";
contract UniswapV4DetfMigrationFacet is UniswapV4DetfMigrationTarget, IFacet {
function facetName() public pure returns(string memory) { return "UniswapV4DetfMigrationFacet"; }
function facetInterfaces() public pure returns(bytes4[] memory ids_) { ids_ = new bytes4[](1); ids_[0] = type(Migration).interfaceId; }
function facetFuncs() public pure returns(bytes4[] memory funcs_) { funcs_ = new bytes4[](10);
funcs_[0] = Migration.migrationActivated.selector;
funcs_[1] = Migration.migrationSyRewardToken.selector;
funcs_[2] = Migration.migrationSnapshotSource.selector;
funcs_[3] = Migration.migrationSnapshot.selector;
funcs_[4] = Migration.previewOriginalCredit.selector;
funcs_[5] = Migration.independentAllocation.selector;
funcs_[6] = Migration.independentIssuance.selector;
funcs_[7] = Migration.migrationDonationInventory.selector;
funcs_[8] = Migration.migrationBootstrapSelfMinted.selector;
funcs_[9] = Migration.donateMigrationCapital.selector; }
function facetMetadata() external pure returns(string memory,bytes4[] memory,bytes4[] memory) { return (facetName(),facetInterfaces(),facetFuncs()); }
}
