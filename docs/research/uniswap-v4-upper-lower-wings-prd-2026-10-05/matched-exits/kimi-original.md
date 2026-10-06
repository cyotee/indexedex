# Wings matched exits — Kimi K3 original (independent round)

**Author:** Kimi K3. **Date:** 2026-10-05. Research authorized as matched-state analysis, NOT ratification. No peer artifacts read. No execution; all arithmetic hand-derived in reals with integer floors noted. Settled (not reopened): `R` custody only; `B = F + Σ owned D + Σ own E`; sleeve `F = p·D`; no entry balancing swap; exit swaps allowed; initiator pays operation fees.

**Identical entry for both options (matched):** internal geometric mint over `B` (`StandardExchangeConstantProduct.sol:58-64`): deposit `c` of token0 into book `(B0, B1)`, supply `S` ⇒ `K = sqrt(B0·B1)`, `K' = sqrt((B0+c)·B1)`, `m = S(K'−K)/K`, withdrawer fraction `f = m/(S+m) = 1 − sqrt(B0/(B0+c))`. Both exits are compared **from the same pre-withdrawal state** `(B0+c, B1, S+m)` — not against a pre-deposit benchmark (entry economics are settled by the entry rule).

**Shared quantities:** proportional entitlement `e0 = f(B0+c)`, `e1 = f·B1`; internal scalar quote (`_singleExit:98-111`) `q = e0 + (B0+c−e0)·e1/B1 = c` exactly in reals (same-token neutrality, carried proof); external proceeds `P = e0 + swap(e1)`.

## 1. Core matched-state results

**Option A — proportional removal + external swap.** Incumbent per-share token quantities are preserved **exactly** at the same state: post-exit supply returns to `S` and the book is scaled by `sqrt(B0/(B0+c))` in both legs (ratio unchanged, proportional removal). Incumbent per-share *value* at any fixed price is likewise identical before/after the exit (verified numerically below). Incumbent side effects are only: LP fees earned by the vault's remaining positions from the exit swap (E+, ordinary income); pool price movement caused by the exit swap re-pricing remaining deployed D (a market effect, zero under the deep-pool assumption); integer floor dust in their favor. **A is the same-state holder-preservation baseline.**

**Option B — internal scalar entitlement, externally settled.** The internal quote `q = c` systematically **exceeds** external proceeds after a same-token single-sided entry, because the entry itself skewed the internal conversion price in the withdrawer's favor (§3 shows the premium equals the entrant's own skew plus external fee). Therefore:
- **B-uncapped (pay q regardless of proceeds):** shortfall paid from backing ⇒ incumbent per-share loss — holder-preservation failure. Rejected.
- **B-capped (pay `min(q, P)`, withdrawer bears the difference; surplus `P − q > 0` to incumbent backing):** payout is **identical to A** whenever `P < q` — the common post-entry case. B differs from A only when execution outperforms the internal quote (`P > q`): A pays the upside to the withdrawer; B-capped pays `q` and keeps the surplus for holders.

**Consequence:** capped-B is "A plus upside capture with one quoting rule across idle/blocked"; it is not a distinct economic exit in the common case. The naive internal quote is never a safe payout promise after single-sided entry.

## 2. Balanced case with full ledgers (reals; assumptions: price 1:1, E=0, pool deep, exit swap fee 0.3%, no protocol fee)

Book `B0 = B1 = 1000`, `S = 1000`, deposit `c = 100` token0 ⇒ `m = 48.81` shares, `f = 4.654%`, `e0 = 51.19`, `e1 = 46.54`, `q = 100.00`, `P = 51.19 + 46.54·0.997 = 97.59`.

| Ledger | Entry | Exit A | Exit B-capped | (reference: internal exit) |
|---|---|---|---|---|
| Withdrawer | −100 T0, +48.81 sh | +97.59 T0 (net −2.41) | +97.59 (net −2.41) | +100.00 (net 0.00) |
| Incumbent per-share value | 2.0000 → 2.00227 | 2.00227 (unchanged) | 2.00227 | returns to 2.0000 |
| Pool LPs (incl. vault positions) | — | +0.14 fee | +0.14 | — |

Conservation: `100 = 97.59 + 2.27 (incumbents) + 0.14 (LPs)`. **Key fact:** the 2.27 entry impact is *realized as holder income only because the exit converts under a different price rule* (external market) than entry (internal average). A same-rule internal exit unwinds it exactly. Holder monetization of single-sided churn is therefore a **mode-choice property**, not an intrinsic one.

## 3. Skewed case (price at wing edge; concentrated divergence)

Market: token1 = 2.0 token0. Post-price-move book `B = (1400, 700)` (internal ratio equals market), `S = 1000`, deposit `c = 140` token0 ⇒ `m = 48.21`, `e0 = 70.83`, `e1 = 32.19`, `q = 70.83 + 1469.17·32.19/700 = 138.39`, external `P = 70.83 + 32.19·2·0.997 = 135.02`. The deposit skewed the internal token1 price 2.0 → 2.2; the internal quote embeds that skew (conversion executes through the remaining internal curve, `:106-110`), exceeding external proceeds by 3.37 (skew premium 3.18 + fee 0.19). Same verdict: capped-B ≡ A in payout; uncapped-B loses holder value. For concentrated books, `ratio(B) ≠ market` is structural (finite wings are piecewise one-sided; `LiquidityAmounts.sol:67-76`), so the skew premium recurs with volatility — bounded per operation by `|divergence|·size − impact`, recurring, not draining.

## 4. Regions, cover, blocked, bypass

- **Price in center:** wings dormant one-sided; analysis as §2. **Price inside a wing:** that wing two-sided, B composition shifted; §3 mechanics. **Outside the whole envelope:** all positions one-sided (`B1 = 0` or `B0 = 0`; PRD G3 supports the state). Internal geometric pricing degenerates (`K = 0`; forward path reverts arithmetically, inverse names `InsufficientBacking`, `:83-88`): same-side deposit/exit use the linear branch (`:50-51`) — economically clean; **missing-token entry/exit has no book price → named rejection** (any admission rule there is new economic design).
- **Blocked (outer unlock in session; PRD S3):** neither A nor B-settlement is executable — position removal and swaps need a session. Only the internal rule paid from `F` (cover-or-revert, D18/B4 `:156`). Note the asymmetry: blocked pays the **internal** (skew-favorable) price but is capacity-capped at `F` (`F = p·D` ≈ 1/6 of T at p = 0.2); zero cover ⇒ atomic revert, never partial burn.
- **Proportional bypass:** any holder can exit dual pro-rata (same-state neutral) and self-swap. This bounds every single-token exit rule: a single-token route paying materially less than `e0 + e1·market·(1−fee)` is dead code; A *is* the vault-performed version of the bypass; capped-B is the bypass with upside capture.

## 5. Repeated cycles and mode arbitrage

Per cycle at fixed prices (§2): A/capped-B cost the churner 2.41 = entry impact (to holders) + external fee (to LPs); bounded, no drain. **But** a same-state *internal* exit (blocked-mode) unwinds the entry impact, so a user who can choose the exit mode (including deliberately wrapping the exit inside an outer unlock to force the blocked branch) avoids the realization. Same-tx enter→exit at unchanged state is near-neutral (minus share-granularity floors and gas): no extraction is possible — transient same-state shares confer nothing (fees accrue through positions over time, not per-tx) — yet it means **holders monetize the entry impact only against users who exit externally or after state change**. Whether that optionality is acceptable is a product decision, not a bug: capacity (`F`) bounds blocked internal exits, and granularity/gas bound same-tx churn.

## 6. Separation of cost categories (no conflation)

- **Operation fees:** protocol usage/dex fees, charged once to the initiator (P3), quoted once.
- **Virtual entry impact:** paid to incumbents; realized only on external-rule exit or state change; formula-bounded (~`(c/B)²/8` leading term).
- **External execution cost:** swap fee + impact to pool LPs (partly the vault's own positions — ordinary LP income, not a second charge).
- **Gas:** A and B-settlement execute identical operations (removal + swap) — same gas; blocked internal exit cheapest (no unlock); entry internal has no composition-swap gas.
- **Rounding:** mint floor (granularity dominates small deposits, up to total loss at dust); entitlement floors and fee ceil favor incumbents; no universal wei-bound is claimed — bounds must be derived per formula and size, not asserted.

## 7. Conclusions discriminating the options

1. At the same pre-withdrawal state, **A is exactly holder-preserving** (quantities and value per share); it should be the benchmark any alternative is measured against.
2. **B is only viable payout-capped**, and then it is payout-identical to A in the common post-entry case, adding (i) one economic quoting rule across idle/blocked and (ii) surplus capture when execution outperforms the internal quote. Its marginal value over A is operational consistency plus upside capture, not better holder preservation.
3. **Uncapped internal-quote settlement is a holder-loss vector** (the quote embeds the entrant's own skew) and must not ship in any mode.
4. Blocked exits are necessarily internal-from-F, cover-or-revert; their skew-favorable pricing is capacity-limited, and mode optionality (§5) decides whether holders actually monetize single-sided churn.
5. Idle internal-priced exits would make same-state single-sided service ≈ free (neutral roundtrip): no drain, but no holder income either — a deliberate free-service design, not a compromise.

## 8. Residual questions for the owner (few, actionable)

1. Should idle single-token exits be market-converted (A/capped-B — entry impact becomes holder income) or internal-priced (same-state neutral — free scalar service)? P2's "may swap" permits both; this choice sets who bears skew risk.
2. If blocked exits keep internal pricing, is user mode choice (including forced nesting) acceptable given the `F` capacity cap, or should idle also offer an internal rule to remove mode arbitrage?
3. In capped-B, surplus on out-execution: to holders (capture) or to the withdrawer (A-equivalent)?
4. Minimum sizes for the granularity-dominated dust region, and named rejection for missing-token operations on one-sided books — confirm both as v1 domain law.

## 9. Honest scope

All cases hand-derived in real arithmetic; integer floors analyzed qualitatively (no exhaustive rounding proof); no simulation, tests, fork data, or chain measurements; assumptions stated per case (balanced/skewed prices, deep pool, 0.3% fee, E=0); concentrated-position repricing under real pool depth not simulated; mechanisms cited (`StandardExchangeConstantProduct.sol:49-64,78-111`; `LiquidityAmounts.sol:67-76`; wings PRD B3/B4/S1/S3/G3) are evidence of machinery, not of safety. P1–P3 analyzed for compatibility, not endorsed.
