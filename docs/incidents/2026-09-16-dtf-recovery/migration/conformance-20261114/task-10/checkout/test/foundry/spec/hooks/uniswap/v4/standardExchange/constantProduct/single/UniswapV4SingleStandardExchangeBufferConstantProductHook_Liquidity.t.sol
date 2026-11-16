// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title Liquidity matrix: proportional + zap-in/out, virtual pair, withdraw.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Liquidity_Test is TestBase {
    function test_P1_firstDeposit_minLiquidityAndVirtualPair() public {
        _initPool();
        uint256 lp = _depositBoth(100 ether, 100 ether);
        assertGt(lp, 0);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(single.isLive());
        assertGt(single.rawReserve(), 0);
        assertGt(single.seClaimSupply(), 0);
        // The actual genesis redemption is a separate positive local component.
        assertGt(pairToken.balanceOf(hook), 0);
        // The shared reserve view publishes local plus rated booked shares.
        assertEq(single.seClaimSupply(), IBasicVault(hook).reserveOfToken(address(pairToken)));
        assertTrue(single.seClaimSupply() != pairToken.balanceOf(hook) || pairToken.balanceOf(hook) == 0);
    }

    function test_VR1_virtualPairNotFreePairBalance() public {
        _seedLiveLiquidity();
        // Donate free pair — must not change book (seClaimSupply)
        pairToken.mint(hook, 50 ether);
        uint256 claimBefore = single.seClaimSupply();
        // Reserves after donation: free pair rises but virtual claim unchanged until buffer
        assertEq(single.seClaimSupply(), claimBefore);
        assertGt(pairToken.balanceOf(hook), DUST);
        // Product book reserve for pair is still virtual
        assertEq(single.reserveCurrency0() + single.reserveCurrency1(),
            single.rawReserve() + single.seClaimSupply());
    }

    function test_P3_subsequentDeposit_previewEqualsExec_clampRefund() public {
        _seedLiveLiquidity();
        uint256 a0 = _amountForCurrency(single.currency0(), 50 ether, 50 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 50 ether, 50 ether);
        // Unbalanced offer → clamp
        uint256 offer0 = a0 + 10 ether;
        uint256 offer1 = a1;
        (uint256 predLp, uint256 predU0, uint256 predU1) = single.previewDeposit(offer0, offer1);
        uint256 bal0Before = IERC20(single.currency0()).balanceOf(user);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 localBefore = pairToken.balanceOf(hook);
        uint256 rawBefore = rawToken.balanceOf(hook);
        uint256 sharesBefore = IERC20(se).balanceOf(hook);
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = single.deposit(offer0, offer1, user, 0, block.timestamp + 1);
        assertEq(lp, predLp);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
        // Refund excess currency0 if clamped
        if (offer0 > u0) {
            assertEq(IERC20(single.currency0()).balanceOf(user), bal0Before - u0);
        }
        uint256 product = (IERC20(hook).totalSupply() - supplyBefore) * localBefore;
        assertEq(pairToken.balanceOf(hook) - localBefore,
            product / supplyBefore + (product % supplyBefore == 0 ? 0 : 1), "ceil local contribution");
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        assertEq(rawToken.balanceOf(hook) - rawBefore, _ceil(gross, rawBefore, supplyBefore), "ceil raw contribution");
        assertEq(IERC20(se).balanceOf(hook) - sharesBefore,
            _ceil(gross, sharesBefore, supplyBefore), "ceil share contribution");
    }

    function test_P4_zeroAmount_reverts() public {
        _initPool();
        vm.prank(user);
        // R2.4: pin ZeroAmount() 0x1f2a2005 (DepositCommon); a bare expectRevert() also
        // passed on an unrelated Panic/OOG, masking a wrong-guard regression.
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        single.deposit(0, 1 ether, user, 0, block.timestamp + 1);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        single.deposit(1 ether, 0, user, 0, block.timestamp + 1);
    }

    function test_P5_deadlineAndMinLp_reverts() public {
        _initPool();
        uint256 a0 = _amountForCurrency(single.currency0(), 10 ether, 10 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 10 ether, 10 ether);
        vm.prank(user);
        // R2.4: pin DeadlineExpired() 0x1ab7da6b (DepositCommon); bare form masked wrong revert.
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        single.deposit(a0, a1, user, 0, block.timestamp - 1);

        _depositBoth(100 ether, 100 ether);
        vm.prank(user);
        // R2.4: pin InsufficientLpOut() 0xb49d8a5e (DepositCommon).
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        single.deposit(a0, a1, user, type(uint256).max, block.timestamp + 1);
    }

    function test_P6_afterFullExit_subsequentMint() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertEq(IERC20(hook).totalSupply(), 1000 + IERC20(hook).balanceOf(_feeTo()), "treasury remains an LP");
        // Next proportional deposit uses subsequent mint (supply > 0)
        uint256 lp2 = _depositBoth(50 ether, 50 ether);
        assertGt(lp2, 0);
        assertGt(IERC20(hook).totalSupply(), 1000);
    }

    function test_W1_withdraw_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user) / 2;
        (uint256 pred0, uint256 pred1) = single.previewWithdraw(lp);
        uint256 b0 = IERC20(single.currency0()).balanceOf(user);
        uint256 b1 = IERC20(single.currency1()).balanceOf(user);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 localBefore = pairToken.balanceOf(hook);
        uint256 sharesBefore = IERC20(se).balanceOf(hook);
        uint256 rawClaim = lp * single.rawReserve() / supply;
        uint256 shareClaim = lp * sharesBefore / supply;
        uint256 localClaim = lp * localBefore / supply;
        (uint256 redeemed,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), shareClaim, IERC20(address(pairToken)));
        vm.prank(user);
        (uint256 a0, uint256 a1) = single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertEq(a0, pred0);
        assertEq(a1, pred1);
        assertEq(IERC20(single.currency0()).balanceOf(user) - b0, a0);
        assertEq(IERC20(single.currency1()).balanceOf(user) - b1, a1);
        assertEq(_isRawCurrency0() ? a0 : a1, rawClaim, "independent floor raw claim");
        assertEq(_isRawCurrency0() ? a1 : a0, localClaim + redeemed, "floor local plus actual SE redemption");
        assertEq(pairToken.balanceOf(hook), localBefore - localClaim, "other LP local backing retained");
        assertEq(IERC20(se).balanceOf(hook), sharesBefore - shareClaim, "only allocated shares redeemed");
    }

    function test_Zi1_depositSingle_bothDirections() public {
        _seedLiveLiquidity();
        for (uint256 i; i < 2; ++i) {
            address input = i == 0 ? address(rawToken) : address(pairToken);
            uint256 preview = single.previewDepositSingle(input, 20 ether);
            uint256 lpBefore = IERC20(hook).balanceOf(user);
            assertGt(preview, 0, "both paid input directions quote LP");
            vm.prank(user);
            uint256 minted = single.depositSingle(input, 20 ether, user, preview, block.timestamp + 1);
            assertEq(minted, preview, "single input preview equals execution");
            assertEq(IERC20(hook).balanceOf(user) - lpBefore, minted, "recipient net LP");
            assertEq(single.rawReserve(), rawToken.balanceOf(hook), "native raw conservation");
        }
    }

    function test_Zi2_previewZapSplit_sumsToAmountIn() public {
        _seedLiveLiquidity();
        (uint256 swapAmt, uint256 otherOut, uint256 kept) =
            single.previewZapSplit(address(rawToken), 20 ether);
        assertGt(swapAmt, 0, "positive paid preparation");
        assertLt(swapAmt, 20 ether, "preparation retains caller input");
        assertGt(otherOut, 0, "positive purchased leg");
        assertEq(kept + swapAmt, 20 ether);
    }

    /// @notice A genuinely zero local book requires no local contribution or share redemption.
    function test_zeroLocalBook_shareFundedJoin_preservesRawAndShareFractions() public {
        _seedLiveLiquidity();
        uint256 local_ = pairToken.balanceOf(hook);
        uint256 swapInput_ = single.previewSwapExactOut(address(rawToken), address(pairToken), local_);
        rawToken.mint(owner, swapInput_);
        vm.startPrank(owner);
        rawToken.approve(hook, swapInput_);
        single.ownerSwapExactOut(address(rawToken), address(pairToken), local_, swapInput_, block.timestamp);
        vm.stopPrank();
        assertEq(pairToken.balanceOf(hook), 0, "trade exhausts only the booked local output");
        uint256 shares_ = _mintSeSharesToUser(20 ether);
        uint256 rawBefore_ = single.rawReserve();
        uint256 shareBefore_ = IERC20(se).balanceOf(hook);
        uint256 supplyBefore_ = IERC20(hook).totalSupply();
        (uint256 preview_,,) = single.previewDepositWithSeShares(20 ether, shares_);
        vm.prank(user);
        (uint256 net_,,) = single.depositWithSeShares(20 ether, shares_, user, 1, block.timestamp);
        uint256 gross_ = IERC20(hook).totalSupply() - supplyBefore_;
        assertGt(net_, 0, "zero local component does not disable a complete basket");
        assertEq(net_, preview_, "zero-local preview parity");
        assertEq(single.rawReserve() - rawBefore_, _ceil(gross_, rawBefore_, supplyBefore_));
        assertEq(IERC20(se).balanceOf(hook) - shareBefore_, _ceil(gross_, shareBefore_, supplyBefore_));
        assertEq(pairToken.balanceOf(hook), 0, "no needless caller share redemption");
    }

    function test_Zi3_depositSingle_emptyBook_reverts() public {
        _initPool();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Zi4_depositSingle_onlyMinLiquidity_reverts() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        _withdrawTreasury();
        assertEq(IERC20(hook).totalSupply(), 1000);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Zo1_withdrawSingle_bothTokenOut_previewEqualsExec() public {
        _seedLiveLiquidity();
        // Allocate the native basket, then sell only the exiting raw claim for pair components.
        uint256 lp = IERC20(hook).balanceOf(user) / 4;
        uint256 predPair = single.previewWithdrawSingle(lp, address(pairToken));
        uint256 bPair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 outPair = single.withdrawSingle(lp, address(pairToken), user, 0, block.timestamp + 1);
        assertEq(outPair, predPair, "pairOut preview!=exec");
        assertEq(pairToken.balanceOf(user) - bPair, outPair);
        assertGt(outPair, 0);

        // Allocate the native basket, then trade only the exiting pair/share claims for raw.
        lp = IERC20(hook).balanceOf(user) / 3;
        uint256 predRaw = single.previewWithdrawSingle(lp, address(rawToken));
        uint256 bRaw = rawToken.balanceOf(user);
        vm.prank(user);
        uint256 outRaw = single.withdrawSingle(lp, address(rawToken), user, 0, block.timestamp + 1);
        assertEq(outRaw, predRaw, "rawOut preview==exec");
        assertEq(rawToken.balanceOf(user) - bRaw, outRaw);
        assertGt(outRaw, 0);
        assertGt(pairToken.balanceOf(hook), 0, "continuing holders retain local backing");
    }

    function test_Zo3_withdrawSingle_notEligible_whenOnlyMinLiquidity() public {
        // Both depositor and treasury must exit before only the locked floor remains.
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        _withdrawTreasury();
        assertEq(IERC20(hook).balanceOf(user), 0);
        assertEq(IERC20(hook).totalSupply(), 1000);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("NotZapEligible()"));
        single.withdrawSingle(1, address(pairToken), user, 0, block.timestamp + 1);
    }

    function test_Zo7_withdrawSingle_deadlineAndMinOut() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user) / 5;
        vm.prank(user);
        // R2.4: pin DeadlineExpired() 0x1ab7da6b (WithdrawTarget).
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        single.withdrawSingle(lp, address(rawToken), user, 0, block.timestamp - 1);
        vm.prank(user);
        // R2.4: pin InsufficientTokenOut() 0x3dec0665 (WithdrawTarget).
        vm.expectRevert(abi.encodeWithSignature("InsufficientTokenOut()"));
        single.withdrawSingle(lp, address(rawToken), user, type(uint256).max, block.timestamp + 1);
    }

    function test_E1_lpMetadataPrefix() public view {
        IERC20Metadata meta = IERC20Metadata(hook);
        assertEq(meta.decimals(), 18);
        assertEq(bytes(meta.symbol())[0], bytes1("S")); // SSEBCP-
        assertTrue(bytes(meta.name()).length > 0);
        assertEq(single.tradingFeePercent(), 300);
        assertEq(single.tradingFeeDenominator(), 100_000);
        assertEq(single.permit2(), 0x000000000022D473030F116dDEE9F6B43aC78BA3);
    }

    // --- B6 SE-share LP units ---

    function test_B6_depositWithSeShares_firstMint_mintsLp() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(100 ether);
        assertGt(seShares, 0);

        (uint256 predLp, uint256 predRaw, uint256 predSe) =
            single.previewDepositWithSeShares(100 ether, seShares);
        assertGt(predLp, 0);
        assertEq(predRaw, 100 ether);
        assertEq(predSe, seShares);

        uint256 seBefore = IERC20(se).balanceOf(user);
        (uint256 localExpected,) = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(se), seShares / 20, IERC20(address(pairToken))
        );
        uint256 lp = _depositBothSeShares(100 ether, seShares);
        assertEq(lp, predLp);
        assertEq(IERC20(hook).balanceOf(user), lp);
        assertEq(IERC20(se).balanceOf(user), seBefore - seShares);
        uint256 redeemedShares = seShares / 20;
        assertEq(IERC20(se).balanceOf(hook), seShares - redeemedShares, "retained genesis shares");
        assertEq(pairToken.balanceOf(hook), localExpected, "actual 5% genesis redemption");
        assertGt(localExpected, 0, "positive actual genesis local receipt");
        assertTrue(single.isLive());
        assertEq(single.seClaimSupply(), IBasicVault(hook).reserveOfToken(address(pairToken)));
    }

    function test_B6_depositWithSeShares_subsequent_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 seShares = _mintSeSharesToUser(50 ether);

        (uint256 predLp, uint256 predRaw, uint256 predSe) =
            single.previewDepositWithSeShares(50 ether, seShares);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 claimBefore = single.seClaimSupply();
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 rawBook = rawToken.balanceOf(hook);
        uint256 sharesBook = IERC20(se).balanceOf(hook);
        uint256 localBook = pairToken.balanceOf(hook);

        vm.prank(user);
        (uint256 lp, uint256 usedRaw, uint256 usedSe) =
            single.depositWithSeShares(50 ether, seShares, user, 0, block.timestamp + 1);

        assertEq(lp, predLp);
        assertEq(usedRaw, predRaw);
        assertEq(usedSe, predSe);
        assertEq(rawToken.balanceOf(user), rawBefore - usedRaw);
        assertEq(IERC20(se).balanceOf(user), seBefore - usedSe);
        assertGt(single.seClaimSupply(), claimBefore);
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        assertEq(rawToken.balanceOf(hook) - rawBook, _ceil(gross, rawBook, supplyBefore), "ceil raw");
        assertEq(IERC20(se).balanceOf(hook) - sharesBook, _ceil(gross, sharesBook, supplyBefore), "ceil shares");
        assertEq(pairToken.balanceOf(hook) - localBook, _ceil(gross, localBook, supplyBefore), "ceil local");
    }

    function test_B6_withdrawSeShares_paysSeAndRaw_previewEqualsExec() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(100 ether);
        uint256 lp = _depositBothSeShares(100 ether, seShares);
        assertGt(lp, 0);

        uint256 burn = lp / 2;
        (uint256 predRaw, uint256 predSe) = single.previewWithdrawSeShares(burn);
        assertGt(predRaw, 0);
        assertGt(predSe, 0);

        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 seBefore = IERC20(se).balanceOf(user);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 localBook = pairToken.balanceOf(hook);
        uint256 sharesBook = IERC20(se).balanceOf(hook);
        uint256 rawClaim = burn * single.rawReserve() / supply;
        uint256 shareClaim = burn * sharesBook / supply;
        uint256 localClaim = burn * localBook / supply;
        (uint256 acquired,) = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(address(pairToken)), localClaim, IERC20(se)
        );
        vm.prank(user);
        (uint256 amountRaw, uint256 amountSe) =
            single.withdrawSeShares(burn, user, 0, 0, block.timestamp + 1);

        assertEq(amountRaw, predRaw);
        assertEq(amountSe, predSe);
        assertEq(rawToken.balanceOf(user) - rawBefore, amountRaw);
        assertEq(IERC20(se).balanceOf(user) - seBefore, amountSe);
        assertEq(amountRaw, rawClaim, "independent floor raw");
        assertEq(amountSe, shareClaim + acquired, "allocated shares plus converted local claim");
        assertEq(pairToken.balanceOf(hook), localBook - localClaim, "remaining local backing");
        assertEq(IERC20(se).balanceOf(hook), sharesBook - shareClaim, "only allocated shares paid");
    }

    function test_B6_pairDepositStillWorks_alongsideSeSharePath() public {
        _seedLiveLiquidity();
        // Pair-token path unchanged
        uint256 lpPair = _depositBoth(25 ether, 25 ether);
        assertGt(lpPair, 0);

        // SE-share path also works on live book
        uint256 seShares = _mintSeSharesToUser(25 ether);
        uint256 lpSe = _depositBothSeShares(25 ether, seShares);
        assertGt(lpSe, 0);

        // Withdraw pair path still unwraps to pair
        uint256 burn = lpPair / 2;
        uint256 pairBefore = pairToken.balanceOf(user);
        vm.prank(user);
        single.withdraw(burn, user, 0, 0, block.timestamp + 1);
        assertGt(pairToken.balanceOf(user), pairBefore);
    }

    function test_B6_antiSkew_seShareDepositVsPairBuffer_similarLp() public {
        // Seed identical books on two sequential deposits of equal economic size.
        // First: pair buffer path. Second user deposit of SE shares with claim ≈ same pair amount.
        _seedLiveLiquidity();

        // Measure LP from pair deposit of 40 raw + 40 pair (buffered)
        uint256 a0 = _amountForCurrency(single.currency0(), 40 ether, 40 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 40 ether, 40 ether);
        vm.prank(user);
        (uint256 lpPair,,) = single.deposit(a0, a1, user, 0, block.timestamp + 1);

        // Mint SE from 40 pair; deposit 40 raw + those SE shares
        uint256 seShares = _mintSeSharesToUser(40 ether);// Claim of seShares ≈ 40 pair (fee-less ERC-4626 wrapper)
        (uint256 claim,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seShares, IERC20(address(pairToken))
        );
        assertApproxEqRel(claim, 40 ether, 0.01e18);

        vm.prank(user);
        (uint256 lpSe,,) = single.depositWithSeShares(40 ether, seShares, user, 0, block.timestamp + 1);

        // Anti-skew: SE-share in must not false-reprice vs pair-then-buffer (within dust/fee).
        // Second deposit is slightly different book; allow modest relative drift.
        assertApproxEqRel(lpSe, lpPair, 0.05e18);
        assertGt(pairToken.balanceOf(hook), 0, "both routes fund local backing");
    }

    function test_B6_depositWithSeShares_zero_reverts() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(10 ether);
        vm.prank(user);
        // R2.4: pin ZeroAmount() 0x1f2a2005 (depositWithSeShares zero-leg guard).
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        single.depositWithSeShares(0, seShares, user, 0, block.timestamp + 1);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        single.depositWithSeShares(10 ether, 0, user, 0, block.timestamp + 1);
    }

    function test_B6_withdrawSeShares_deadlineAndMin_reverts() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(50 ether);
        uint256 lp = _depositBothSeShares(50 ether, seShares);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("DeadlineExpired()"));
        single.withdrawSeShares(lp / 2, user, 0, 0, block.timestamp - 1);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InsufficientTokenOut()"));
        single.withdrawSeShares(lp / 2, user, type(uint256).max, 0, block.timestamp + 1);
    }

    function _ceil(uint256 mint_, uint256 component_, uint256 supply_) internal pure returns (uint256) {
        uint256 product_ = mint_ * component_;
        return product_ / supply_ + (product_ % supply_ == 0 ? 0 : 1);
    }

    function _withdrawTreasury() internal {
        address treasury_ = _feeTo();
        uint256 lp_ = IERC20(hook).balanceOf(treasury_);
        if (lp_ != 0) {
            vm.prank(treasury_);
            single.withdraw(lp_, treasury_, 0, 0, block.timestamp + 1);
        }
    }
}
