// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @notice Real claim path: sellNFT mints claim; redeemClaim pays configured rateAsset from BPT unwind.
contract MultiVaultWeightedDetf_Claim_Test is TestBase_MultiVaultWeightedDetf {
    function test_claimToken_wiredOnDeploy() public view {
        address claim_ = detfInfo.rebasingClaimToken();
        assertTrue(claim_ != address(0), "claim token wired");
        assertEq(IRebasingClaimToken(claim_).protocolDETF(), detf, "claim points at detf");
    }

    function test_sellNFT_mintsClaim_thenRedeemToRateAsset() public {
        (uint256 tokenId_, uint256 bptPrincipal_) = _goLiveViaBptBond(detf, alice, 1_500e18);
        assertTrue(bptPrincipal_ > 0, "bpt principal");

        IRebasingClaimToken claim_ = IRebasingClaimToken(detfInfo.rebasingClaimToken());
        uint256 claimBefore_ = claim_.balanceOf(alice);

        vm.prank(alice);
        uint256 minted_ = detfBonding.sellNFT(tokenId_, alice);
        assertTrue(minted_ > 0, "claim minted");
        assertEq(claim_.balanceOf(alice) - claimBefore_, minted_, "claim balance");

        // Redeemer must approve DETF (burnShares pulls claim via onlyOwner path without transfer when owner=DETF).
        // burnShares(owner=msg.sender) burns from alice without transferFrom when pretransferred=false — it burns sharesOf(owner).
        uint256 daiBefore_ = dai.balanceOf(alice);
        uint256 claimAmt_ = claim_.balanceOf(alice);
        assertTrue(claimAmt_ > 0, "has claim");

        // redeem half of claim to rateAsset0 (dai)
        uint256 redeemAmt_ = claimAmt_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimAmt_;

        vm.prank(alice);
        uint256 out_ =
            detfBonding.redeemClaim(redeemAmt_, rateAsset0, 0, alice, block.timestamp + 1 hours);

        assertTrue(out_ > 0, "rateAsset payout");
        assertEq(dai.balanceOf(alice) - daiBefore_, out_, "dai received");
        assertTrue(claim_.balanceOf(alice) < claimAmt_, "claim burned");
        _assertNoFreeInventory(detf);
    }

    function test_redeemClaim_unconfiguredRateAsset_reverts() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        vm.prank(alice);
        detfBonding.sellNFT(tokenId_, alice);

        address junk = address(uint160(uint256(keccak256("junkRate"))));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MultiVaultWeightedDetfRepo.InvalidRoute.selector, address(0), junk)
        );
        detfBonding.redeemClaim(1e18, IERC20(junk), 0, alice, block.timestamp + 1 hours);
    }

    function test_redeemClaim_withoutClaimInventory_reverts() public {
        _goLiveViaBptBond(detf, bob, 500e18);
        // alice has no claim tokens
        vm.prank(alice);
        vm.expectRevert();
        detfBonding.redeemClaim(1e18, rateAsset0, 0, alice, block.timestamp + 1 hours);
    }
}
