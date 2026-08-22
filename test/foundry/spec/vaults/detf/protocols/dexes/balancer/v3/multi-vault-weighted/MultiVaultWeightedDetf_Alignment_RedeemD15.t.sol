// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";

contract MultiVaultWeightedDetf_Alignment_RedeemD15 is TestBase_MultiVaultWeightedDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetf("D15 MVW", "d15mvw");
        detfInfo = IMultiVaultWeightedDetfInfo(detf);
        detfBonding = IMultiVaultWeightedDetfBonding(detf);
        _bootstrapViaFirstBond(alice, 1_000e18);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        uint256 seShares_ = _fundSeShares0(bob, 200e18);
        vm.startPrank(bob);
        seShare0.approve(detf, seShares_);
        (uint256 tokenId_,) =
            detfBonding.bond(seShare0, seShares_, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        _warpPastUnlock(detf, tokenId_);
        vm.prank(bob);
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert();
        detfBonding.redeemClaim(claimBal_ / 3, seShare0, 0, bob, block.timestamp + 1 hours);
    }
}
