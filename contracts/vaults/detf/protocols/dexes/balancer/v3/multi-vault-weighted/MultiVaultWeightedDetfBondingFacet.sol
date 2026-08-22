// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {
    MultiVaultWeightedDetfBondingTarget,
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";

/// @title MultiVaultWeightedDetfBondingFacet
/// @notice Bond / reserve / claim sell-redeem surface (Option 1c size split).
contract MultiVaultWeightedDetfBondingFacet is IFacet, MultiVaultWeightedDetfBondingTarget {
    function facetName() external pure returns (string memory) {
        return "MultiVaultWeightedDetfBondingFacet";
    }

    function facetInterfaces() external pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMultiVaultWeightedDetfBonding).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](16);
        funcs_[0] = IMultiVaultWeightedDetfBonding.bond.selector;
        funcs_[1] = IMultiVaultWeightedDetfBonding.initializeReserve.selector;
        funcs_[2] = IMultiVaultWeightedDetfBonding.sellPositionToDetfNft.selector;
        funcs_[3] = IMultiVaultWeightedDetfBonding.acceptedBondTokens.selector;
        funcs_[4] = IMultiVaultWeightedDetfBonding.redeemClaim.selector;
        funcs_[5] = IMultiVaultWeightedDetfBonding.buyClaim.selector;
        funcs_[6] = IMultiVaultWeightedDetfBonding.previewBuyClaim.selector;
        funcs_[7] = IMultiVaultWeightedDetfBonding.closeBondMature.selector;
        funcs_[8] = IMultiVaultWeightedDetfBonding.previewCloseBondMature.selector;
        funcs_[9] = IMultiVaultWeightedDetfBonding.previewRedeemClaim.selector;
        funcs_[10] = IMultiVaultWeightedDetfBonding.claimLiquidity.selector;
        funcs_[11] = IMultiVaultWeightedDetfBonding.protocolBondOriginalShares.selector;
        funcs_[12] = IMultiVaultWeightedDetfBonding.joinDonatedCapital.selector;
        funcs_[13] = IMultiVaultWeightedDetfBonding.previewJoinDonatedCapital.selector;
        funcs_[14] = IMultiVaultWeightedDetfBonding.notifyReserveDonated.selector;
        funcs_[15] = IMultiVaultWeightedDetfBonding.donate.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces_, bytes4[] memory funcs_)
    {
        name_ = "MultiVaultWeightedDetfBondingFacet";
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IMultiVaultWeightedDetfBonding).interfaceId;
        funcs_ = facetFuncs();
    }
}
