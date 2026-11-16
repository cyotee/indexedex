// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MultiVaultWeightedDetfExchangeQueryTarget} from "./MultiVaultWeightedDetfExchangeQueryTarget.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {DETFBalancerReserveSwapTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapTarget.sol";

/// @notice Assembled funded DETF surface; function lists share one canonical implementation.
contract MultiVaultWeightedDetfExchangeInFacet is IFacet, MultiVaultWeightedDetfExchangeQueryTarget {
    function facetName() public pure returns (string memory) { return type(MultiVaultWeightedDetfExchangeInFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](2);
        interfaces_[0] = type(IStandardExchangeIn).interfaceId;
        interfaces_[1] = type(IStandardExchangeOut).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](5);
        selectors_[0] = IStandardExchangeIn.exchangeIn.selector;
        selectors_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        selectors_[2] = IStandardExchangeOut.exchangeOut.selector;
        selectors_[3] = IStandardExchangeOut.previewExchangeOut.selector;
        selectors_[4] = DETFBalancerReserveSwapTarget.executeReserveSwap.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
