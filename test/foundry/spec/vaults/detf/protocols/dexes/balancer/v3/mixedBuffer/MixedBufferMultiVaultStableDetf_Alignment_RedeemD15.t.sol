// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";

contract MixedBufferMultiVaultStableDetf_Alignment_RedeemD15 is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        _fundBuffer(bob, 100e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 100e18);
        (uint256 tokenId_,) =
            detfBonding.bond(IERC20(address(dai)), 100e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(bob);
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
        uint256 claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert();
        detfBonding.redeemClaim(claimBal_ / 3, IERC20(address(dai)), 0, bob, block.timestamp + 1 hours);
    }
}
