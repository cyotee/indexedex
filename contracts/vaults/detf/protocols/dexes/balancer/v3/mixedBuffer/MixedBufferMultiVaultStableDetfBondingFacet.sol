// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    MixedBufferMultiVaultStableDetfBondingTarget,
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";

/// @title MixedBufferMultiVaultStableDetfBondingFacet
/// @notice Bond / bootstrap / claim sell-redeem surface (Option 1c size split).
contract MixedBufferMultiVaultStableDetfBondingFacet is IFacet, MixedBufferMultiVaultStableDetfBondingTarget {
    function facetName() external pure returns (string memory) {
        return "MixedBufferMultiVaultStableDetfBondingFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](16);
        funcs_[0] = IMixedBufferMultiVaultStableDetfBonding.bootstrapFirstBond.selector;
        funcs_[1] = IMixedBufferMultiVaultStableDetfBonding.bond.selector;
        funcs_[2] = IMixedBufferMultiVaultStableDetfBonding.sellPositionToDetfNft.selector;
        funcs_[3] = IMixedBufferMultiVaultStableDetfBonding.acceptedBondTokens.selector;
        funcs_[4] = IMixedBufferMultiVaultStableDetfBonding.redeemClaim.selector;
        funcs_[5] = IMixedBufferMultiVaultStableDetfBonding.buyClaim.selector;
        funcs_[6] = IMixedBufferMultiVaultStableDetfBonding.previewBuyClaim.selector;
        funcs_[7] = IMixedBufferMultiVaultStableDetfBonding.closeBondMature.selector;
        funcs_[8] = IMixedBufferMultiVaultStableDetfBonding.previewCloseBondMature.selector;
        funcs_[9] = IMixedBufferMultiVaultStableDetfBonding.previewRedeemClaim.selector;
        funcs_[10] = IMixedBufferMultiVaultStableDetfBonding.claimLiquidity.selector;
        funcs_[11] = IMixedBufferMultiVaultStableDetfBonding.protocolBondOriginalShares.selector;
        funcs_[12] = IMixedBufferMultiVaultStableDetfBonding.joinDonatedCapital.selector;
        funcs_[13] = IMixedBufferMultiVaultStableDetfBonding.previewJoinDonatedCapital.selector;
        funcs_[14] = IMixedBufferMultiVaultStableDetfBonding.notifyReserveDonated.selector;
        funcs_[15] = IMixedBufferMultiVaultStableDetfBonding.donate.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MixedBufferMultiVaultStableDetfBondingFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMixedBufferMultiVaultStableDetfBonding).interfaceId;
        funcs_ = facetFuncs();
    }
}
