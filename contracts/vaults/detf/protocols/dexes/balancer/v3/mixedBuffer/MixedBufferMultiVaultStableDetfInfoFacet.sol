// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MixedBufferMultiVaultStableDetfInfoTarget, IMixedBufferMultiVaultStableDetfInfo} from "./MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";

/// @notice Assembled funded DETF surface; function lists share one canonical implementation.
contract MixedBufferMultiVaultStableDetfInfoFacet is IFacet, MixedBufferMultiVaultStableDetfInfoTarget {
    function facetName() public pure returns (string memory) { return type(MixedBufferMultiVaultStableDetfInfoFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](4);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
        interfaces_[1] = type(IDETFFundedRewards).interfaceId;
        interfaces_[2] = type(IDETFStandardizedYield).interfaceId;
        interfaces_[3] = type(IDETFStakingPreview).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](26);
        selectors_[0] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        selectors_[1] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        selectors_[2] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        selectors_[3] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        selectors_[4] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        selectors_[5] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        selectors_[6] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        selectors_[7] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        selectors_[8] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        selectors_[9] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        selectors_[10] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        selectors_[11] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        selectors_[12] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        selectors_[13] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        selectors_[14] = IMixedBufferMultiVaultStableDetfInfo.epochAnchor.selector;
        selectors_[15] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        selectors_[16] = IMixedBufferMultiVaultStableDetfInfo.pendingExpansionDetf.selector;
        selectors_[17] = IDETFFundedRewards.synchronizeRewards.selector;
        selectors_[18] = IDETFStandardizedYield.rawSY.selector;
        selectors_[19] = IDETFStandardizedYield.stakingSY.selector;
        selectors_[20] = IDETFStakingPreview.previewStakingGonsPerUnit.selector;
        selectors_[21] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        selectors_[22] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        selectors_[23] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        selectors_[24] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        selectors_[25] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
