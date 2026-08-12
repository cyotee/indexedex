// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";
import {
    IMixedBufferMultiVaultStableDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfInfoTarget.sol";
import {
    IMixedBufferMultiVaultStableDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfBondingTarget.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";

contract MixedBufferMultiVaultStableDetf_Claim_Test is TestBase_MixedBufferMultiVaultStableDetf {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenThresholdDetfN(1);
        detfInfo = IMixedBufferMultiVaultStableDetfInfo(detf);
        detfBonding = IMixedBufferMultiVaultStableDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _bootstrapDefault(detf, alice);
    }

    function test_sell_to_claim_and_redeem_buffer() public {
        _fundBuffer(bob, 200e18);
        vm.startPrank(bob);
        IERC20(address(dai)).approve(detf, 200e18);
        (uint256 tokenId_,) = detfBonding.bond(
            IERC20(address(dai)), 200e18, DEFAULT_MIN_LOCK, bob, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        _warpPastUnlock(detf, tokenId_);
        vm.prank(bob);
        uint256 claimMinted_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);

        assertTrue(claimMinted_ > 0, "claim minted");
        IRebasingClaimToken claim_ = IRebasingClaimToken(detfInfo.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(bob);
        assertTrue(claimBal_ > 0, "claim balance");

        uint256 bufBefore_ = IERC20(address(dai)).balanceOf(bob);
        vm.startPrank(bob);
        uint256 out_ = detfBonding.redeemClaim(claimBal_, 0, bob, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(out_ > 0, "buffer from redeem");
        assertEq(IERC20(address(dai)).balanceOf(bob) - bufBefore_, out_, "buffer received");
        _assertNoFreeInventory(detf);
    }
}
