// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFRepo.sol";

/// @notice Phase 2: first-bond bootstrap + lock clamp rules against production SE vault.
contract SingleStandardExchangeDETF_Bonding_Test is TestBase_SingleStandardExchangeDETF, FundedBondLifecycleAssertions {
    function test_firstBond_bootstrapsReserveLive() public {
        _assertInert();
        (uint256 tokenId_, uint256 bpt_) = _bootstrapViaFirstBond(alice, 1_000e18);
        _assertLive();
        assertTrue(tokenId_ > 0, "bond nft minted");
        assertTrue(bpt_ > 0, "bpt principal recorded");
        assertTrue(IERC20(detf).totalSupply() > 0, "detf minted for reserve + split");
        assertTrue(IERC20(detfInfo.reservePool()).totalSupply() > 0, "reserve pool initialized");
    }

    function test_bond_live_unboostedLiquidityAndFundedRewards() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 seShares_ = _fundSeShares(bob, 200e18);
        (uint256 principal_, uint256 liquidity_, uint256 rewards_) =
            detfBonding.previewBond(seShare, seShares_, DEFAULT_MIN_LOCK);
        IStakedDETF staking_ = IStakedDETF(address(detfInfo.rebasingClaimToken()));
        uint256 backing_ = IERC20(detf).balanceOf(address(staking_));
        uint256 reserve_ = IERC20(detf).balanceOf(address(vault));
        vm.startPrank(bob);
        seShare.approve(detf, seShares_);
        (uint256 id_,) = detfBonding.bond(seShare, seShares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(liquidity_, 0);
        assertEq(IERC20(detf).balanceOf(address(vault)) - reserve_, liquidity_, "unboosted liquidity leg");
        assertEq(
            IERC20(detf).balanceOf(address(staking_)) - backing_,
            principal_ + rewards_,
            "purchase and rewards actually funded"
        );
        assertEq(IDetfBondNFT(detfInfo.bondNftVault()).positionOf(id_).principal, principal_);
        _assertBondPrincipalIsFunded(detf, id_, bob);
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

    function test_mint_belowThreshold_executesReserveSwap() public {
        _bootstrapViaFirstBond(alice, 1_000e18);
        assertFalse(detfInfo.isMintingAllowed(), "primary mint remains closed");
        uint256 seShares_ = _fundSeShares(bob, 100e18);
        uint256 quote_ = detfExchangeIn.previewExchangeIn(seShare, seShares_, IERC20(detf));
        assertGt(quote_, 0, "funded swap output");
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.startPrank(bob);
        seShare.approve(detf, seShares_);
        uint256 out_ =
            detfExchangeIn.exchangeIn(seShare, seShares_, IERC20(detf), quote_, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(out_, quote_);
        assertEq(IERC20(detf).balanceOf(bob), quote_);
        assertEq(IERC20(detf).totalSupply(), supply_, "fallback swaps existing DETF");
    }

    function test_newBond_principalRemainsLocked() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        _assertBondPrincipalStillLocked(detf, tokenId_, alice);
    }

    function test_bond_partialVesting_paysFundedStaking() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        _assertBondPartialVesting(detf, tokenId_, alice);
    }

    function test_matureBond_previewEqualsFundedPayment() public {
        (uint256 tokenId_,) = _bootstrapViaFirstBond(alice, 800e18);
        _assertBondMaturePreviewEqualsPayment(detf, tokenId_, alice);
    }
}
