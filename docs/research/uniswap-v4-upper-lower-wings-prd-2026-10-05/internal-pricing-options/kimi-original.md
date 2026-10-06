# Wings internal-pricing options — Kimi K3 original (independent bounded round)

**Author:** Kimi K3. **Date:** 2026-10-05. No peer artifacts read this round; own prior context reused cautiously (one retraction carried forward). No execution. PRD: `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.1). Mechanism evidence: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`. External semantics: Context7 `/uniswap/v4-core` (SwapMath.computeSwapStep; accessed 2026-10-05).

**Status of owner preferences (explicitly NOT ratified; analyzed for compatibility only):**
- **P1** AMM-style internal pricing for no-external-balancing-swap single-sided entry.
- **P2** Withdrawals may swap through the underlying pool.
- **P3** Initiating depositor/withdrawer bears operation fees.

**Settled (not reopened):** `R` = local custody only; `B = F + Σ owned D + Σ own E`; sleeve `F = p·D`, `D` = vault-owned deployed only; finite concentrated center/upper/lower.

## 1. Mechanism candidates mapped to evidence

- **Entry under P1:** invariant-growth mint, production-analog `_sharesForDeposit:58-64`: `K = ceil(sqrt(B0·B1))`, `K' = floor(sqrt((B0+c)·B1))`, `m = floor(S·(K'−K)/K)`; dual-leg offers use min-ratio (`:52-56`); min-ratio zero for single-sided (`C1=0 ⇒ m=0`) is the boundary P1 addresses.
- **Exit under P2:** pro-rata burn (each inventory component `floor(shares·component/S)`), withdraw pro-rata position liquidity, collect E→F once, then swap the opposing entitlement through the underlying pool (exact-in, fee scaled off input, mandatory price limit — SwapMath semantics). Blocked analog: internal `_singleExit:98-111` paid from F only, cover-or-revert.
- Carried-forward correction: concentrated `D` does **not** track the pool like a full-range CP book; `ratio(B) ≠ market` is the normal state, so every internal-price operation embeds a divergence transfer whose sign depends on deposit/exit token and ratio direction.

## 2. Concrete numerical roundtrip (entry internal → exit external)

**Assumptions (explicit):** balanced book `B0 = B1 = 1000` at pool price 1:1; `S = 1000`; `E = 0`, no accrual during the cycle; sleeve folded into B (F=0 base; §6 varies); external pool **deep** relative to the exit (46.5-unit swap costs fee only, 0.3%); no protocol usage fee unless stated; real arithmetic, then floor notes.

1. **Entry (P1):** deposit `c = 100` token0. `K' = sqrt(1100·1000) = 1048.81`; `m = 48.81` shares (4.654% of new supply 1048.81). Book `(1100, 1000)`.
2. **Mark immediately after entry (price 1):** depositor claim = 4.654% × 2100 = **97.73**. Entry virtual impact **2.27** = incumbent gain (per-share value 2.0000 → 2.00227). This is real compensation for a real risk transfer: the book is now token0-heavy; if token0 dumps, incumbents absorb more than their pre-entry share.
3. **Idle exit (P2):** burn 48.81 shares → pro-rata entitlement (51.19 token0, 46.54 token1); withdraw pro-rata liquidity; external exact-in swap 46.54 token1 → **46.40** token0 (0.3% fee, negligible impact in deep pool).
4. **Recovered: 51.19 + 46.40 = 97.59.** Roundtrip cost **2.41** = 2.27 (entry virtual impact → incumbents) + 0.14 (exit swap fee → pool LPs, **including the vault's own positions pro-rata to their active liquidity** — ordinary LP income, not a second charge on the withdrawer).
5. **Reference points:** internal entry + internal exit (`_singleExit` shape) is **exactly neutral** in reals (51.19 + 48.81 = 100.00; carried-forward proof). Internal entry + **dual pro-rata exit with no swap** returns (51.19, 46.54) — identical pre-swap. Integer share flooring (m floor) adds a granularity loss dominant at small sizes (0.987/4.987 ≈ 19.7% at 1%-of-book; corrected from my earlier "two impacts" framing).

**Consistency findings:**
- No profitable passive cycle at fixed prices (net −2.41); costs sit with the initiator (P3 satisfied).
- **Cross-mode asymmetry (the real design fact):** the 2.27 entry impact is only *realized* because the exit converts at a different price rule (external market) than entry (internal average). Same-mode internal-internal is neutral. Therefore under P1+P2 the entry impact is a genuine, bounded cost of instant single-sided service — it must be disclosed as such, and entry/exit pricing rules must be specified as one pair, never silently mixed (Astra's pairing warning, adopted).
- The pool fee earned by the vault's own positions during the exit swap is **paid ordinary LP income**, not custody theft; likewise any third party trading the pool pays the vault's liquidity. **Unbacked credit / extractive loss are a different category**: minting beyond formula, counting E twice, crediting F that includes the caller's own fresh funds as prior backing, or paying blocked exits from B rather than F — those are accounting bugs, not economics, and none is implied by P1–P3.

**Bounded vs draining:** entry impact is formula-bounded (`≈ value·(c/B)²/8` leading term); divergence extraction is bounded per operation by `|divergence|·c − impact(c)` but **recurs** with every price move (slow-bleed channel ∝ volatility × single-sided flow, not a one-shot drain); exit external swap is bounded by min-out/price-limit and pool depth. Nothing in P1–P3 is unbounded per transaction; the recurring bleed is the honest residual to price or gate (§4).

## 3. Exit-design alternatives compatible with P1–P3

- **E1 (P2-literal):** idle single-token exit = pro-rata removal + external swap, min-out guard; blocked = internal `_singleExit` from F, cover-or-revert. Simple; cross-mode cost (§2) is disclosed; idle/blocked quotes differ by construction and must say so.
- **E2 (paired internal-economic exit settled externally):** quote the single-token exit with the internal CP conversion over B (same rule as blocked), settle by pro-rata removal + external swap; execution-vs-quote difference attributed to the withdrawer (quote conservative; surplus stays as incumbent backing; shortfall beyond tolerance reverts). Advantages: one economic rule across idle/blocked, no mode-switch arbitrage, execution upgrades to market when the pool is deep. Cost: quote/execution divergence must be bounded and preview-conservative; same-state parity needs the conservative quote, not the optimistic execution.
- Rejected-by-complexity for v1 (owner may revive): virtual-reserve pricing bases (e.g. price over `D + min(F, targetFree)`). Any virtual base still requires the backing inequality on **real** B (`delivered_i·S ≥ m·B_i`); virtual pricing must never mint against inventory the vault does not hold.

## 4. Limits, reference gates, fees — options, not sufficiency claims

- **Size caps:** `c ≤ κ·B_i` bounds entry impact to ≈κ²/8 of book value; cap values are owner parameters, not proposed here.
- **Divergence/reference gate:** rejects single-sided ops when `ratio(B)` deviates from a reference beyond a band; a TWAP is a chosen risk model (window/units/failure behavior to be specified; prior council 25 bp/100 bp/30 min figures uncalibrated). A gate reduces the §2 bleed at the cost of route availability during volatility — do not assert any band suffices.
- **Entry/exit fee on the virtual conversion:** currently fee-free (`:8`); charging a trading-fee-equivalent to incumbents/protocol aligns no-swap and swap routes; fee proceeds' destination (incumbent backing vs feeTo) is a policy choice. None of these alone closes the bleed; they compose.

## 5. Fees vs impact vs gas vs later maintenance (no double charge)

- **Operation fees (P3):** protocol usage/dex fees per fee oracle, charged once to the initiator, quoted once.
- **Price impact:** entry virtual impact → incumbents (only realized cross-mode); exit real impact+fee → pool LPs (partly the vault's own positions). Distinct events, distinct payees; the roundtrip shows no double charge of the *same* cost.
- **Gas:** initiator pays their tx gas; internal entry avoids composition-swap gas; blocked ops avoid unlock gas.
- **Later maintenance:** placing deposited sleeve into positions (and placement losses) happens after the mint. Boundary to specify: if placement loss is borne by incumbents, large single-sided entries socialize it (secondary bounded leak); if anticipated and deducted from `C` before minting (aperture rule "caller-funded addition loss reduces C"), it is initiator-borne but must be quoted exactly once — never both. v1 default recommendation: deposited funds rest in F, maintenance is best-effort/permissionless with losses attributed per an explicit owner-approved rule, and the mint quote states which.

## 6. Edge states

- **One-sided backing (`B1 = 0`):** invariant formula degenerates (K=0; forward path reverts arithmetically, inverse names `InsufficientBacking`). Same-side deposit → existing linear branch `mulDiv(c, S, B0)` is economically clean (single-asset book, pro-rata claims). Missing-token deposit needs a price the book does not have → **named rejection** for v1; any admission rule for it is a new economic design (owner decision). Missing-token exit → zero entitlement, named rejection (never pays from the other side implicitly).
- **Blocked capacity:** entry while blocked rests in F and mints on B (fine); exit pays only F of the requested token — cover-or-revert before any burn; a quote on B is never capacity. Sleeve at `F = p·D` (≈1/6 of T at p=0.2) caps blocked single-token throughput regardless of the pricing rule.
- **Mixed states:** price inside a wing ⇒ that wing's D is two-sided; B aggregates all components with current-state finite-range math; orientation per `LiquidityAmounts.sol:67-76` (above price = token0, below = token1; PRD G1 orientation verified correct previously).

## 7. Few actionable choices for the owner

1. **Exit pairing:** E1 (P2-literal, external idle exit, disclose cross-mode entry impact) vs E2 (one internal pricing rule both modes, external settlement, withdrawer bears execution difference). This determines whether the §2 2.27-style entry impact is a real recurring cost (E1) or mostly theoretical (E2).
2. **Divergence bleed:** accept as priced AMM-style economics (possibly with size caps κ), or add a specified reference gate; a band value is *not* proposed here.
3. **Virtual-conversion fee:** fee-free vs trading-fee-equivalent, and its destination (incumbent backing vs feeTo).
4. **Placement-loss attribution for deferred deployment:** incumbent-borne (simple, socialized) vs initiator-borne via pre-mint deduction from C (quoted once).
5. **Missing-token domains:** confirm named rejection for missing-token single-sided entry/exit on one-sided books in v1.

## 8. Honest scope

All arithmetic hand-derived (real arithmetic; integer floors noted qualitatively); no simulation, tests, or fork data; P1–P3 analyzed for compatibility, not endorsed; no formula, cap, gate, or fee asserted sufficient; existing code cited as mechanism evidence only. Pool-depth and fee figures in §2 are stated assumptions, not measurements.
