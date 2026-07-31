// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    MixedBufferMultiVaultStableDetfExchangeQueryTarget
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol";
import {
    MixedBufferMultiVaultStableDetfBondingTarget,
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    MixedBufferMultiVaultStableDetfInfoTarget,
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

/// @dev Combined facet for exchange/bond/info/query (split later if size requires).
contract MixedBufferMultiVaultStableDetfExchangeInFacet is
    IFacet,
    MixedBufferMultiVaultStableDetfExchangeQueryTarget,
    MixedBufferMultiVaultStableDetfBondingTarget,
    MixedBufferMultiVaultStableDetfInfoTarget
{
    function facetName() external pure returns (string memory) {
        return "MixedBufferMultiVaultStableDetfExchangeInFacet";
    }

    function facetInterfaces() external pure override returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
        interfaces_[2] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
    }

    function facetFuncs() external pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](35);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
        funcs_[4] = IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector;
        funcs_[5] = IMixedBufferMultiVaultStableDetfBonding.bond.selector;
        funcs_[6] = IMixedBufferMultiVaultStableDetfBonding.sellPositionToDetfNft.selector;
        funcs_[7] = IMixedBufferMultiVaultStableDetfBonding.sellNFT.selector;
        funcs_[8] = IMixedBufferMultiVaultStableDetfBonding.acceptedBondTokens.selector;
        funcs_[9] = IMixedBufferMultiVaultStableDetfBonding.redeemClaim.selector;
        funcs_[10] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        funcs_[11] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        funcs_[12] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        funcs_[13] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        funcs_[14] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        funcs_[15] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        funcs_[16] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        funcs_[17] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        funcs_[18] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        funcs_[19] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        funcs_[20] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        funcs_[21] = IMixedBufferMultiVaultStableDetfInfo.thresholdMode.selector;
        funcs_[22] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        funcs_[23] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        funcs_[24] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        funcs_[25] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        funcs_[26] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        funcs_[27] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        funcs_[28] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
        funcs_[29] = IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector;
        funcs_[30] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[31] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        funcs_[32] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[33] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[34] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpCapBps.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MixedBufferMultiVaultStableDetfExchangeInFacet";
        interfaces_ = new bytes4[](3);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
        interfaces_[2] = type(IMixedBufferMultiVaultStableDetfInfo).interfaceId;
        funcs_ = new bytes4[](35);
        funcs_[0] = IStandardExchangeIn.exchangeIn.selector;
        funcs_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        funcs_[2] = bytes4(keccak256("previewExchangeOut(address,address,uint256)"));
        funcs_[3] = bytes4(keccak256("exchangeOut(address,address,uint256,uint256,address,bool,uint256)"));
        funcs_[4] = IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector;
        funcs_[5] = IMixedBufferMultiVaultStableDetfBonding.bond.selector;
        funcs_[6] = IMixedBufferMultiVaultStableDetfBonding.sellPositionToDetfNft.selector;
        funcs_[7] = IMixedBufferMultiVaultStableDetfBonding.sellNFT.selector;
        funcs_[8] = IMixedBufferMultiVaultStableDetfBonding.acceptedBondTokens.selector;
        funcs_[9] = IMixedBufferMultiVaultStableDetfBonding.redeemClaim.selector;
        funcs_[10] = IMixedBufferMultiVaultStableDetfInfo.isReserveLive.selector;
        funcs_[11] = IMixedBufferMultiVaultStableDetfInfo.vaultCount.selector;
        funcs_[12] = IMixedBufferMultiVaultStableDetfInfo.underlyingVaults.selector;
        funcs_[13] = IMixedBufferMultiVaultStableDetfInfo.vaultShares.selector;
        funcs_[14] = IMixedBufferMultiVaultStableDetfInfo.bufferToken.selector;
        funcs_[15] = IMixedBufferMultiVaultStableDetfInfo.amplificationParameter.selector;
        funcs_[16] = IMixedBufferMultiVaultStableDetfInfo.rateProvider.selector;
        funcs_[17] = IMixedBufferMultiVaultStableDetfInfo.reservePool.selector;
        funcs_[18] = IMixedBufferMultiVaultStableDetfInfo.syntheticPrice.selector;
        funcs_[19] = IMixedBufferMultiVaultStableDetfInfo.mintThreshold.selector;
        funcs_[20] = IMixedBufferMultiVaultStableDetfInfo.burnThreshold.selector;
        funcs_[21] = IMixedBufferMultiVaultStableDetfInfo.thresholdMode.selector;
        funcs_[22] = IMixedBufferMultiVaultStableDetfInfo.isMintingAllowed.selector;
        funcs_[23] = IMixedBufferMultiVaultStableDetfInfo.isBurningAllowed.selector;
        funcs_[24] = IMixedBufferMultiVaultStableDetfInfo.bondNftVault.selector;
        funcs_[25] = IMixedBufferMultiVaultStableDetfInfo.rebasingClaimToken.selector;
        funcs_[26] = IMixedBufferMultiVaultStableDetfInfo.detfIndex.selector;
        funcs_[27] = IMixedBufferMultiVaultStableDetfInfo.bufferIndex.selector;
        funcs_[28] = IMixedBufferMultiVaultStableDetfInfo.shareIndex.selector;
        funcs_[29] = IMixedBufferMultiVaultStableDetfInfo.compoundProtocolRewards.selector;
        funcs_[30] = bytes4(keccak256("compoundProtocolRewardsAtomic()"));
        funcs_[31] = IMixedBufferMultiVaultStableDetfInfo.lastExpansionTimestamp.selector;
        funcs_[32] = IMixedBufferMultiVaultStableDetfInfo.expansionClosureRatePerSecond.selector;
        funcs_[33] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpMaxSeconds.selector;
        funcs_[34] = IMixedBufferMultiVaultStableDetfInfo.expansionCatchUpCapBps.selector;
    }
}
