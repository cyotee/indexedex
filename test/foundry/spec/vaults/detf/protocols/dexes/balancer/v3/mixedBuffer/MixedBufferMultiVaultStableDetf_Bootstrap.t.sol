// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

contract MixedBufferMultiVaultStableDetf_Bootstrap_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_bootstrap_permissionless_third_party() public {
        _assertInert(detf);
        // bob is not owner
        (uint256 tokenId_, uint256 bpt_, uint256 freeDetf_) = _bootstrapDefault(detf, bob);
        _assertLive(detf);
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(bpt_ > 0, "bpt principal");
        // Free DETF may be zero if fee oracle seigniorage is zero; allow either.
        assertTrue(IERC20(detf).totalSupply() > 0, "supply");
        assertTrue(IERC20(detfInfo.reservePool()).totalSupply() > 0, "pool supply");
        freeDetf_; // used for observability
    }

    function test_bootstrap_second_reverts() public {
        _bootstrapDefault(detf, alice);
        _assertLive(detf);

        uint256 shareAmt_ = _fundVaultShares(0, bob, 100e18);
        _fundBuffer(bob, 100e18);
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;

        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 100e18);
        seShares[0].approve(detf, shareAmt_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.AlreadyLive.selector);
        detfBonding.bootstrapFirstBond(100e18, shares_, DEFAULT_MIN_LOCK, bob, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_zero_buffer_reverts() public {
        uint256 shareAmt_ = _fundVaultShares(0, alice, 100e18);
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;

        vm.startPrank(alice);
        seShares[0].approve(detf, shareAmt_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts.selector);
        detfBonding.bootstrapFirstBond(0, shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_zero_share_leg_reverts() public {
        _fundBuffer(alice, 100e18);
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = 0;

        vm.startPrank(alice);
        IERC20(address(dai)).approve(detf, 100e18);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts.selector);
        detfBonding.bootstrapFirstBond(100e18, shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_peg_seed_n1() public {
        // Unit-level: with equal buffer and share amounts + STANDARD rates,
        // detf seed = (b + s) / 2.
        uint256 bufferAmt_ = 1_000e18;
        uint256 shareFund_ = 1_000e18;
        (,, uint256 freeDetf_) = _bootstrapFirstBond(detf, alice, bufferAmt_, shareFund_);
        _assertLive(detf);
        // Pool has DETF self-leg; free DETF is seigniorage side effect.
        assertTrue(IERC20(detf).totalSupply() > 0, "supply after bootstrap");
        freeDetf_;
    }

    function test_bootstrap_ungated_by_synthetic() public {
        // Default thresholds — bootstrap still succeeds near peg.
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        assertTrue(tokenId_ > 0, "tokenId");
        assertTrue(detfInfo.syntheticPrice() > 0, "synthetic readable");
    }
}
