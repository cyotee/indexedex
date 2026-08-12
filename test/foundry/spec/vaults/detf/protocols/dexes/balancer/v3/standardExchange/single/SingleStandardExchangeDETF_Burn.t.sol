// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice Phase 4: burn DETF → vault shares after open-threshold bootstrap + mint.
contract SingleStandardExchangeDETF_Burn_Test is TestBase_SingleStandardExchangeDETF {
    address internal openDetf;
    ISingleStandardExchangeDETFInfo internal openInfo;
    ISingleStandardExchangeDETFBonding internal openBonding;
    IStandardExchangeIn internal openExchangeIn;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenDetf();
        openInfo = ISingleStandardExchangeDETFInfo(openDetf);
        openBonding = ISingleStandardExchangeDETFBonding(openDetf);
        openExchangeIn = IStandardExchangeIn(openDetf);
    }

    function _deployOpenDetf() internal returns (address detf_) {
        // Product Open: mint+burn when live (historical mint=1/burn=max fails mint>burn validation).
        detf_ = _deployOpenModeDetf("Open Burn Single Standard Exchange DETF", "obDETF");
    }

    function _bootstrapAndMint(address user, uint256 bondLp, uint256 mintLp)
        internal
        returns (uint256 detfBal_)
    {
        uint256 bondShares_ = _fundSeShares(user, bondLp);
        vm.startPrank(user);
        seShare.approve(openDetf, bondShares_);
        openBonding.bond(seShare, bondShares_, DEFAULT_MIN_LOCK, user, false, block.timestamp + 1 hours);
        vm.stopPrank();

        uint256 mintShares_ = _fundSeShares(user, mintLp);
        vm.startPrank(user);
        seShare.approve(openDetf, mintShares_);
        openExchangeIn.exchangeIn(
            seShare, mintShares_, IERC20(openDetf), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        detfBal_ = IERC20(openDetf).balanceOf(user);
    }

    function test_burn_toVaultShares() public {
        uint256 detfBal_ = _bootstrapAndMint(alice, 1_000e18, 200e18);
        assertTrue(detfBal_ > 0, "has detf");
        assertTrue(openInfo.isBurningAllowed(), "burn allowed");

        uint256 burnAmt_ = detfBal_ / 2;
        uint256 seBefore_ = seShare.balanceOf(alice);
        uint256 preview_ = openExchangeIn.previewExchangeIn(IERC20(openDetf), burnAmt_, seShare);

        vm.startPrank(alice);
        IERC20(openDetf).approve(openDetf, burnAmt_);
        uint256 out_ = openExchangeIn.exchangeIn(
            IERC20(openDetf), burnAmt_, seShare, 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertTrue(out_ > 0, "received vault shares");
        assertEq(seShare.balanceOf(alice) - seBefore_, out_, "share balance");
        assertApproxEqAbs(preview_, out_, 1, "preview ~= execution");
    }
}
