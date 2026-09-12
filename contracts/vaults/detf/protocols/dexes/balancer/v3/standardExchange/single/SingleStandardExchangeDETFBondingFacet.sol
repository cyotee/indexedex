// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {DETFBalancerReserveSwapTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapTarget.sol";
import {SingleStandardExchangeDETFExchangeInTarget} from "./SingleStandardExchangeDETFExchangeInTarget.sol";
import {SingleStandardExchangeDETFExchangeInQueryTarget} from "./SingleStandardExchangeDETFExchangeInQueryTarget.sol";
import {SingleStandardExchangeDETFBondingTarget, ISingleStandardExchangeDETFBonding} from "./SingleStandardExchangeDETFBondingTarget.sol";
import {SingleStandardExchangeDETFInfoTarget, ISingleStandardExchangeDETFInfo} from "./SingleStandardExchangeDETFInfoTarget.sol";

contract SingleStandardExchangeDETFBondingFacet is IFacet,
    SingleStandardExchangeDETFExchangeInQueryTarget,
    SingleStandardExchangeDETFBondingTarget, SingleStandardExchangeDETFInfoTarget
{
    function facetName() public pure returns (string memory) { return type(SingleStandardExchangeDETFBondingFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](6);
        ids_[0] = type(IStandardExchangeIn).interfaceId;
        ids_[1] = type(ISingleStandardExchangeDETFBonding).interfaceId;
        ids_[2] = type(ISingleStandardExchangeDETFInfo).interfaceId;
        ids_[3] = type(IDETFFundedRewards).interfaceId;
        ids_[4] = type(IDETFStandardizedYield).interfaceId;
        ids_[5] = type(IDETFStakingPreview).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](27);
        selectors_[0] = IStandardExchangeIn.previewExchangeIn.selector;
        selectors_[1] = ISingleStandardExchangeDETFBonding.bond.selector;
        selectors_[2] = ISingleStandardExchangeDETFBonding.previewBond.selector;
        selectors_[3] = ISingleStandardExchangeDETFBonding.acceptedBondTokens.selector;
        selectors_[4] = ISingleStandardExchangeDETFBonding.joinDonatedCapital.selector;
        selectors_[5] = ISingleStandardExchangeDETFBonding.notifyReserveDonated.selector;
        selectors_[6] = ISingleStandardExchangeDETFBonding.donate.selector;
        selectors_[7] = ISingleStandardExchangeDETFInfo.isReserveLive.selector;
        selectors_[8] = ISingleStandardExchangeDETFInfo.standardExchangeVault.selector;
        selectors_[9] = ISingleStandardExchangeDETFInfo.standardExchangeVaultShare.selector;
        selectors_[10] = ISingleStandardExchangeDETFInfo.rateTarget.selector;
        selectors_[11] = ISingleStandardExchangeDETFInfo.reservePool.selector;
        selectors_[12] = ISingleStandardExchangeDETFInfo.syntheticPrice.selector;
        selectors_[13] = ISingleStandardExchangeDETFInfo.mintThreshold.selector;
        selectors_[14] = ISingleStandardExchangeDETFInfo.burnThreshold.selector;
        selectors_[15] = ISingleStandardExchangeDETFInfo.isMintingAllowed.selector;
        selectors_[16] = ISingleStandardExchangeDETFInfo.isBurningAllowed.selector;
        selectors_[17] = ISingleStandardExchangeDETFInfo.bondNftVault.selector;
        selectors_[18] = ISingleStandardExchangeDETFInfo.rebasingClaimToken.selector;
        selectors_[19] = ISingleStandardExchangeDETFInfo.lastExpansionTimestamp.selector;
        selectors_[20] = ISingleStandardExchangeDETFInfo.epochAnchor.selector;
        selectors_[21] = ISingleStandardExchangeDETFInfo.expansionClosureRatePerSecond.selector;
        selectors_[22] = ISingleStandardExchangeDETFInfo.pendingExpansionDetf.selector;
        selectors_[23] = IDETFFundedRewards.synchronizeRewards.selector;
        selectors_[24] = IDETFStandardizedYield.rawSY.selector;
        selectors_[25] = IDETFStandardizedYield.stakingSY.selector;
        selectors_[26] = IDETFStakingPreview.previewStakingGonsPerUnit.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
