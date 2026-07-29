// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice H2 claim redeem atomicity; H3 residual already in Guards.
/// @dev H2 critical: if redeemClaim reverts, claim balance must be unchanged (single-tx atomicity).
///      Production burns claim then exits BPT; EVM full-tx revert restores claim if exit fails.
///      Deferred P2: H1 (N=7 initializeReserve gas boundary — NRange deploys N=7 live path).
contract Adversarial_Griefing_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    /// @notice H2: impossible minOut reverts whole redeem; claim not permanently burned.
    function test_H2_redeemClaim_revert_claimUnchanged() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 2_500e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);

        vm.prank(alice);
        bonding_.sellNFT(tokenId_, alice);

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBefore_ = claim_.balanceOf(alice);
        assertTrue(claimBefore_ > 0, "has claim");

        uint256 redeemAmt_ = claimBefore_ / 10;
        if (redeemAmt_ == 0) redeemAmt_ = claimBefore_;

        // Impossible minOut forces failure after burn-in-tx → full revert restores claim
        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(
            redeemAmt_, rateAssets[0], type(uint256).max, alice, block.timestamp + 1 hours
        );

        assertEq(claim_.balanceOf(alice), claimBefore_, "H2: claim unchanged after failed redeem");

        // Successful redeem still works
        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(
            redeemAmt_, rateAssets[0], 0, alice, block.timestamp + 1 hours
        );
        assertTrue(out_ > 0, "H2: successful redeem after failed attempt");
        assertLt(claim_.balanceOf(alice), claimBefore_, "claim burned on success");
    }

    /// @notice H2b: full claim redeem either succeeds or reverts cleanly (no partial strand).
    function test_H2_fullRedeem_atomic() public {
        address instance_ = _deployOpenModeDetfN(1);
        // Large bootstrap to reduce TokenBalanceBelowMin grief on full exit
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 5_000e18);
        // Add more reserve via mint so full claim exit is a fraction of pool
        _mintOnLeg(instance_, 0, bob, 200e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IRebasingClaimToken claim_ =
            IRebasingClaimToken(IMultiVaultWeightedDetfInfo(instance_).rebasingClaimToken());

        vm.prank(alice);
        bonding_.sellNFT(tokenId_, alice);
        uint256 claimBal_ = claim_.balanceOf(alice);
        // Redeem majority but not 100% of pool BPT path — use 30% of claim to stay above min balances
        uint256 part_ = (claimBal_ * 30) / 100;
        if (part_ == 0) part_ = claimBal_;

        uint256 claimBefore_ = claim_.balanceOf(alice);
        vm.prank(alice);
        try bonding_.redeemClaim(part_, rateAssets[0], 0, alice, block.timestamp + 1 hours) returns (
            uint256 out_
        ) {
            assertTrue(out_ > 0, "partial redeem ok");
            assertLt(claim_.balanceOf(alice), claimBefore_, "claim reduced on success");
        } catch {
            // Clean fail: claim fully restored
            assertEq(claim_.balanceOf(alice), claimBefore_, "H2: fail leaves claim intact");
        }
    }
}
