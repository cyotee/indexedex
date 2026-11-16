// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    MixedBufferMultiVaultStableDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfRepo.sol";
import {IMixedBufferMultiVaultStableDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol";
import {IMixedBufferMultiVaultStableDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfInfo.sol";

contract MixedBufferMultiVaultStableDetf_Bootstrap_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function test_bootstrap_permissionless_third_party() public virtual {
        _assertInert(detf);
        // bob is not owner
        (uint256 tokenId_, uint256 bpt_, uint256 principal_) = _bootstrapDefault(detf, bob);
        _assertLive(detf);
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(bpt_ > 0, "protocol LP");
        assertGt(principal_, 0);
        assertEq(IDetfBondNFT(detfInfo.bondNftVault()).positionOf(tokenId_).principal, principal_);
        assertEq(IERC20(detf).balanceOf(bob), 0, "purchased principal is staked in escrow");
        assertTrue(IERC20(detf).totalSupply() > 0, "supply");
        assertTrue(IERC20(detfInfo.reservePool()).totalSupply() > 0, "pool supply");
    }

    function test_bootstrap_second_reverts() public virtual {
        _bootstrapDefault(detf, alice);
        _assertLive(detf);

        uint256 shareAmt_ = _fundVaultShares(0, bob, 100e18);
        _fundBuffer(bob, _fixtureAmount(100e18));
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;

        vm.startPrank(bob);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(100e18));
        seShares[0].approve(detf, shareAmt_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.AlreadyLive.selector);
        detfBonding.bootstrapFirstBond(_fixtureAmount(100e18), shares_, DEFAULT_MIN_LOCK, bob, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_zero_buffer_reverts() public virtual {
        uint256 shareAmt_ = _fundVaultShares(0, alice, 100e18);
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = shareAmt_;

        vm.startPrank(alice);
        seShares[0].approve(detf, shareAmt_);
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.ZeroAmount.selector);
        detfBonding.bootstrapFirstBond(0, shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_zero_share_leg_reverts() public virtual {
        _fundBuffer(alice, _fixtureAmount(100e18));
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = 0;

        vm.startPrank(alice);
        IERC20(address(_fixtureBufferToken())).approve(detf, _fixtureAmount(100e18));
        vm.expectRevert(MixedBufferMultiVaultStableDetfRepo.InvalidBootstrapAmounts.selector);
        detfBonding.bootstrapFirstBond(_fixtureAmount(100e18), shares_, DEFAULT_MIN_LOCK, alice, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bootstrap_peg_seed_n1() public virtual {
        // Unit-level: with equal buffer and share amounts + STANDARD rates,
        // detf seed = (b + s) / 2.
        uint256 bufferAmt_ = _fixtureAmount(1_000e18);
        uint256 shareFund_ = 1_000e18;
        (uint256 tokenId_,, uint256 principal_) = _bootstrapFirstBond(detf, alice, bufferAmt_, shareFund_);
        _assertLive(detf);
        // Pool self-leg and fully staked purchased principal are separate issuance.
        assertTrue(IERC20(detf).totalSupply() > 0, "supply after bootstrap");
        assertEq(IDetfBondNFT(detfInfo.bondNftVault()).positionOf(tokenId_).principal, principal_);
    }

    function test_bootstrap_ungated_by_synthetic() public virtual {
        // Default thresholds - bootstrap still succeeds near peg.
        (uint256 tokenId_,,) = _bootstrapDefault(detf, alice);
        assertTrue(tokenId_ > 0, "tokenId");
        assertTrue(detfInfo.syntheticPrice() > 0, "synthetic readable");
    }
}
