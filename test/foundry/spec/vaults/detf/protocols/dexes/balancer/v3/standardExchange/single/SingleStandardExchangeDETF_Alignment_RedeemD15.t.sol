// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice D15 DETF-only redeem on Single SE. D15-5 N/A NatSpec.
contract SingleStandardExchangeDETF_Alignment_RedeemD15 is TestBase_SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        detf = _deployOpenModeDetf("D15 SSE", "d15sse");
        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        _bootstrapViaFirstBond(alice, 1_200e18);
    }

    function _sellBob() internal returns (uint256 claimBal_) {
        uint256 tokenId_ = _bootstrapDetf(detf, bob, 200e18);
        _warpPastUnlock(detf, tokenId_);
        vm.prank(bob);
        detfBonding.sellPositionToDetfNft(tokenId_, 0, bob);
        claimBal_ = IRebasingClaimToken(detfInfo.rebasingClaimToken()).balanceOf(bob);
        assertGt(claimBal_, 0);
    }

    function test_D15_1_previewEqualsExecute() public {
        uint256 claimBal_ = _sellBob();
        uint256 redeem_ = claimBal_ / 2;
        uint256 preview_ = detfBonding.previewRedeemClaim(redeem_, IERC20(detf));
        uint256 before_ = IERC20(detf).balanceOf(bob);
        vm.prank(bob);
        uint256 out_ = detfBonding.redeemClaim(redeem_, IERC20(detf), 0, bob, block.timestamp + 1 hours);
        assertApproxEqAbs(out_, preview_, 1, "D15-1");
        assertEq(IERC20(detf).balanceOf(bob) - before_, out_);
    }

    function test_D15_8_tokenOutNotDetfReverts() public {
        uint256 claimBal_ = _sellBob();
        vm.prank(bob);
        vm.expectRevert();
        detfBonding.redeemClaim(claimBal_ / 3, seShare, 0, bob, block.timestamp + 1 hours);
    }

    function test_D15_9_ungatedVsOpen() public {
        uint256 claimBal_ = _sellBob();
        vm.prank(bob);
        uint256 out_ = detfBonding.redeemClaim(claimBal_ / 4, IERC20(detf), 0, bob, block.timestamp + 1 hours);
        assertGt(out_, 0);
    }
}
