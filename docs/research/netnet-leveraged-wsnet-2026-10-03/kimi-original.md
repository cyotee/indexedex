# Kimi K3 — Leveraged wsNET-collateral / USDG-debt Morpho leg: independent first pass

**Scope.** Research only; no PRD/plan/code edits, no RPC/tests. Independent: no peer artifacts read (any round). Question: a leveraged leg posting wsNET collateral and borrowing USDG on NetNet's Loopback Morpho Blue market, as **one vault with two bound rate-provider valuations** ((1) wsNET safely withdrawable to a configured target LTV; (2) USDG additionally borrowable), token routes as implicit management directives; compatibility with the current NetNet–Pendle family vs separate design. PRD v0.36 read: `PkgArgs.standardExchangeVault` substitution (v0.36:22, R33/R55), whole-PkgArgs salt (:307), package-fixed hook (:291), and the standing rule that the in-scope Morpho alternative is **supply-only** — "not authorization to borrow or loop" (v0.36:172; `MorphoBlueStandardExchange_PRD.md` D6, §3 "Borrow / loop vault: separate package", §11 non-goals). Leverage is therefore **new, unselected scope**.

## 1. Verified building blocks (vendored 2026-08-28 dump; deployed-equivalence open, G1)

- **wsNET** (`perp/WrappedStakedNET.sol`): static 18-dec wrapper over rebasing 9-dec sNET; `ws = sNet×1e18/index`, `sNet = ws×index/1e18` (`:79–86`), permissionless wrap/unwrap, no owner. Foil: index moves only when staking **processes** a rebase.
- **Staking/Distributor**: `rebase()` permissionless after epoch end; distributes the queued amount, advances **one** epoch per touch, requests the next reward (`Staking.sol:129–150`). Dividend rate = `R_MAX × clamp((P−1)/(K−1),0,1)` over TWAP/backing premium, **0 on stale TWAP** (`Distributor.sol:43–102`); R_MAX 0.45%/8h-epoch, K=1.75 (survey:110–123, docs/strategies/ohm-style/2026-09-21-…md). Emissions are premium-driven: **at/below NAV the index is flat**.
- **Loopback market** (Morpho Blue, wsNET collateral / USDG loan): oracle `0xCDE9…5F16`, router `0x4638…7E17`, market id `0xaa58…0589` (docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md:103,119–120). **LLTV 62.5%**; LIF ≈ 12.7% chosen to clear the 5% sell tax (`LendingConstants.sol:24–32`); TurboRouter UX guardrail opens no position above **TARGET_LTV 53.125%** (85% of LLTV) — a policy cap, not a protocol cap.
- **LoopbackOracle** (`lending/LoopbackOracle.sol:52–76`): `price = clamp(TWAP×0.9, backingPerToken, 5×backingPerToken) × index`, scaled ×1e6 to Morpho's 1e36 convention (`LendingConstants.sol:36–39`). **Fail-closed** when the TWAP window is invalid or spot sits >15% below TWAP — and this pause hits **borrows and liquidations alike** (`:22–27`, `:58–64`). Immutable, no owner. Oracle credit is **not** an executable sale price (strategy research:159).
- **TurboRouter** (`lending/TurboRouter.sol`) is the working precedent for both directions using Morpho callbacks (no flash loan): `turbo` = supplyCollateral+callback → borrow → taxed USDG→NET pool buy → Zap(stake+wrap) → collateral (`:163–222`); `unwind` = repay+callback → withdrawCollateral → unwrap → unstake-loop → taxed NET→USDG sale → repay, surplus to caller (`:235–294`). It settles pending rebases first (bounded 8-iteration `_settleRebase`, `:296–308`) because unstaking advances ≤1 epoch per touch (`:265–275`). `_currentLtvWad` rounds debt up (`:313–324`).
- **Morpho Blue** (vendored v1.0.0, `external/morpho/blue`; singleton Robinhood `0x9D53…1010`, MorphoBlueSE PRD §6.1): `supply/withdraw/borrow/repay/supplyCollateral/withdrawCollateral/liquidate/flashLoan/setAuthorization/accrueInterest` (`IMorpho.sol:146–289`); borrow shares accrue via market `accrueInterest`; health checked at LLTV on borrow/withdrawCollateral; liquidation pays a LIF bonus at oracle price (Context7 `/llmstxt/morpho_llms_txt`, docs.morpho.org LTV/liquidation pages, accessed 2026-10-03). AdaptiveCurveIRM targets 90% utilization; rate floats with utilization (Context7, same date). Borrow/withdraw **revert** when market cash is insufficient (MorphoBlueSE PRD D23).
- **InverseBond**: 0.985×backing standing bid, 1%-of-liquid-treasury per 8h epoch cap, oracle-gated, shared public capacity (round-1 verified: `InverseBond.sol:68–140`).

## 2. Position accounting, W and H (unit-explicit)

State: collateral `c` (wsNET wei, 1e18), borrow shares `b_s`; market totals `B_a, B_s` (accrued). Oracle `p` (1e36-scale, USDG-raw per wsNET-wei).

```
D = ceil(b_s × B_a / B_s)                      [USDG raw, 1e6]  (TurboRouter.sol:317–320)
V = c × p / 1e36                               [USDG raw]
E = V − D                                      equity NAV, oracle-USDG terms
LTV = D / V (WAD); target λ configured (≤ LLTV; 53.125% precedent)
W = max(0, c − ceil(D × 1e36 / (λ × p)))       [wsNET wei] collateral withdrawable keeping LTV ≤ λ
H_credit = max(0, floor(λ × V) − D)            [USDG raw]
H = min(H_credit, marketCash)                  marketCash = totalSupplyAssets − totalBorrowAssets
```

**Relationships/nonadditivity (fact of the constraint):** at the boundary, `H + λ·p·W/1e36 = λV − D`. W and H are two projections of the *same* (c,D,λ) constraint; withdrawing collateral shrinks V and hence H; borrowing shrinks W. They are **management capacities, not value**, and `λV − D < E` for λ<1. Using either as NAV overstates; consuming both as independent backing double-counts. Zero-debt: W=c, H=λV. Underwater (V<D, reachable when debt interest outruns a flat/below-NAV index): W=H=0 and E<0 — the vault is insolvent at oracle terms even though Morpho may not yet liquidate.

**Share accounting (inference, standard single-position vault discipline):** shares claim **E**, never W or H. Issuance: `mint = inValue × S / E_pre` with E measured after accrual and on actual received collateral (reserve-delta crediting, MorphoBlueSE PRD D22 anti-donation precedent; A0 first-depositor test). Deposits into an underwater or above-target state must price at current E — issuance cannot "restore" target LTV; if E≤0 honest issuance is impossible (gate/pause/recapitalization semantics = explicit product decision). Redemption at fair value `E/S`: paying wsNET is bounded by the redeemer's share of W **and** raising survivors' LTV; paying USDG by new borrowing converts equity into debt owned by **the vault position — i.e., the remaining shareholders collectively** (Blue positions are per-`onBehalf`; no per-user debt transfer exists). Donated wsNET supplied `onBehalf` the vault raises V for all holders (K1); idle donated wsNET is not collateral until supplied. Dynamic LTV: W and H drift with every processed rebase (index↑ → p↑ → V↑) and every interest accrual (D↑) — previews must settle/accrue first (TurboRouter `_settleRebase` precedent) or quotes jump mid-transaction.

## 3. Routes as management directives (proposed matrix)

| Route | Effect | Binding constraint |
|---|---|---|
| NET in | Zap/stake→wrap→supplyCollateral (untaxed hops; TurboRouter composes `IZap.zap`, :26–28,211) | none (raises c, E; LTV falls) |
| sNET in | wrap→supplyCollateral | settle pending rebase first |
| wsNET in | supplyCollateral directly | — |
| USDG in | **repay debt** (deleverage; raises W,H,E per share) — or, alternatively selected, supply to a lending market | repay is the clean v1; supplying USDG to the *same* Loopback market the vault borrows from is self-referential reflexivity (decision) |
| wsNET out | withdrawCollateral | ≤ W; post-op LTV ≤ λ enforced by Morpho at LLTV and by policy at λ |
| USDG out | **borrow** (≤ H_exec; debt-financed payout) or unwind-sale proceeds | reverts if market cash short; survivors inherit the debt |
| NET/sNET out | composite unwind: withdrawCollateral→unwrap→unstake→(sell) | TurboRouter unwind precedent; taxed sale 5%+0.3%+impact, or IB within its 1%/epoch cap |

**Unwind endpoints:** partial (repay-then-withdrawCollateral, health checked at post-repay debt, TurboRouter.sol:260–262), full (repay all borrowShares; withdraw all collateral), and callback/flash compositions (`IMorpho.sol:228–273`) for atomic rebalance without pre-funding. **"Only-USDG without conversion" is unattainable** as the user suspects: collateral is wsNET; USDG payouts are either new debt (not conversion, but leverage) or require wsNET→sNET→NET→(taxed pool | InverseBond) conversion. Settlement reliability ordering: oracle V is backing-floored (never below B per unit) but **capped at 5×B** and TWAP-haircut; executable sale tracks spot minus tax/fee/impact; IB yields 0.985×B but only ~1% of liquid treasury per epoch, oracle-gated, publicly shared. In a dump, the divergence guard (>15% spot-below-TWAP) **fails closed and pauses liquidations too** (LoopbackOracle:22–27) — a bad-debt window for lenders and a stuck-position window for the vault.

## 4. Premise evaluation (no unconditional safety)

- "Rebase outgrows debt" is **regime-conditional**: dividend rate is 0 at/below NAV and maxes at 1.75× premium (`Distributor.sol:85–102`), while borrow cost floats with utilization toward 90% (AdaptiveCurveIRM, Context7 2026-10-03). Below NAV: flat index + compounding debt ⇒ LTV *rises* into the 62.5% LLTV wall. No APR or live-state claim is made here.
- Reflexivity: collateral value, protocol backing (POL leg), and the buyback floor all key off the same NET complex; a NET drawdown hits V, and liquidation sells wsNET into the same pool. The oracle's backing floor bounds *credit*, not *settlement*: forced sales clear at taxed market, possibly below B.
- Concentration: encumbering majority NET supply as collateral reduces float but **guarantees no price floor** — the buyback's capacity (~1% liquid reserves/epoch) is orders smaller than a majority-supply position, and strategy research:77 already records reduced supply as an objective, not a price proof. Liquidation of a concentrated position cascades through taxed thin liquidity; LIF 12.7% was sized to clear the 5% tax (`LendingConstants.sol:24–26`), not deep drawdowns.

## 5. One vault + two providers vs two claims; hook compatibility

- **One vault, one share class, equity-valued** is the only solvent reading. Providers (1) and (2) are legitimate as a **capacity/quote pair** (`maxWithdraw`-analog: rate uses full NAV, withdrawal caps conservative — MorphoBlueSE PRD D18/D27 precedent), with the valuation provider emitting **E per share in USDG**, and W/H exposed as separate management views. Two *value* feeds summed by a consumer = double-count (§2 identity). Two independent claim tokens/legs (wsNET-claim + USDG-claim) against one position: rejected — insolvency by construction.
- **Hook zero-rate/capability:** the family's four-leg Weighted hook consumes a USDG-targeted rate for the SE leg (v0.36:127). An equity rate can be 0 at empty state (existing provider returns 0 on empty supply, MorphoBlueSE PRD §8.3:267) and near-0 underwater; Weighted join/exit math behavior under a zero/vanishing leg rate is an **unverified engineering gate** (division/domain/imbalance-fee handling) — not claimed compatible. The leveraged vault also breaks the current common SE contract's assumptions (D23-style utilization reverts become LTV/liquidity/divergence-guard reverts; "truthful rate/limit/quote and atomic settlement" per v0.36:340 still applies).

## 6. Recommendation — bounded alternatives

- **A (recommended): separate, standalone single-position leverage vault package** (new PRD), not a third `standardExchangeVault` option under v0.36 (which is explicitly supply-only, :172). One share = equity E; v1 routes: NET/sNET/wsNET in; USDG in = repay-only; wsNET out ≤ W; USDG out ≤ H_exec; management ops (leverage-up loop à la TurboRouter, deleverage unwind) permissionless with a configured λ band; unwind paths via taxed pool and opportunistic IB within capacity; `_settleRebase`-style epoch settlement before quotes. Rate providers: one equity valuation + W/H capacity views.
- **B (defer): family-leg variant** — only after owner selection superseding the supply-only rule, zero-rate hook verification, and E18-style component binding work.
- **Explicit owner decisions:** λ (53.125% precedent vs lower); USDG-in = repay vs lend (same-market reflexivity); leverage-up loops in scope or passive collateral only; acceptance of the divergence-guard liquidation pause; underwater deposit policy; redemption revert-vs-pro-rata within λ; written acknowledgement that encumbered supply is not a price-floor guarantee.

## 7. Assumptions, confidence, gaps

Assumptions: dump ≡ deployed (G1 open); sNET index 9-dec (LoopbackOracle:73–75); Loopback market identity per strategy research:103; no live IRM/utilization/liquidity/capacity read. **Confidence:** high on mechanics/accounting identities; medium on route matrix details; low on live state. Primary sources: vendored files cited above; Context7 `/llmstxt/morpho_llms_txt` (docs.morpho.org LTV/liquidation/IRM pages, accessed 2026-10-03); docs.netnet.capital/treasury (accessed 2026-10-01, prior round); MorphoBlueStandardExchange_PRD.md (2026-08-22, D6/D13–D34); NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md:59–210; PRD v0.36:22,127,172,307,340. Versions: Morpho Blue v1.0.0 vendored; PRD v0.36; plan v0.10 (unchanged).
