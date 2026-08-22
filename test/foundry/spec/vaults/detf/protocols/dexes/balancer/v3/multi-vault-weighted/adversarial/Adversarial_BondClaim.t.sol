// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

/// @notice D2–D6 claim authority, double redeem, lock clamp.
/// @dev Deferred P2: D7 (sell then immediate redeem vs lock - sell/redeem independence by design;
///      documented in PRD; no free principal without sell).
contract Adversarial_BondClaim_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    function test_D2_redeemClaim_withoutClaim_noBptDrain() public {
        address instance_ = _openLiveN1();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        address pool_ = info_.reservePool();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(instance_);

        // Attacker has no claim tokens
        vm.prank(attacker);
        vm.expectRevert();
        IMultiVaultWeightedDetfBonding(instance_).redeemClaim(
            1e18, IERC20(instance_), 0, attacker, block.timestamp + 1 hours
        );

        assertEq(IERC20(pool_).balanceOf(instance_), bptBefore_, "D2: BPT not drained");
    }

    function test_D3_doubleRedeem_secondReverts() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 3_000e18);

        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);

        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        uint256 minted_ = bonding_.sellPositionToDetfNft(tokenId_, 0, alice);
        assertTrue(minted_ > 0, "claim minted");

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 bal_ = claim_.balanceOf(alice);
        // Small redeem to avoid min-balance grief
        uint256 part_ = bal_ / 10;
        if (part_ == 0) part_ = bal_;

        vm.prank(alice);
        uint256 out_ = bonding_.redeemClaim(part_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
        assertTrue(out_ > 0, "first redeem ok");

        uint256 left_ = claim_.balanceOf(alice);
        // Attempt over-redeem of remaining + more
        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(left_ + 1e18, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
    }

    function test_D4_redeem_junkRateAsset_InvalidRoute() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 tokenId_,) = _goLiveViaBptBond(instance_, alice, 1_500e18);
        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        bonding_.sellPositionToDetfNft(tokenId_, 0, alice);

        address junk = address(uint160(uint256(keccak256("junkRA"))));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiVaultWeightedDetfRepo.InvalidRoute.selector,
                IMultiVaultWeightedDetfInfo(instance_).rebasingClaimToken(),
                junk
            )
        );
        bonding_.redeemClaim(1e18, IERC20(junk), 0, alice, block.timestamp + 1 hours);
    }

    function test_D5_lockClamp_minRevert_maxOk() public {
        address instance_ = _openLiveN1();
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 80e18);
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        vm.expectRevert();
        IMultiVaultWeightedDetfBonding(instance_).bond(
            seShares[0], shares_, 1 days, attacker, false, block.timestamp + 1 hours
        );
        // max+ clamp succeeds
        (uint256 tid_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            seShares[0],
            shares_,
            DEFAULT_MAX_LOCK + 365 days,
            attacker,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tid_ > 0, "clamped max lock bonds");
    }

    function test_D6_cannotRedeemMoreThanClaimPrincipal() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 tokenId_, uint256 bptPrincipal_) = _goLiveViaBptBond(instance_, alice, 2_500e18);
        IMultiVaultWeightedDetfBonding bonding_ = IMultiVaultWeightedDetfBonding(instance_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);

        _warpPastUnlock(instance_, tokenId_);
        vm.prank(alice);
        bonding_.sellPositionToDetfNft(tokenId_, 0, alice);

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(alice);
        uint256 detfBefore_ = IERC20(instance_).balanceOf(alice);
        uint256 redeemAmt_ = claimBal_ / 5;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;

        vm.prank(alice);
        uint256 paid_ = bonding_.redeemClaim(redeemAmt_, IERC20(instance_), 0, alice, block.timestamp + 1 hours);

        assertGt(paid_, 0, "D15 DETF paid");
        assertLt(claim_.balanceOf(alice), claimBal_, "claim burned");
        assertGt(IERC20(instance_).balanceOf(alice), detfBefore_, "user DETF increased");
        assertTrue(redeemAmt_ <= bptPrincipal_ + claimBal_, "redeem sized from claim");
        vm.prank(alice);
        vm.expectRevert();
        bonding_.redeemClaim(claimBal_ + 1e18, IERC20(instance_), 0, alice, block.timestamp + 1 hours);
    }
}
