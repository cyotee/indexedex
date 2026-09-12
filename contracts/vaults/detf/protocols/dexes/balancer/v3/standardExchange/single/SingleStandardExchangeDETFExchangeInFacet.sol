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

contract SingleStandardExchangeDETFExchangeInFacet is IFacet,
    SingleStandardExchangeDETFExchangeInTarget
{
    function facetName() public pure returns (string memory) { return type(SingleStandardExchangeDETFExchangeInFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(IStandardExchangeIn).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](3);
        selectors_[0] = IStandardExchangeIn.exchangeIn.selector;
        selectors_[1] = DETFBalancerReserveSwapTarget.executeReserveSwap.selector;
        selectors_[2] = ISingleStandardExchangeDETFBonding.previewJoinDonatedCapital.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
