// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_SingleStandardExchangeDETF_Decimals
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/// @notice Phase 3: mint after bootstrap with open mint threshold (production SE only).
abstract contract SingleStandardExchangeDETF_Mint_Decimals is TestBase_SingleStandardExchangeDETF_Decimals {
    address internal openDetf;
    ISingleStandardExchangeDETFInfo internal openInfo;
    ISingleStandardExchangeDETFBonding internal openBonding;
    IStandardExchangeIn internal openExchangeIn;

    function setUp() public virtual override {
        super.setUp();
        openDetf = _deployOpenMintDetf();
        openInfo = ISingleStandardExchangeDETFInfo(openDetf);
        openBonding = ISingleStandardExchangeDETFBonding(openDetf);
        openExchangeIn = IStandardExchangeIn(openDetf);
    }

    function _deployOpenMintDetf() internal returns (address detf_) {
        // The legacy fixture helper deploys the current mandatory-threshold package.
        detf_ = _deployOpenModeDetf("Open Mint Single Standard Exchange DETF", "omDETF");
    }

    function _bootstrapOpen(address bonder, uint256 lpAmount) internal {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        vm.startPrank(bonder);
        seShare.approve(openDetf, seShares_);
        openBonding.bond(seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_mint_fromVaultShares_afterBootstrap() public {
        _bootstrapOpen(alice, 1_000e18);
        assertTrue(openInfo.isReserveLive(), "live");
        assertFalse(openInfo.isMintingAllowed(), "primary mint closed; standard route uses reserve swap");

        uint256 seShares_ = _fundSeShares(bob, 200e18);
        uint256 bobBefore_ = IERC20(openDetf).balanceOf(bob);
        uint256 preview_ = openExchangeIn.previewExchangeIn(seShare, seShares_, IERC20(openDetf));

        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 out_ =
            openExchangeIn.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(out_ > 0, "minted detf");
        assertEq(IERC20(openDetf).balanceOf(bob) - bobBefore_, out_, "user balance");
        // Closed-form share path: preview should match execution (within 1 wei rounding).
        assertApproxEqAbs(preview_, out_, 1, "preview == execution");
    }

    function test_closedPrimaryMint_swapsExistingDetf_withoutIssuance() public {
        _bootstrapOpen(alice, 1_000e18);
        uint256 reserveDetfBefore_ = IERC20(openDetf).balanceOf(address(vault));
        uint256 feeToBefore_ = IERC20(openDetf).balanceOf(_feeTo());
        uint256 supplyBefore_ = IERC20(openDetf).totalSupply();
        assertFalse(openInfo.isMintingAllowed(), "primary mint closed");

        uint256 seShares_ = _fundSeShares(bob, 200e18);
        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        uint256 out_ =
            openExchangeIn.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();

        assertTrue(out_ > 0, "minted");
        assertEq(
            IERC20(openDetf).balanceOf(address(vault)), reserveDetfBefore_ - out_, "existing reserve DETF pays the swap"
        );
        assertEq(IERC20(openDetf).totalSupply(), supplyBefore_, "fallback does not issue DETF");
        assertEq(IERC20(openDetf).balanceOf(_feeTo()), feeToBefore_, "D14 no feeTo mint");
    }

    function test_mint_revertsWhenInert() public {
        uint256 seShares_ = _fundSeShares(alice, 100e18);
        vm.startPrank(alice);
        seShare.approve(openDetf, seShares_);
        vm.expectRevert();
        openExchangeIn.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }
}
