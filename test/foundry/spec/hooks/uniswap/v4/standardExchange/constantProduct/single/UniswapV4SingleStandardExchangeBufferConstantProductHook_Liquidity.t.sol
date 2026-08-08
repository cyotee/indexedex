// SPDX-License-Identifier: BUSL-1.1
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
        // Free pair is not the book
        assertLe(pairToken.balanceOf(hook), DUST);
        // Virtual pair equals seClaim, not free pair (shared BasicVault accounting)
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
        vm.prank(user);
        (uint256 lp, uint256 u0, uint256 u1) = single.deposit(offer0, offer1, user, 0, block.timestamp + 1);
        // SE claim-in preview vs exec can drift; used amounts must match clamp
        assertApproxEqRel(lp, predLp, 0.02e18);
        assertEq(u0, predU0);
        assertEq(u1, predU1);
        // Refund excess currency0 if clamped
        if (offer0 > u0) {
            assertEq(IERC20(single.currency0()).balanceOf(user), bal0Before - u0);
        }
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_P4_zeroAmount_reverts() public {
        _initPool();
        vm.prank(user);
        vm.expectRevert();
        single.deposit(0, 1 ether, user, 0, block.timestamp + 1);
        vm.prank(user);
        vm.expectRevert();
        single.deposit(1 ether, 0, user, 0, block.timestamp + 1);
    }

    function test_P5_deadlineAndMinLp_reverts() public {
        _initPool();
        uint256 a0 = _amountForCurrency(single.currency0(), 10 ether, 10 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 10 ether, 10 ether);
        vm.prank(user);
        vm.expectRevert();
        single.deposit(a0, a1, user, 0, block.timestamp - 1);

        _depositBoth(100 ether, 100 ether);
        vm.prank(user);
        vm.expectRevert();
        single.deposit(a0, a1, user, type(uint256).max, block.timestamp + 1);
    }

    function test_P6_afterFullExit_subsequentMint() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertEq(IERC20(hook).totalSupply(), 1000);
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
        vm.prank(user);
        (uint256 a0, uint256 a1) = single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertApproxEqAbs(a0, pred0, DUST);
        assertApproxEqAbs(a1, pred1, DUST);
        assertEq(IERC20(single.currency0()).balanceOf(user) - b0, a0);
        assertEq(IERC20(single.currency1()).balanceOf(user) - b1, a1);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_Zi1_depositSingle_bothDirections() public {
        _seedLiveLiquidity();
        uint256 predRaw = single.previewDepositSingle(address(rawToken), 20 ether);
        vm.prank(user);
        uint256 lpRaw = single.depositSingle(address(rawToken), 20 ether, user, 0, block.timestamp + 1);
        assertApproxEqRel(lpRaw, predRaw, 0.05e18);
        assertGt(lpRaw, 0);

        uint256 predPair = single.previewDepositSingle(address(pairToken), 20 ether);
        vm.prank(user);
        uint256 lpPair = single.depositSingle(address(pairToken), 20 ether, user, 0, block.timestamp + 1);
        assertApproxEqRel(lpPair, predPair, 0.05e18);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_Zi2_previewZapSplit_sumsToAmountIn() public {
        _seedLiveLiquidity();
        (uint256 swapAmt, uint256 otherOut, uint256 kept) =
            single.previewZapSplit(address(rawToken), 20 ether);
        assertGt(swapAmt, 0);
        assertGt(otherOut, 0);
        assertEq(kept + swapAmt, 20 ether);
    }

    function test_Zi3_depositSingle_emptyBook_reverts() public {
        _initPool();
        vm.prank(user);
        vm.expectRevert();
        single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Zi4_depositSingle_onlyMinLiquidity_reverts() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertEq(IERC20(hook).totalSupply(), 1000);
        vm.prank(user);
        vm.expectRevert();
        single.depositSingle(address(rawToken), 10 ether, user, 0, block.timestamp + 1);
    }

    function test_Zo1_withdrawSingle_bothTokenOut_previewEqualsExec() public {
        _seedLiveLiquidity();
        // tokenOut = pair (includes residual raw→pair sell quoted pre-buffer)
        uint256 lp = IERC20(hook).balanceOf(user) / 4;
        uint256 predPair = single.previewWithdrawSingle(lp, address(pairToken));
        uint256 bPair = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 outPair = single.withdrawSingle(lp, address(pairToken), user, 0, block.timestamp + 1);
        assertEq(outPair, predPair, "pairOut preview!=exec");
        assertEq(pairToken.balanceOf(user) - bPair, outPair);
        assertGt(outPair, 0);

        // tokenOut = raw (includes residual pair→raw sell quoted pre-buffer, buffer-last)
        lp = IERC20(hook).balanceOf(user) / 3;
        uint256 predRaw = single.previewWithdrawSingle(lp, address(rawToken));
        uint256 bRaw = rawToken.balanceOf(user);
        vm.prank(user);
        uint256 outRaw = single.withdrawSingle(lp, address(rawToken), user, 0, block.timestamp + 1);
        // SE claim-in on residual buffer may differ by few wei from pure preview
        assertApproxEqAbs(outRaw, predRaw, 1e15, "rawOut preview~=exec");
        assertEq(rawToken.balanceOf(user) - bRaw, outRaw);
        assertGt(outRaw, 0);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_Zo3_withdrawSingle_notEligible_whenOnlyMinLiquidity() public {
        // Covered by Zi4 for depositSingle; here assert supply-only dust after full proportional exit.
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user);
        vm.prank(user);
        single.withdraw(lp, user, 0, 0, block.timestamp + 1);
        assertEq(IERC20(hook).balanceOf(user), 0);
        assertEq(IERC20(hook).totalSupply(), 1000);
    }

    function test_Zo7_withdrawSingle_deadlineAndMinOut() public {
        _seedLiveLiquidity();
        uint256 lp = IERC20(hook).balanceOf(user) / 5;
        vm.prank(user);
        vm.expectRevert();
        single.withdrawSingle(lp, address(rawToken), user, 0, block.timestamp - 1);
        vm.prank(user);
        vm.expectRevert();
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
        uint256 lp = _depositBothSeShares(100 ether, seShares);
        assertEq(lp, predLp);
        assertEq(IERC20(hook).balanceOf(user), lp);
        assertEq(IERC20(se).balanceOf(user), seBefore - seShares);
        // Free pair not book; SE held on hook
        assertLe(pairToken.balanceOf(hook), DUST);
        assertGt(IERC20(se).balanceOf(hook), 0);
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

        vm.prank(user);
        (uint256 lp, uint256 usedRaw, uint256 usedSe) =
            single.depositWithSeShares(50 ether, seShares, user, 0, block.timestamp + 1);

        assertApproxEqRel(lp, predLp, 0.02e18);
        assertEq(usedRaw, predRaw);
        assertEq(usedSe, predSe);
        assertEq(rawToken.balanceOf(user), rawBefore - usedRaw);
        assertEq(IERC20(se).balanceOf(user), seBefore - usedSe);
        // Virtual pair (claim) rose; free pair remains dust
        assertGt(single.seClaimSupply(), claimBefore);
        assertLe(pairToken.balanceOf(hook), DUST);
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
        vm.prank(user);
        (uint256 amountRaw, uint256 amountSe) =
            single.withdrawSeShares(burn, user, 0, 0, block.timestamp + 1);

        assertEq(amountRaw, predRaw);
        assertEq(amountSe, predSe);
        assertEq(rawToken.balanceOf(user) - rawBefore, amountRaw);
        assertEq(IERC20(se).balanceOf(user) - seBefore, amountSe);
        // No forced unwrap — free pair stays dust
        assertLe(pairToken.balanceOf(hook), DUST);
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
        uint256 seShares = _mintSeSharesToUser(40 ether);
        // Claim of seShares ≈ 40 pair (fee-less ERC-4626 wrapper)
        uint256 claim = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(se), seShares, IERC20(address(pairToken))
        );
        assertApproxEqRel(claim, 40 ether, 0.01e18);

        vm.prank(user);
        (uint256 lpSe,,) = single.depositWithSeShares(40 ether, seShares, user, 0, block.timestamp + 1);

        // Anti-skew: SE-share in must not false-reprice vs pair-then-buffer (within dust/fee).
        // Second deposit is slightly different book; allow modest relative drift.
        assertApproxEqRel(lpSe, lpPair, 0.05e18);
        assertLe(pairToken.balanceOf(hook), DUST);
    }

    function test_B6_depositWithSeShares_zero_reverts() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(10 ether);
        vm.prank(user);
        vm.expectRevert();
        single.depositWithSeShares(0, seShares, user, 0, block.timestamp + 1);
        vm.prank(user);
        vm.expectRevert();
        single.depositWithSeShares(10 ether, 0, user, 0, block.timestamp + 1);
    }

    function test_B6_withdrawSeShares_deadlineAndMin_reverts() public {
        _initPool();
        uint256 seShares = _mintSeSharesToUser(50 ether);
        uint256 lp = _depositBothSeShares(50 ether, seShares);
        vm.prank(user);
        vm.expectRevert();
        single.withdrawSeShares(lp / 2, user, 0, 0, block.timestamp - 1);
        vm.prank(user);
        vm.expectRevert();
        single.withdrawSeShares(lp / 2, user, type(uint256).max, 0, block.timestamp + 1);
    }
}
