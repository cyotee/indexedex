// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    MixedBufferMultiVaultStableDetfInfoTarget,
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @title MixedBufferMultiVaultStableDetfInfoFacet
/// @notice Product info + compound surface (Option 1c size split).
contract MixedBufferMultiVaultStableDetfInfoFacet is IFacet, MixedBufferMultiVaultStableDetfInfoTarget {
    function facetName() external pure returns (string memory) {
        return "MixedBufferMultiVaultStableDetfInfoFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](25);
        funcs_[0] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        funcs_[1] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        funcs_[2] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        funcs_[3] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        funcs_[4] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        funcs_[5] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        funcs_[6] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        funcs_[7] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        funcs_[8] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        funcs_[9] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        funcs_[10] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        funcs_[11] = IMixedBufferMultiVaultStableDetfInfo.thresholdMode.selector;
        funcs_[12] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        funcs_[13] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        funcs_[14] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        funcs_[15] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        funcs_[16] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        funcs_[17] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        funcs_[18] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
        funcs_[19] = IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector;
        funcs_[20] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[21] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        funcs_[22] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[23] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[24] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpCapBps.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MixedBufferMultiVaultStableDetfInfoFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
        funcs_ = new bytes4[](25);
        funcs_[0] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        funcs_[1] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        funcs_[2] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        funcs_[3] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        funcs_[4] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        funcs_[5] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        funcs_[6] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        funcs_[7] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        funcs_[8] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        funcs_[9] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        funcs_[10] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        funcs_[11] = IMixedBufferMultiVaultStableDetfInfo.thresholdMode.selector;
        funcs_[12] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        funcs_[13] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        funcs_[14] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        funcs_[15] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        funcs_[16] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        funcs_[17] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        funcs_[18] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
        funcs_[19] = IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector;
        funcs_[20] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[21] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        funcs_[22] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[23] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[24] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpCapBps.selector;
    }
}
