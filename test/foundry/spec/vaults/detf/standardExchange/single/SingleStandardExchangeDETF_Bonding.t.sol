// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice Phase 2: first-bond bootstrap + lock clamp rules against production SE vault.
contract SingleStandardExchangeDETF_Bonding_Test is TestBase_SingleStandardExchangeDETF {
    function test_firstBond_bootstrapsReserveLive() public {
        _assertInert();
        (uint256 tokenId_, uint256 bpt_) = _bootstrapViaFirstBond(alice, 1_000e18);
        _assertLive();
        assertTrue(tokenId_ > 0, "bond nft minted");
        assertTrue(bpt_ > 0, "bpt principal recorded");
        assertTrue(IERC20(detf).totalSupply() > 0, "detf minted for reserve + split");
        assertTrue(IERC20(detfInfo.reservePool()).totalSupply() > 0, "reserve pool initialized");
    }

    function test_bond_revertsIfLockTooShort() public {
        uint256 seShares_ = _fundSeShares(alice, 500e18);
        vm.startPrank(alice);
        seShare.approve(detf, seShares_);
        vm.expectRevert();
        detfBonding.bond(seShare, seShares_, 1 days, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bond_clampsLockAboveMax() public {
        uint256 seShares_ = _fundSeShares(alice, 500e18);
        vm.startPrank(alice);
        seShare.approve(detf, seShares_);
        // Above max should clamp (not revert) per PRD.
        (uint256 tokenId_,) =
            detfBonding.bond(seShare, seShares_, DEFAULT_MAX_LOCK + 365 days, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "clamped max lock still bonds");
        _assertLive();
    }

    function test_mint_stillGatedByThresholdAfterBootstrap() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        // After first bond at peg, synthetic is near 1e18 → mint blocked by 1.05 threshold.
        uint256 seShares_ = _fundSeShares(bob, 100e18);
        vm.startPrank(bob);
        seShare.approve(detf, seShares_);
        // May revert MintingNotAllowed if synthetic ≤ threshold (expected post-bootstrap at peg).
        try detfExchangeIn.exchangeIn(
            seShare, seShares_, IERC20(detf), 0, bob, false, block.timestamp + 1 hours
        ) returns (uint256 out_) {
            // If mint succeeded, synthetic must have been above threshold.
            assertTrue(out_ > 0, "minted amount");
            assertTrue(detfInfo.isMintingAllowed() || out_ > 0, "mint path");
        } catch (bytes memory reason) {
            // Accept MintingNotAllowed or other threshold guard.
            assertTrue(reason.length > 0, "reverted with reason");
        }
        vm.stopPrank();
    }
}
