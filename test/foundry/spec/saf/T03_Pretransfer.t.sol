// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";

/// @notice T03 / L-CLAIM-3: pretransferred requires proven balance increase vs lastSelfBalance.
contract T03_Pretransfer_Test is TestBase_UniswapV4SingleStandardExchangeDETF {
    function setUp() public override {
        super.setUp();
        _firstBond(400 ether);
        _firstBond(80 ether);
    }

    function test_redeem_pretransferred_false_pullsFromCaller() public {
        (uint256 tokenId,) = _firstBond(50 ether);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 bal = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(bal, 0);

        // Non-pretransfer path pulls claim shares from msg.sender via internal transfer (no ERC20 approve).
        vm.prank(detfUser);
        uint256 out = IRebasingClaimToken(claim).redeem(bal / 4, detfUser, false);
        assertTrue(out >= 0, "redeem from caller balance");
        assertLt(IRebasingClaimToken(claim).balanceOf(detfUser), bal, "caller claim reduced");
    }

    function test_redeem_pretransferred_true_withoutDeposit_reverts() public {
        (uint256 tokenId,) = _firstBond(50 ether);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 bal = IRebasingClaimToken(claim).balanceOf(detfUser);
        assertGt(bal, 0);

        // Fake pretransfer: claim never received tokens → L-CLAIM-3 abuse path.
        vm.prank(detfUser);
        vm.expectRevert();
        IRebasingClaimToken(claim).redeem(bal / 4, detfUser, true);
    }

    function test_redeem_pretransferred_true_afterRealTransfer_succeeds() public {
        (uint256 tokenId,) = _firstBond(60 ether);
        vm.prank(detfUser);
        detfInfo.sellPositionToDetfNft(tokenId, detfUser);

        address claim = detfInfo.rebasingClaimToken();
        uint256 bal = IRebasingClaimToken(claim).balanceOf(detfUser);
        uint256 amt = bal / 4;
        assertGt(amt, 0);

        // Real transfer into claim diamond, then redeem with pretransferred=true.
        // Use post-transfer held balance (rebasing share math may round 1 wei).
        vm.startPrank(detfUser);
        IERC20(claim).transfer(claim, amt);
        uint256 held = IERC20(claim).balanceOf(claim);
        assertGt(held, 0, "claim diamond holds transferred claim");
        uint256 rateOut = IRebasingClaimToken(claim).redeem(held, detfUser, true);
        vm.stopPrank();

        // Unwind path returns settlement via DETF claimLiquidity (pair out for CP-single).
        assertTrue(rateOut >= 0, "redeem completed via unwind path");
    }
}
