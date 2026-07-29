// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/composed/stable/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/composed/stable/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";

contract MixedBufferMultiVaultStableDetf_Bonding_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenThresholdDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_bond_buffer_after_live() public {
        _fundBuffer(bob, 100e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 100e18);
        (uint256 tokenId_, uint256 principal_) = detfBonding.bond(
            IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0 && principal_ > 0, "buffer bond");
    }

    function test_bond_vaultShare_after_live() public {
        uint256 shares_ = _fundVaultShares(0, bob, 100e18);
        vm.startPrank(bob);
        seShares[0].approve(detf, shares_);
        (uint256 tokenId_, uint256 principal_) = detfBonding.bond(
            seShares[0], shares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0 && principal_ > 0, "share bond");
    }

    function test_bond_reserveBpt_after_live() public {
        // Production path: user obtains reserve BPT via seRouter unbalanced join, then bonds BPT.
        uint256 bpt_ = _fundReserveBpt(detf, bob, 80e18);
        assertTrue(bpt_ > 0, "user funded with BPT");
        address pool_ = detfInfo.reservePool();
        assertEq(IERC20(pool_).balanceOf(bob), bpt_, "bob holds all funded BPT");

        vm.startPrank(bob);
        IERC20(pool_).approve(detf, bpt_);
        (uint256 tokenId_, uint256 principal_) = detfBonding.bond(
            IERC20(pool_), bpt_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(tokenId_ > 0, "bpt bond nft");
        assertEq(principal_, bpt_, "principal == bpt bonded");
        assertEq(IERC20(pool_).balanceOf(bob), 0, "bpt pulled from bob");
    }

    function test_bond_lock_too_short_reverts() public {
        _fundBuffer(bob, 50e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 50e18);
        vm.expectRevert();
        detfBonding.bond(
            IERC20(address(dai)), 50e18, 1 days, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_bond_lock_clamps_to_max() public {
        _fundBuffer(bob, 50e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 50e18);
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(dai)), 50e18, DEFAULT_MAX_LOCK + 365 days, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "clamped lock succeeds");
    }
}
