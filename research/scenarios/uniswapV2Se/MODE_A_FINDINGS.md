# Mode A findings — Uni V2 Standard Exchange rate matrix

**Audience:** internal review (not marketing).  
**Date:** 2026-07-20  
**Tracked path:** `research/scenarios/uniswapV2Se/MODE_A_FINDINGS.md`  
**Artifacts (generated):** `research/out/uniswapV2Se/modeA_trade_{usdc,weth}/`  
**Reproduce:** `./research/run_mode_a.sh`  
**Data:** 24 trade steps each, identical hermetic init.

## Setup (shared)

| Item | Value |
|------|--------|
| Underlying | Uni V2 WETH/USDC, seed 10k WETH : 10M USDC |
| Init spot | 1000 USDC / WETH |
| SE vault | Half of circulating Uni LP deposited as shares |
| Balancer | 4 const-prod pools: rate ∈ {WETH, USDC} × pair ∈ {WETH, USDC} |
| Drive | Uni only (no Balancer swaps) |
| Book mark | Alice full exit: BPT → pair+shares → redeem SE → remove LP → mark USDC |

## One-sentence product story

**SE vault rates re-mark when Uni inventory tilts; Balancer markets that price those shares follow the rate target (with frozen Balancer inventory, mid index = rate₀/rateₜ).**

## Side-by-side end state (step 24)

| Metric | Market buys **WETH** (`modeA_trade_usdc`) | Market buys **USDC** (`modeA_trade_weth`) |
|--------|-------------------------------------------|-------------------------------------------|
| Uni USDC/WETH index | **1.00480** ↑ | **0.99522** ↓ |
| SE rate(WETH) index | **0.99761** ↓ | **1.00240** ↑ |
| SE rate(USDC) index | **1.00240** ↑ | **0.99761** ↓ |
| Identity `rateWeth × uni` | **= rateUsdc** (exact in sample) | **= rateUsdc** (exact in sample) |
| WETH-rated Balancer mid index | **1.00239** (≈ 1/rateWeth) | **0.99761** |
| USDC-rated Balancer mid index | **0.99761** (≈ 1/rateUsdc) | **1.00239** |
| Total P&L / start | **+0.479%** | **−0.477%** |
| Fee P&L (USDC units) | **+7.33** | **+7.29** |
| Fee / start book | ~0 (book is enormous) | ~0 |

## Charts to read (in order)

For each run dir:

1. **`rates.png`** — foundation. SE rate providers are the vault’s “price of a share.”
2. **`price_index.png`** — five markets. Same rate target ⇒ same path; opposite rate targets ⇒ opposite paths.
3. **`pnl_normalized.png`** — economics as fraction of start book (use this, not absolute `pnl.png` scale).
4. **`pnl.png`** — absolute USDC with fee panel isolated (green fee line).
5. **`inventory.png`** — full-exit token claims. Often ~flat in *qty* (see caveats).

## Mechanisms (why)

### When market buys WETH (we sell WETH from LP)

1. Uni holds more USDC, less WETH → **USDC/WETH spot rises**.
2. Each SE share claims **less WETH** and **more USDC** → `rate(WETH)↓`, `rate(USDC)↑`.
3. Cross-check: `rate(WETH) × (USDC/WETH) ≈ rate(USDC)` (share has one underlying claim).
4. Balancer live balances scale shares by rate. Frozen raw inventory ⇒  
   `mid_t/mid_0 = rate_0/rate_t` for that pool’s rate target.  
   So WETH-rated mids **rise** when rate(WETH) falls; USDC-rated **fall** when rate(USDC) rises.
5. USDC-marked book **rises** mostly because WETH is more expensive (price P&L), not because fees are large.

### When market buys USDC (mirror)

Opposite signs on every line above. Fees still **positive** (~7 USDC) while total USDC mark is **down** (~0.48%). That is the teaching case for “green fees, red total.”

## What Mode A already proves (SE foundation)

- [x] Uni trades alone re-mark SE rate providers.
- [x] Rate targets are consistent: `rateWeth * spot ≈ rateUsdc`.
- [x] Balancer share markets with frozen inventory track inverse rate for their rate target.
- [x] Pair token on Balancer does **not** change the *index* path (same rating ⇒ same path).
- [x] Maker fee accrual is positive under one-way flow but tiny vs directional mark on this book.
- [x] Reproducible hermetic runs + JSONL + plots.

## Caveats / research debt (learn before Mode C)

1. **Book scale** — full-exit mark is ~1e12 USDC (~1T) with ~99.9% WETH-by-value mix. Matrix **pair legs** dominate token qty vs the Uni LP inside the SE vault. Prefer **normalized** P&L and **rates** charts for intuition.
2. **Inventory chart** is a weak teaching tool for classic IL until we add a **vault-only / LP-only** mark series (future telemetry field).
3. **Fee as % of book** is meaningless at this scale; report fee in **absolute USDC** (and later: fee vs cumulative trade notional).
4. **One-way flow** maximizes directional price P&L; add a two-way / mean-reverting Mode A later to isolate fee income.
5. Do not treat ±0.48% as “APY” — it is a 24-step hermetic shock, not a yield product.

## Commands

```bash
# Re-plot both Mode A runs (no forge re-run needed if series.jsonl exists)
python research/plots/plot_all_mode_a.py \
  research/out/uniswapV2Se/modeA_trade_usdc \
  research/out/uniswapV2Se/modeA_trade_weth

# Regenerate data
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeUsdc.s.sol:Script_ModeA_TradeUsdc -vv
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth -vv
```

## Implications for Mode C (later)

Mode C should make Balancer mids **stop lagging** Uni/rates when arb fills. Today Mode C shows **zero fills** — after Mode A is solid, debug closer edge using the same rate/mid identity as the residual.

## Next Mode A polish (optional)

1. Telemetry: `vaultOnlyClaimWeth/Usdc` (redeem SE only, ignore Balancer pair legs).
2. Fee vs cumulative volume (bps of notional).
3. Alternating demand script (two-way flow).
4. Shrink matrix init pair sizes or plot per-share marks for cleaner slides.
