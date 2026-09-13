// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MultiVaultWeightedDetfBondingTarget} from "./MultiVaultWeightedDetfBondingTarget.sol";
import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";


/// @notice Assembled funded DETF surface; function lists share one canonical implementation.
contract MultiVaultWeightedDetfBondingFacet is IFacet, MultiVaultWeightedDetfBondingTarget {
    function facetName() public pure returns (string memory) { return type(MultiVaultWeightedDetfBondingFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMultiVaultWeightedDetfBonding).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](8);
        selectors_[0] = IMultiVaultWeightedDetfBonding.bond.selector;
        selectors_[1] = IMultiVaultWeightedDetfBonding.initializeReserve.selector;
        selectors_[2] = IMultiVaultWeightedDetfBonding.previewBond.selector;
        selectors_[3] = IMultiVaultWeightedDetfBonding.previewInitializeReserve.selector;
        selectors_[4] = IMultiVaultWeightedDetfBonding.acceptedBondTokens.selector;
        selectors_[5] = IMultiVaultWeightedDetfBonding.joinDonatedCapital.selector;
        selectors_[6] = IMultiVaultWeightedDetfBonding.notifyReserveDonated.selector;
        selectors_[7] = IMultiVaultWeightedDetfBonding.donate.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
