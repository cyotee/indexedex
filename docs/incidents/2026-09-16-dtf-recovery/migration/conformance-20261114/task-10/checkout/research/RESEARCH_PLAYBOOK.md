# IndexedEx Strategy Performance Research Playbook

**Purpose:** how we research, document, and plot vault / DETF behavior so *we* understand it, can explain it to others, and can reuse clean charts in marketing.

**Audience:** protocol builders first; marketing second. Every marketing chart should be a subset of a research chart that has a written interpretation.

**Status (2026-07-19):** Mode A (Uni-only drive) and Mode C (Uni + Balancer arb closer) exist for Uni V2 Standard Exchange + Balancer rate matrix. DETF research is not started. This playbook is the north star; `research/README.md` is the runbook for what already works.

---

## 1. What we are actually trying to learn

IndexedEx products are **not** “black box yield farms.” They re-mark claims through:

1. **Underlying market** (Uni / Aero / Camelot / Aave / …)
2. **Standard Exchange vault shares** (LP → share rate providers)
3. **Balancer markets on those shares** (const-prod / weighted / stable / DETF reserve)
4. **Optional seigniorage / bond / claim** (DETF layer)

Research answers three layers of questions:

| Layer | Question | Output |
|-------|----------|--------|
| **Mechanics** | *Why* does price / inventory move this way? | Pedagogical charts + short captions |
| **Economics** | *Who* earns/loses under which flow? Fees vs price vs arb? | Attribution P&L panels |
| **Product story** | *What* should a depositor / LP / DETF minter expect? | Marketing-safe charts with locked framing |

If a chart cannot answer at least one of those, drop it.

---

## 2. Industry practice we should borrow (mapped to us)

### 2.1 Separate market risk from strategy “alpha”

AMM research (esp. **LVR — Loss Versus Rebalancing**, a16z / Milionis et al.) shows that raw LP P&L is almost entirely **price beta**. The interesting number is small:

- **Fees earned**
- minus **adverse selection / LVR** (being picked off by better-informed flow)
- optionally vs a **rebalancing / hold** benchmark

Our Mode A P&L already does a useful cousin of this:

| Our series | Closest industry idea |
|------------|----------------------|
| **Asset price P&L** | Hold t0 claim at live prices − start (LVH-like price mark) |
| **Fee P&L** | Full exit − hold(t0 claim) ≈ maker fees + claim qty drift |
| **Total P&L** | Full-exit value − start |

**Rule:** never put fee P&L and price P&L on one axis when price is 1e9× larger (we already split panels — keep that).

**Later upgrade (not urgent):** true **LVR / delta-hedged LP** series for Uni-only book, then for SE vault, then for Balancer BPT book. That is the marketing-grade “strategy alpha” line.

### 2.2 Scenario simulation over blind historical backtests

Portfolio / strategy literature: prefer **designed scenarios** (stress, one-factor moves, regime stories) over a single historical path when the goal is *understanding*. History is for validation once mechanics are clear.

We already do this: hermetic Foundry scripts with fixed init + one demand direction.

### 2.3 Vault dashboards (Yearn / Morpho / Gauntlet) — product layer

Public vault products emphasize:

- Net APY / fee take
- Risk / stress narrative (“withstood withdrawals”)
- Exposure composition
- Transparent methodology

For us, **methodology transparency is the product differentiator.** Every chart folder should have `meta.json` + a 5-line interpretation in a `NOTES.md` (see §6).

### 2.4 Pedagogical chart design

Good educational finance charts:

1. **One story per figure** (or stacked panels with shared x-axis)
2. **Labeled end values** (we do this on price indices)
3. **Raw market direction** (no cosmetic invert) — **locked for us**
4. **Caption that states the causal mechanism**, not just “line went up”
5. **Baselines** at 1.0 (price index) or 0 (P&L)

---

## 3. Where we stand today

### 3.1 Pipeline (keep this architecture)

```
Foundry research script (production contracts, hermetic)
  → ResearchTelemetry JSONL + meta.json
  → Python plot_*.py
  → research/out/<product>/<runId>/{series.jsonl,meta.json,*.png}
```

| Piece | Role |
|-------|------|
| `scripts/foundry/research/harness/ResearchTelemetry.sol` | Append-only JSONL writer |
| `ResearchFixture_UniswapV2SeRateMatrix.sol` | Uni V2 SE + 4 Balancer CP pools (rate × pair matrix) |
| Mode A scripts | Uni demand only; sample five markets |
| Mode C scripts | Uni demand + Balancer arb closer |
| `research/plots/plot_price_series.py` | Relative bar-ratio indices |
| `research/plots/plot_pnl.py` | USDC full-exit attribution |

### 3.2 Locked chart conventions (do not reopen casually)

See `research/README.md`. Summary:

- Framing = **market demand against our liquidity**, not “we sell X”
- Uni = raw **USDC/WETH** index
- Balancer = raw **mid = pair / liveShares**, index `mid_t/mid_0`
- **No display invert** by default
- WETH-rated mids **with** Uni; USDC-rated **opposite**
- Price charts ≠ USD; P&L is separate full-exit USDC mark

### 3.3 Known gaps / open findings

1. **Mode B** (drive Balancer markets first) listed as later — still needed for “why Balancer mid moves when we trade it.”
2. **Mode C arb fills currently 0** in `modeC_market_buys_usdc` (same total P&L as Mode A twin). Closer may be edge-starved, profit-token/framing mismatch, or inventory not creating fillable arb for alice’s book. **Investigate before marketing Mode C.**
3. **Portfolio scale** is huge (full-exit of all matrix positions); charts work but human-readable USDC should be normalized (per 1 share / per $1 deposited) for marketing.
4. **No DETF research path yet** (synthetic price, mint/burn gates, bond → live, claim redeem).
5. **No written interpretation files** next to PNG outputs — charts alone confuse non-authors.

---

## 4. Research ladder (simplified → product-complete)

Work **down the ladder**. Do not jump to Monte Carlo / multi-protocol until the step above has a one-paragraph “we understand this” note.

### Tier 0 — Toy identities (optional pure math / unit plots)

**Goal:** prove labels and rate identity without LP drama.

| Scenario | Drive | Assert |
|----------|-------|--------|
| T0.1 Frozen Balancer inventory | Change only rate provider input | `mid_t/mid_0 = rate_0/rate_t` |
| T0.2 Same rate target, different pair | Same Uni path | **Identical** index paths |
| T0.3 Opposite rate targets | Same Uni path | **Mirror** indices |

*Status:* Mode A already demonstrates T0.2–T0.3 empirically. A one-step unit script would make T0.1 bulletproof for docs.

### Tier 1 — Standard Exchange as LP wrapper (Mode A — **done core**)

**Goal:** “SE vault shares re-mark when underlying Uni is traded.”

| Scenario | Market story | Learning |
|----------|--------------|----------|
| A.USDC demand | Market buys WETH from our Uni LP | Uni USDC/WETH ↑; WETH-rated with Uni; fees + inventory P&L |
| A.WETH demand | Market buys USDC from our Uni LP | Uni ↓; USDC-rated rise; price P&L can dominate fees |

**Charts (existing):** `price_index.png`, `pnl.png`.

**Add for clarity:**

- `share_rate.png` — vault rate(WETH) and rate(USDC) indices alone
- `inventory.png` — exit claim WETH / USDC over time (shows IL-like inventory shift)
- Normalized P&L per 1e18 initial USDC of portfolio0

### Tier 2 — Cross-market consistency (Mode C — **in progress**)

**Goal:** “When Uni moves and Balancer lags, does arb close the gap, and who captures it?”

| Scenario | Learning |
|----------|----------|
| C after Uni demand | Arb profit in traded/profit asset; mid indices should snap toward no-arb |
| C with intentional lag (skip arb N steps) | Divergence then catch-up — best *teaching* chart |

**Required before marketing Mode C:** non-zero arb fills on at least one scripted path, or a written reason fills are zero.

### Tier 3 — Balancer as primary drive (Mode B — **todo**)

**Goal:** “Trading the SE-share pool moves vault inventory and rates without Uni volume.”

Drive each matrix pool (exact-in pair ↔ shares), sample Uni + all rates. Compare to Mode A.

### Tier 4 — User roles (who is the chart about?)

Same world state, **different books**:

| Book | Valuation |
|------|-----------|
| **Uni LP holder** (outside SE) | Classic LP exit |
| **SE vault shareholder** | Redeem → LP → tokens |
| **Balancer BPT holder** | Proportional exit → pair + shares → … |
| **DETF holder** | Synthetic / burn / claim path (Tier 5) |

Marketing almost always wants **one book** per figure.

### Tier 5 — DETF (not started)

Build on SE fixtures; never subclass brand-specific DETFs. Use role names (`rateAsset`, `vaultShare`, `detfToken`, …).

| Scenario family | Question |
|-----------------|----------|
| D.inert | Pre-live mint blocked; first bond → live |
| D.mint_gate | Synthetic > mintThreshold; preview == execution |
| D.burn_gate | Synthetic < burnThreshold |
| D.price_via_underlying | Real SE/Uni trades move synthetic (default ±5% thresholds) |
| D.seigniorage_dilution | Mints increase supply vs reserve claim |
| D.bond_claim | Lock clamp; sell NFT → rebasing claim; redeem → rateAsset |
| D.multi_vault | Distinct legs keep distinct valuations (weighted multi) |

**Charts:**

- Synthetic price vs 1.0 peg + threshold bands
- Reserve composition (stacked area of rate-scaled balances)
- Mint/burn allowed regions (green/red bands)
- DETF holder P&L vs hold rateAsset / vs hold vault shares

### Tier 6 — Stress / regimes (later)

| Regime | Drive |
|--------|-------|
| One-way trend | Continuous demand one side (Mode A×N) |
| Mean-reverting | Alternate demand |
| Shock | 1-step large trade then rest |
| Volume vs size | Same notional, more smaller trades (fee vs impact) |
| Nested SE | DETF-on-DETF or dual-liquidity legs |

### Tier 7 — Live / fork validation (last)

Fork Base (or target chain), sample real pools with the **same telemetry schema**. Only after hermetic stories are solid.

---

## 5. Chart catalog (what to plot, for whom)

### 5.1 Understanding (internal + docs)

| Chart ID | Content | Audience |
|----------|---------|----------|
| **P1** Price indices (5 markets) | Existing `price_index.png` | Core mechanics |
| **P2** Rate providers only | rateWeth / rateUsdc indices | “Why mids move” |
| **P3** Inventory / claim | exitClaim WETH & USDC | IL intuition |
| **P4** P&L attribution | Existing 3-panel `pnl.png` | Economics |
| **P5** Mid vs rate identity | scatter or dual axis | Audit / paper |
| **P6** Arb fill | cumulative arb profit + fills | Mode C debug |
| **P7** Gap to no-arb | Balancer mid vs Uni-implied | Mode C teaching |

### 5.2 Explaining to others (deck / README)

Same as P1–P4 but:

- Normalize to start = $1 or 1 share
- One demand direction per slide
- Caption template (see §6)
- Drop matrix labels for plain English on first slide:

  > “When traders buy WETH from our pool, the vault’s WETH rate rises and Balancer markets that treat shares as WETH reprice with it.”

### 5.3 Marketing (subset only)

**Safe to market when:**

1. Hermetic run is reproducible (`forge script` + plot commands in `meta.json` or NOTES)
2. Framing is LP/market-demand or depositor-book (not “guaranteed APY”)
3. Fee and price risk are not conflated
4. Caption includes **scenario conditions** (init spot, trade size, steps)

**Recommended marketing pack (SE vault):**

1. Two price-index charts (buy WETH / buy USDC) — “rates follow underlying”
2. One fee-positive panel under two-way flow (if we add alternating Mode)
3. One “full exit still recovers tokens” inventory chart (no yield claim without fees)

**Avoid until solid:** Mode C arb edge, DETF mint APY, any APR without volume assumption.

---

## 6. Documentation standard (every run)

Create next to outputs:

```
research/out/<product>/<runId>/
  meta.json          # machine
  series.jsonl       # machine
  price_index.png
  pnl.png
  NOTES.md           # human (required for “done”)
```

### `NOTES.md` template

```markdown
# <runId>

## One-line story
<e.g. Market buys USDC from our Uni LP for 24 steps; Balancer inventory frozen.>

## Setup
- Product: Uni V2 SE WETH/USDC + 4 Balancer CP share pools
- Init: 1 WETH = 1000 USDC; TRADE_*; half LP in vault
- Drive: <script name>
- Book: alice full matrix BPT + residual free LP settlement

## What the price chart shows
1. ...
2. ...

## What the P&L chart shows
- Price P&L: ...
- Fee P&L: ...
- Total: ...

## Why (mechanism)
<rate provider → liveShares → mid = pair/liveShares>

## Caveats
- Hermetic; not live APY
- Full portfolio mark, not per-share
- ...

## Commands
\`\`\`bash
forge script ...
python research/plots/...
\`\`\`
```

### Research log

Append one row per completed scenario to `research/SCENARIO_LOG.md` (product, mode, status, path, one-line finding).

---

## 7. Metrics dictionary (use these names everywhere)

| Name | Definition | Unit |
|------|------------|------|
| `uniSpot_USDCperWETH` | Uni reserve ratio USDC/WETH | 1e18 |
| `uniPriceIndex` | spot_t / spot_0 | 1e18 |
| `rateWeth` / `rateUsdc` | SE rate provider | native |
| `*_midRaw` | Balancer pair / liveShares | 1e18-ish |
| `*_index` | mid_t / mid_0 | 1e18 |
| `portfolioExitUsdc` | Full unwind mark | 1e18 USDC |
| `pricePnlUsdc` | hold(claim0 @ live) − portfolio0 | 1e18 |
| `feePnlUsdc` | exit − hold(claim0) | 1e18 |
| `totalPnlUsdc` | exit − portfolio0 | 1e18 |
| `arbProfit` / `fills` | Mode C step stats | profit token |

**Normalized (add in Python, not Solidity):**

- `pnl_per_start = totalPnl / portfolio0`
- `fee_bps_of_notional` vs cumulative trade volume

---

## 8. How to run a research session (operating procedure)

1. **State the question in one sentence** before coding.
2. **Pick the lowest tier** that can answer it.
3. **One drive variable** per run (direction of demand, or which pool).
4. **Fresh hermetic bootstrap** per script (current pattern).
5. **Export** via `ResearchTelemetry` only (no ad-hoc console parsing for plots).
6. **Plot** with existing Python; add a new plot script only if a new *kind* of chart.
7. **Write NOTES.md** before declaring success.
8. **If confused by a chart**, simplify (fewer pools, one step, print rates) — do not add features.

### Anti-patterns

- Marketing APY from a one-way shock run
- Display-inverting prices so “everything goes up”
- Mixing alice’s book with arb agent’s book without labeling
- Mocking SE / DETF / manager in research (production-first)
- Giant multi-mode scripts that recompile the world for a label change

---

## 9. Suggested work order (drive this, not the other agent’s sprawl)

### Phase 1 — Consolidate understanding (Mode A polish) — **done 2026-07-20**

1. ~~Mode A NOTES + findings~~ → `research/scenarios/uniswapV2Se/` (tracked).
2. ~~Plot pack~~ → `research/plots/plot_all_mode_a.py`.
3. ~~Reproduce runners~~ → `./research/run_mode_a.sh`, `stamp_meta.py`, enriched `meta.json`.
4. ~~`SCENARIO_LOG.md`~~.

**Optional Mode A follow-ups:** vault-only claim telemetry; fee vs volume; two-way demand script.

### Phase 1b — Reconstructability (Session A) — **done 2026-07-20**

- Tracked narrative under `research/scenarios/`
- Generated artifacts only under `research/out/` (gitignored)
- One-command Mode A/C runners + git-stamped meta

### Phase 1c — Mode C (Session C) — **done core 2026-07-20**

- Closer Permit2 buy path aligned with test harness
- Probe diagnostics in series.jsonl
- **Result:** `modeC_market_buys_usdc` — fills=0 and maxBuy/SellProbe=0 all steps; P&L matches Mode A twin
- Finding: rate providers leave no free Balancer residual after Uni-only demand under default fees/params
- Mirror run `modeC_market_buys_weth` optional; Mode B if we need a fills&gt;0 closer demo

### Phase 2 — Teaching pack (SE)

1. Tier 0 identity mini-script or assert in fixture.
2. Mode B: one Balancer pool exact-in series.
3. Dual-direction / mean-reverting Mode A for “fees without large directional IL.”
4. Slide-ready captions in `research/docs/SE_RATE_MATRIX_EXPLAINER.md`.

### Phase 3 — DETF research harness

1. Fixture from Single SE DETF gold TestBase (production deploy path).
2. Scenarios D.inert → D.mint/burn gates → D.price_via_underlying.
3. Charts: synthetic + thresholds; holder P&L vs rateAsset hold.

### Phase 4 — Multi-product + live

1. Aero / Camelot SE same Mode A matrix (protocol ports).
2. Fork validation with same JSONL schema.
3. Optional LVR / hedged-LP series for academic-grade alpha.

---

## 10. Success criteria

We are “done enough” for a product family when:

- [ ] Every core scenario has `series.jsonl` + plots + `NOTES.md`
- [ ] A new engineer can reproduce charts from README alone
- [ ] We can answer in plain English: *what happens when market buys X*
- [ ] Fee income is visible **separately** from directional price risk
- [ ] Marketing deck uses only charts that pass §5.3
- [ ] DETF: inert→live, gates, and one real underlying price move under default thresholds

---

## 11. References (external ideas, not dependencies)

- a16z crypto: *LVR — Quantifying the Cost of Providing Liquidity* (fees vs adverse selection; hedged LP)
- Milionis et al.: Automated Market Making and Loss-Versus-Rebalancing
- Gauntlet / Morpho vault market reports: stress + withdrawable liquidity narrative
- Yearn Curation: publish methodology + risk, not just APY
- Scenario / stress design over single historical backtests (portfolio optimization practice)

---

## 12. Relation to code paths

| Path | Owns |
|------|------|
| `research/README.md` | How to run existing Mode A/C |
| `research/RESEARCH_PLAYBOOK.md` | This file — goals, ladder, chart catalog |
| `research/plots/` | Offline plotting |
| `research/out/` | Artifacts (gitignored) |
| `scripts/foundry/research/` | Hermetic production-first experiments |
| Family PRDs under `contracts/vaults/detf/**` | Normative DETF product rules |

When playbook and PRD conflict on product rules, **PRD wins**. When playbook and an old plot convention conflict on chart framing, **locked conventions in README win** until explicitly revised here.
