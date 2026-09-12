// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";

/// @title DETFNFTVaultFacet
/// @notice Common funded bond lifecycle, custody, donations and registry metadata.
contract DETFNFTVaultFacet is DETFFundedBondTarget, IFacet {
    /// @inheritdoc IFacet
    function facetName() public pure virtual returns (string memory) { return type(DETFNFTVaultFacet).name; }

    /// @inheritdoc IFacet
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IDetfBondNFT).interfaceId;
        interfaces_[1] = type(IStandardVault).interfaceId;
        interfaces_[2] = type(IDetfNftReserveDonation).interfaceId;
    }

    /// @inheritdoc IFacet
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](20);
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
    }

    /// @inheritdoc IFacet
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
