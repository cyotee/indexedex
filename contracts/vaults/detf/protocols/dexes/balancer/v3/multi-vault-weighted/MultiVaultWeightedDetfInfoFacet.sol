// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    MultiVaultWeightedDetfInfoTarget,
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @title MultiVaultWeightedDetfInfoFacet
/// @notice Product info + compound surface (Option 1c size split).
contract MultiVaultWeightedDetfInfoFacet is IFacet, MultiVaultWeightedDetfInfoTarget {
    function facetName() external pure returns (string memory) {
        return "MultiVaultWeightedDetfInfoFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMultiVaultWeightedDetfInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](23);
        funcs_[0] = IMultiVaultWeightedDetfInfo.isReserveLive.selector;
        funcs_[1] = IMultiVaultWeightedDetfInfo.vaultCount.selector;
        funcs_[2] = IMultiVaultWeightedDetfInfo.underlyingVaults.selector;
        funcs_[3] = IMultiVaultWeightedDetfInfo.vaultShares.selector;
        funcs_[4] = IMultiVaultWeightedDetfInfo.weights.selector;
        funcs_[5] = IMultiVaultWeightedDetfInfo.rateProvider.selector;
        funcs_[6] = IMultiVaultWeightedDetfInfo.rateAsset.selector;
        funcs_[7] = IMultiVaultWeightedDetfInfo.rateAssets.selector;
        funcs_[8] = IMultiVaultWeightedDetfInfo.reservePool.selector;
        funcs_[9] = IMultiVaultWeightedDetfInfo.syntheticPrice.selector;
        funcs_[10] = IMultiVaultWeightedDetfInfo.mintThreshold.selector;
        funcs_[11] = IMultiVaultWeightedDetfInfo.burnThreshold.selector;
        funcs_[12] = IMultiVaultWeightedDetfInfo.thresholdMode.selector;
        funcs_[13] = IMultiVaultWeightedDetfInfo.isMintingAllowed.selector;
        funcs_[14] = IMultiVaultWeightedDetfInfo.isBurningAllowed.selector;
        funcs_[15] = IMultiVaultWeightedDetfInfo.bondNftVault.selector;
        funcs_[16] = IMultiVaultWeightedDetfInfo.rebasingClaimToken.selector;
        funcs_[17] = IMultiVaultWeightedDetfInfo.compoundProtocolRewards.selector;
        funcs_[18] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[19] = IMultiVaultWeightedDetfInfo.lastExpansionTimestamp.selector;
        funcs_[20] = IMultiVaultWeightedDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[21] = IMultiVaultWeightedDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[22] = IMultiVaultWeightedDetfInfo.expansionCatchUpCapBps.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MultiVaultWeightedDetfInfoFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMultiVaultWeightedDetfInfo).interfaceId;
        funcs_ = new bytes4[](23);
        funcs_[0] = IMultiVaultWeightedDetfInfo.isReserveLive.selector;
        funcs_[1] = IMultiVaultWeightedDetfInfo.vaultCount.selector;
        funcs_[2] = IMultiVaultWeightedDetfInfo.underlyingVaults.selector;
        funcs_[3] = IMultiVaultWeightedDetfInfo.vaultShares.selector;
        funcs_[4] = IMultiVaultWeightedDetfInfo.weights.selector;
        funcs_[5] = IMultiVaultWeightedDetfInfo.rateProvider.selector;
        funcs_[6] = IMultiVaultWeightedDetfInfo.rateAsset.selector;
        funcs_[7] = IMultiVaultWeightedDetfInfo.rateAssets.selector;
        funcs_[8] = IMultiVaultWeightedDetfInfo.reservePool.selector;
        funcs_[9] = IMultiVaultWeightedDetfInfo.syntheticPrice.selector;
        funcs_[10] = IMultiVaultWeightedDetfInfo.mintThreshold.selector;
        funcs_[11] = IMultiVaultWeightedDetfInfo.burnThreshold.selector;
        funcs_[12] = IMultiVaultWeightedDetfInfo.thresholdMode.selector;
        funcs_[13] = IMultiVaultWeightedDetfInfo.isMintingAllowed.selector;
        funcs_[14] = IMultiVaultWeightedDetfInfo.isBurningAllowed.selector;
        funcs_[15] = IMultiVaultWeightedDetfInfo.bondNftVault.selector;
        funcs_[16] = IMultiVaultWeightedDetfInfo.rebasingClaimToken.selector;
        funcs_[17] = IMultiVaultWeightedDetfInfo.compoundProtocolRewards.selector;
        funcs_[18] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[19] = IMultiVaultWeightedDetfInfo.lastExpansionTimestamp.selector;
        funcs_[20] = IMultiVaultWeightedDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[21] = IMultiVaultWeightedDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[22] = IMultiVaultWeightedDetfInfo.expansionCatchUpCapBps.selector;
    }
}
