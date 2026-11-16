// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";

import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ComposedStableCommonDetfBondNFTVaultTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol";
import {IDetfFeeRecipientInventoryPolicy} from 'contracts/vaults/detf/common/inventory/IDetfFeeRecipientInventoryPolicy.sol';

contract ComposedStableCommonDetfBondNFTVaultFacet is ComposedStableCommonDetfBondNFTVaultTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(ComposedStableCommonDetfBondNFTVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IDETFNFTVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](35);
        funcs_[0] = IDETFNFTVault.initializeDETFNFT.selector;
        funcs_[1] = IDETFNFTVault.createPosition.selector;
        funcs_[2] = IDETFNFTVault.createPositionWithEffectiveBase.selector;
        funcs_[3] = IDETFNFTVault.redeemPosition.selector;
        funcs_[4] = IDETFNFTVault.claimRewards.selector;
        funcs_[5] = IDETFNFTVault.addToDETFNFT.selector;
        funcs_[6] = IDETFNFTVault.sellPositionToDetfNft.selector;
        funcs_[7] = IDETFNFTVault.getPosition.selector;
        funcs_[8] = IDETFNFTVault.pendingRewards.selector;
        funcs_[9] = IDETFNFTVault.totalShares.selector;
        funcs_[10] = IDETFNFTVault.detf.selector;
        funcs_[11] = IDETFNFTVault.lpToken.selector;
        funcs_[12] = IDETFNFTVault.rewardToken.selector;
        funcs_[13] = IDETFNFTVault.detfNFTId.selector;
        funcs_[14] = IDETFNFTVault.positionOf.selector;
        funcs_[15] = IDETFNFTVault.originalSharesOf.selector;
        funcs_[16] = IDETFNFTVault.effectiveSharesOf.selector;
        funcs_[17] = IDETFNFTVault.unlockTimeOf.selector;
        funcs_[18] = IDETFNFTVault.isUnlocked.selector;
        funcs_[19] = IDETFNFTVault.convertToShares.selector;
        funcs_[20] = IDETFNFTVault.convertToAssets.selector;
        funcs_[21] = IDETFNFTVault.reallocateDetfNftRewards.selector;
        funcs_[22] = IERC721Metadata.tokenURI.selector;
        funcs_[23] = IDetfFeeRecipientInventoryPolicy.feeRecipientNFTId.selector;
        funcs_[24] = IComposedStableCommonDetfBondNFTVault.deploymentTimestamp.selector;
        funcs_[25] = IDetfFeeRecipientInventoryPolicy.addToFeeRecipientNFT.selector;
        funcs_[26] = IDETFNFTVault.transferHeldToken.selector;
        funcs_[27] = IDETFNFTVault.lockInfoOf.selector;
        funcs_[28] = IDETFNFTVault.rewardPerShares.selector;
        funcs_[29] = IDETFNFTVault.removeFromDETFNFT.selector;
        funcs_[30] = IDETFNFTVault.totalOriginalShares.selector;
        funcs_[31] = IDETFNFTVault.initializeReservedBondNfts.selector;
        funcs_[32] = IDETFNFTVault.reservedBondNftsWired.selector;
        funcs_[33] = IDETFNFTVault.addEffectiveSharesOnly.selector;
        funcs_[34] = IDETFNFTVault.retireMaturePosition.selector;
    }

    function facetMetadata()
        public
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }
}