// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {MixedBufferMultiVaultStableDetfBondingTarget, IMixedBufferMultiVaultStableDetfBonding} from "./MixedBufferMultiVaultStableDetfBondingTarget.sol";


/// @notice Assembled funded DETF surface; function lists share one canonical implementation.
contract MixedBufferMultiVaultStableDetfBondingFacet is IFacet, MixedBufferMultiVaultStableDetfBondingTarget {
    function facetName() public pure returns (string memory) { return type(MixedBufferMultiVaultStableDetfBondingFacet).name; }
    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](9);
        selectors_[0] = IMixedBufferMultiVaultStableDetfBonding.bond.selector;
        selectors_[1] = IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector;
        selectors_[2] = IMixedBufferMultiVaultStableDetfBonding.previewBond.selector;
        selectors_[3] = IMixedBufferMultiVaultStableDetfBonding.previewBootstrapFirstBond.selector;
        selectors_[4] = IMixedBufferMultiVaultStableDetfBonding.acceptedBondTokens.selector;
        selectors_[5] = IMixedBufferMultiVaultStableDetfBonding.joinDonatedCapital.selector;
        selectors_[6] = IMixedBufferMultiVaultStableDetfBonding.previewJoinDonatedCapital.selector;
        selectors_[7] = IMixedBufferMultiVaultStableDetfBonding.notifyReserveDonated.selector;
        selectors_[8] = IMixedBufferMultiVaultStableDetfBonding.donate.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}
