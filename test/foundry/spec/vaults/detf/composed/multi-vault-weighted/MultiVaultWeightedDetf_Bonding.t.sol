// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/composed/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

contract MultiVaultWeightedDetf_Bonding_Test is TestBase_MultiVaultWeightedDetf {
    function test_bond_revertsIfLockTooShort() public {
        (uint256 tokenId0_,) = _goLiveViaBptBond(detf, alice, 500e18);
        assertTrue(tokenId0_ > 0);

        uint256 seShares_ = _fundSeShares0(bob, 100e18);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        vm.expectRevert();
        detfBonding.bond(seShare0, seShares_, 1 days, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_bond_vaultShare_afterLive() public {
        _goLiveViaBptBond(detf, alice, 1_000e18);
        uint256 seShares_ = _fundSeShares0(bob, 200e18);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        (uint256 tokenId_, uint256 shares_) =
            detfBonding.bond(seShare0, seShares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(tokenId_ > 0, "nft");
        assertTrue(shares_ > 0, "bpt principal");
    }

    function test_sellPositionToDetfNft() public {
        (uint256 tokenId_,) = _goLiveViaBptBond(detf, alice, 800e18);
        vm.prank(alice);
        uint256 principal_ = detfBonding.sellPositionToDetfNft(tokenId_, alice);
        assertTrue(principal_ > 0, "principal sold");
    }
}
