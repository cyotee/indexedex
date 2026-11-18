// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricingV3 as PricingV3} from "./interfaces/IUniswapV4DetfMigrationWeightedPricingV3.sol";
import {UniswapV4DetfMigrationWeightedHookTarget} from "./UniswapV4DetfMigrationWeightedHookTarget.sol";
contract UniswapV4DetfMigrationWeightedHookFacet is UniswapV4DetfMigrationWeightedHookTarget, IFacet {
function facetName() public pure returns(string memory) { return "UniswapV4DetfMigrationWeightedHookFacet"; }
function facetInterfaces() public pure returns(bytes4[] memory ids_) { ids_ = new bytes4[](3); ids_[0] = type(Migration).interfaceId; ids_[1] = type(IERC721Receiver).interfaceId; ids_[2] = type(PricingV3).interfaceId; }
function facetFuncs() public pure returns(bytes4[] memory funcs_) { funcs_ = new bytes4[](29);
funcs_[0] = Migration.migrationActivated.selector;
funcs_[1] = Migration.migrationSyRewardToken.selector;
funcs_[2] = Migration.migrationWeightedPricing.selector;
funcs_[3] = Migration.previewOriginalCredit.selector;
funcs_[4] = Migration.independentAllocation.selector;
funcs_[5] = Migration.independentIssuance.selector;
funcs_[6] = Migration.migrationDonationInventory.selector;
funcs_[7] = Migration.migrationBootstrapSelfMinted.selector;
funcs_[8] = Migration.donateMigrationCapital.selector;
funcs_[9] = Migration.migrationNftOriginalId.selector;
funcs_[10] = Migration.nftCustody.selector;
funcs_[11] = Migration.previewNftSurrender.selector;
funcs_[12] = Migration.surrenderMigrationNft.selector;
funcs_[13] = IERC721Receiver.onERC721Received.selector;
funcs_[14] = Migration.weightedLiquidEntitlement.selector;
funcs_[15] = Migration.weightedLiquidSurrender.selector;
funcs_[16] = Migration.previewWeightedLiquidSurrender.selector;
funcs_[17] = Migration.surrenderMigrationWeightedLiquid.selector;
funcs_[18] = Migration.migrationOwnerFirstBondTokenId.selector;
funcs_[19] = Migration.weightedSyEntitlement.selector;
funcs_[20] = Migration.weightedSySurrender.selector;
funcs_[21] = Migration.previewWeightedSySurrender.selector;
funcs_[22] = Migration.surrenderMigrationWeightedSy.selector;
funcs_[23] = Migration.dtfCustodySeEntitlement.selector;
funcs_[24] = Migration.dtfCustodySeSurrender.selector;
funcs_[25] = Migration.previewDtfCustodySeSurrender.selector;
funcs_[26] = Migration.surrenderMigrationDtfCustodySe.selector;
funcs_[27] = Migration.claimedSyWeights.selector;
funcs_[28] = PricingV3.migrationWeightedPricingV3.selector; }
function facetMetadata() external pure returns(string memory,bytes4[] memory,bytes4[] memory) { return (facetName(),facetInterfaces(),facetFuncs()); }
}
