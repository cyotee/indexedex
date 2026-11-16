// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./IUniswapV4DetfMigrationBondNFTVault.sol";
import {UniswapV4DetfMigrationBondNFTVaultTarget} from "./UniswapV4DetfMigrationBondNFTVaultTarget.sol";

/// @notice Migration lifecycle selectors; package separately replaces three ERC721 transfers.
contract UniswapV4DetfMigrationBondNFTVaultFacet is UniswapV4DetfMigrationBondNFTVaultTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure returns (string memory) {
        return type(UniswapV4DetfMigrationBondNFTVaultFacet).name;
    }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](5);
        ids_[0] = type(IDetfBondNFT).interfaceId;
        ids_[1] = type(IStandardVault).interfaceId;
        ids_[2] = type(IDetfNftReserveDonation).interfaceId;
        ids_[3] = type(IUniswapV4DetfMigrationBondNFTVault).interfaceId;
        ids_[4] = type(IUniswapV4DetfMigrationAccounting).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](24);
        funcs_[0] = IDetfBondNFT.detf.selector;
        funcs_[1] = IDetfBondNFT.lpToken.selector;
        funcs_[2] = IDetfBondNFT.initializeReservedBondNfts.selector;
        funcs_[3] = IDetfBondNFT.reservedBondNftsWired.selector;
        funcs_[4] = IDetfBondNFT.createFundedPosition.selector;
        funcs_[5] = IDetfBondNFT.positionOf.selector;
        funcs_[6] = IDetfBondNFT.previewClaim.selector;
        funcs_[7] = IDetfBondNFT.claimPrincipal.selector;
        funcs_[8] = IDetfBondNFT.claimRewards.selector;
        funcs_[9] = IDetfBondNFT.claimBond.selector;
        funcs_[10] = IDetfBondNFT.transferHeldToken.selector;
        funcs_[11] = IStandardVault.vaultFeeTypeIds.selector;
        funcs_[12] = IStandardVault.contentsId.selector;
        funcs_[13] = IStandardVault.vaultTypes.selector;
        funcs_[14] = IStandardVault.vaultConfig.selector;
        funcs_[15] = bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)"));
        funcs_[16] = bytes4(keccak256("donate(address,address,uint256,uint256,bool,uint256)"));
        funcs_[17] = IDetfNftReserveDonation.donateWithPermit2Allowance.selector;
        funcs_[18] = IDetfNftReserveDonation.donateWithPermit2Signature.selector;
        funcs_[19] = IDetfNftReserveDonation.previewDonate.selector;
        funcs_[20] = IUniswapV4DetfMigrationBondNFTVault.createMigrationPosition.selector;
        funcs_[21] = IUniswapV4DetfMigrationBondNFTVault.isMigrationPosition.selector;
        funcs_[22] = IUniswapV4DetfMigrationBondNFTVault.attributedBondGons.selector;
        funcs_[23] = IUniswapV4DetfMigrationAccounting.migrationAccountingPhase.selector;
    }

    /// @inheritdoc IFacet
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
