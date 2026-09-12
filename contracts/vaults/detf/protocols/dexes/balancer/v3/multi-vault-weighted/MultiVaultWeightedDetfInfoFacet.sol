// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MultiVaultWeightedDetfInfoTarget, IMultiVaultWeightedDetfInfo} from "./MultiVaultWeightedDetfInfoTarget.sol";
import {IMultiVaultWeightedDetfBonding} from "./MultiVaultWeightedDetfBondingTarget.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";

/// @notice Assembled funded DETF surface; function lists share one canonical implementation.
contract MultiVaultWeightedDetfInfoFacet is IFacet, MultiVaultWeightedDetfInfoTarget {
    function facetName() public pure returns (string memory) { return type(MultiVaultWeightedDetfInfoFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](4);
        interfaces_[0] = type(IMultiVaultWeightedDetfInfo).interfaceId;
        interfaces_[1] = type(IDETFFundedRewards).interfaceId;
        interfaces_[2] = type(IDETFStandardizedYield).interfaceId;
        interfaces_[3] = type(IDETFStakingPreview).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](25);
        selectors_[0] = IMultiVaultWeightedDetfInfo.isReserveLive.selector;
        selectors_[1] = IMultiVaultWeightedDetfInfo.vaultCount.selector;
        selectors_[2] = IMultiVaultWeightedDetfInfo.underlyingVaults.selector;
        selectors_[3] = IMultiVaultWeightedDetfInfo.vaultShares.selector;
        selectors_[4] = IMultiVaultWeightedDetfInfo.weights.selector;
        selectors_[5] = IMultiVaultWeightedDetfInfo.rateProvider.selector;
        selectors_[6] = IMultiVaultWeightedDetfInfo.rateAsset.selector;
        selectors_[7] = IMultiVaultWeightedDetfInfo.rateAssets.selector;
        selectors_[8] = IMultiVaultWeightedDetfInfo.reservePool.selector;
        selectors_[9] = IMultiVaultWeightedDetfInfo.syntheticPrice.selector;
        selectors_[10] = IMultiVaultWeightedDetfInfo.mintThreshold.selector;
        selectors_[11] = IMultiVaultWeightedDetfInfo.burnThreshold.selector;
        selectors_[12] = IMultiVaultWeightedDetfInfo.isMintingAllowed.selector;
        selectors_[13] = IMultiVaultWeightedDetfInfo.isBurningAllowed.selector;
        selectors_[14] = IMultiVaultWeightedDetfInfo.bondNftVault.selector;
        selectors_[15] = IMultiVaultWeightedDetfInfo.rebasingClaimToken.selector;
        selectors_[16] = IMultiVaultWeightedDetfInfo.lastExpansionTimestamp.selector;
        selectors_[17] = IMultiVaultWeightedDetfInfo.epochAnchor.selector;
        selectors_[18] = IMultiVaultWeightedDetfInfo.expansionClosureRatePerSecond.selector;
        selectors_[19] = IMultiVaultWeightedDetfInfo.pendingExpansionDetf.selector;
        selectors_[20] = IDETFFundedRewards.synchronizeRewards.selector;
        selectors_[21] = IDETFStandardizedYield.rawSY.selector;
        selectors_[22] = IDETFStandardizedYield.stakingSY.selector;
        selectors_[23] = IDETFStakingPreview.previewStakingGonsPerUnit.selector;
        selectors_[24] = IMultiVaultWeightedDetfBonding.previewJoinDonatedCapital.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
