// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC721Metadata} from "@crane/contracts/interfaces/IERC721Metadata.sol";

import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {ComposedStableCommonDetfBondNFTVaultTarget} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultTarget.sol";
import {IDetfFeeRecipientInventoryPolicy} from 'contracts/vaults/detf/inventory/IDetfFeeRecipientInventoryPolicy.sol';

contract ComposedStableCommonDetfBondNFTVaultFacet is ComposedStableCommonDetfBondNFTVaultTarget, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(ComposedStableCommonDetfBondNFTVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IProtocolNFTVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](26);
        funcs_[0] = IProtocolNFTVault.initializeProtocolNFT.selector;
        funcs_[1] = IProtocolNFTVault.createPosition.selector;
        funcs_[2] = IProtocolNFTVault.redeemPosition.selector;
        funcs_[3] = IProtocolNFTVault.claimRewards.selector;
        funcs_[4] = IProtocolNFTVault.addToProtocolNFT.selector;
        funcs_[5] = IProtocolNFTVault.sellPositionToProtocol.selector;
        funcs_[6] = IProtocolNFTVault.getPosition.selector;
        funcs_[7] = IProtocolNFTVault.pendingRewards.selector;
        funcs_[8] = IProtocolNFTVault.totalShares.selector;
        funcs_[9] = IProtocolNFTVault.protocolDETF.selector;
        funcs_[10] = IProtocolNFTVault.lpToken.selector;
        funcs_[11] = IProtocolNFTVault.rewardToken.selector;
        funcs_[12] = IProtocolNFTVault.protocolNFTId.selector;
        funcs_[13] = IProtocolNFTVault.positionOf.selector;
        funcs_[14] = IProtocolNFTVault.originalSharesOf.selector;
        funcs_[15] = IProtocolNFTVault.effectiveSharesOf.selector;
        funcs_[16] = IProtocolNFTVault.unlockTimeOf.selector;
        funcs_[17] = IProtocolNFTVault.isUnlocked.selector;
        funcs_[18] = IProtocolNFTVault.convertToShares.selector;
        funcs_[19] = IProtocolNFTVault.convertToAssets.selector;
        funcs_[20] = IProtocolNFTVault.markProtocolNFTSold.selector;
        funcs_[21] = IProtocolNFTVault.reallocateProtocolRewards.selector;
        funcs_[22] = IERC721Metadata.tokenURI.selector;
        funcs_[23] = IDetfFeeRecipientInventoryPolicy.feeRecipientNFTId.selector;
        funcs_[24] = IComposedStableCommonDetfBondNFTVault.deploymentTimestamp.selector;
        funcs_[25] = IDetfFeeRecipientInventoryPolicy.addToFeeRecipientNFT.selector;
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