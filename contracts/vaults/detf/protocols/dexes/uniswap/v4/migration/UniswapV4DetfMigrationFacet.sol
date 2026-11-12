// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationTarget} from "./UniswapV4DetfMigrationTarget.sol";
contract UniswapV4DetfMigrationFacet is UniswapV4DetfMigrationTarget, IFacet {
function facetName() public pure returns(string memory) { return "UniswapV4DetfMigrationFacet"; }
function facetInterfaces() public pure returns(bytes4[] memory ids_) { ids_ = new bytes4[](2); ids_[0] = type(Migration).interfaceId; ids_[1] = type(IERC721Receiver).interfaceId; }
function facetFuncs() public pure returns(bytes4[] memory funcs_) { funcs_ = new bytes4[](30);
funcs_[0] = Migration.migrationActivated.selector;
funcs_[1] = Migration.migrationSyRewardToken.selector;
funcs_[2] = Migration.migrationSnapshotSource.selector;
funcs_[3] = Migration.migrationSnapshot.selector;
funcs_[4] = Migration.previewOriginalCredit.selector;
funcs_[5] = Migration.independentAllocation.selector;
funcs_[6] = Migration.independentIssuance.selector;
funcs_[7] = Migration.migrationDonationInventory.selector;
funcs_[8] = Migration.migrationBootstrapSelfMinted.selector;
funcs_[9] = Migration.donateMigrationCapital.selector;
funcs_[10] = Migration.migrationNftOriginalId.selector;
funcs_[11] = Migration.nftEntitlement.selector;
funcs_[12] = Migration.nftSurrender.selector;
funcs_[13] = Migration.nftCustody.selector;
funcs_[14] = Migration.previewNftSurrender.selector;
funcs_[15] = Migration.surrenderMigrationNft.selector;
funcs_[16] = IERC721Receiver.onERC721Received.selector;
funcs_[17] = Migration.weightedLiquidEntitlement.selector;
funcs_[18] = Migration.weightedLiquidSurrender.selector;
funcs_[19] = Migration.previewWeightedLiquidSurrender.selector;
funcs_[20] = Migration.surrenderMigrationWeightedLiquid.selector;
funcs_[21] = Migration.migrationOwnerFirstBondTokenId.selector;
funcs_[22] = Migration.weightedSyEntitlement.selector;
funcs_[23] = Migration.weightedSySurrender.selector;
funcs_[24] = Migration.previewWeightedSySurrender.selector;
funcs_[25] = Migration.surrenderMigrationWeightedSy.selector;
funcs_[26] = Migration.dtfCustodySeEntitlement.selector;
funcs_[27] = Migration.dtfCustodySeSurrender.selector;
funcs_[28] = Migration.previewDtfCustodySeSurrender.selector;
funcs_[29] = Migration.surrenderMigrationDtfCustodySe.selector; }
function facetMetadata() external pure returns(string memory,bytes4[] memory,bytes4[] memory) { return (facetName(),facetInterfaces(),facetFuncs()); }
}
