// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IComposedStableCommonDetfInfo} from "./IComposedStableCommonDetfInfo.sol";
import {RebasingDETFTokenPricingTarget} from "./RebasingDETFTokenPricingTarget.sol";
contract RebasingDETFTokenPricingFacet is RebasingDETFTokenPricingTarget, IFacet {
    function facetName() public pure returns (string memory) { return type(RebasingDETFTokenPricingFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](1);
        a_[0] = type(IComposedStableCommonDetfInfo).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory a_) {
        a_ = new bytes4[](25);
        a_[0] = this.reservePool.selector;
        a_[1] = this.bondNftVault.selector;
        a_[2] = this.rebasingClaimToken.selector;
        a_[3] = this.syntheticDetfEthPrice.selector;
        a_[4] = this.previewStablePoolBptEthValue.selector;
        a_[5] = this.previewCommonPoolBptEthValue.selector;
        a_[6] = this.previewReservePoolDecomposition.selector;
        a_[7] = this.mintThreshold.selector;
        a_[8] = this.burnThreshold.selector;
        a_[9] = this.isMintingAllowed.selector;
        a_[10] = this.isBurningAllowed.selector;
        a_[11] = this.isReserveLive.selector;
        a_[12] = this.epochAnchor.selector;
        a_[13] = this.lastExpansionTimestamp.selector;
        a_[14] = this.expansionClosureRatePerSecond.selector;
        a_[15] = this.pendingExpansionDetf.selector;
        a_[16] = this.rawSY.selector;
        a_[17] = this.stakingSY.selector;
        a_[18] = this.tokensIn.selector;
        a_[19] = this.tokensOut.selector;
        a_[20] = this.synchronizeRewards.selector;
        a_[21] = this.previewStakingGonsPerUnit.selector;
        a_[22] = this.previewExchangeIn.selector;
        a_[23] = this.previewJoinDonatedCapital.selector;
        a_[24] = this.openingConfiguration.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
