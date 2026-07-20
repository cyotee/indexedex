# IndexedEx research harness

Production-first experiments as **Foundry scripts** (not tests): drive real vaults/pools, sample views after each step, export JSONL, plot offline.

| Doc | Role |
|-----|------|
| [`RESEARCH_PLAYBOOK.md`](./RESEARCH_PLAYBOOK.md) | Why / scenario ladder / chart catalog |
| [`SCENARIO_LOG.md`](./SCENARIO_LOG.md) | Index of completed runs |
| [`scenarios/`](./scenarios/) | **Tracked** narrative (findings + per-run notes) |
| `out/` | **Generated** JSONL + PNGs (gitignored) — recreate with runners |

## Reproduce Mode A (primary)

From **repo root**:

```bash
./research/run_mode_a.sh
```

Uses `FOUNDRY_PROFILE=default` (via_ir off). The `[profile.research]` via_ir path currently fails on Uniswap V4 `LiquidityAmounts` stack depth — do not force it for these scripts.

Runs both Uni demand directions, stamps `meta.json` (git commit, forge version, script id), and builds the full plot pack.

| Flag | Effect |
|------|--------|
| `--plot-only` | Replot existing `series.jsonl` (no forge) |
| `--data-only` | Forge + stamp only (no plots) |

### Expected end metrics (sanity check)

After a successful run, step-24 indices should be **near** (hermetic; tiny drift OK):

| Metric | `modeA_trade_usdc` (market buys WETH) | `modeA_trade_weth` (market buys USDC) |
|--------|----------------------------------------|----------------------------------------|
| Uni USDC/WETH index | ~**1.00480** | ~**0.99522** |
| SE rate(WETH) index | ~**0.99761** | ~**1.00240** |
| SE rate(USDC) index | ~**1.00240** | ~**0.99761** |
| Identity | `rateWeth × uni ≈ rateUsdc` | same |
| Total P&L / start | ~**+0.479%** | ~**−0.477%** |
| Fee P&L | ~**+7.3 USDC** | ~**+7.3 USDC** |

Full writeup: [`scenarios/uniswapV2Se/MODE_A_FINDINGS.md`](./scenarios/uniswapV2Se/MODE_A_FINDINGS.md).

### Chart review order (each Mode A run)

1. `rates.png` — SE rate providers vs Uni  
2. `price_index.png` — five markets  
3. **`index_vs_fairness.png`** — slopes can differ while fairness residuals ≈ 0 (see [`scenarios/uniswapV2Se/INDEX_VS_FAIRNESS_EXPLAINER.md`](./scenarios/uniswapV2Se/INDEX_VS_FAIRNESS_EXPLAINER.md))  
4. `pnl_normalized.png` — book-relative P&L  
5. `pnl.png` — absolute + fee panel  
6. `inventory.png` — full-exit claims (often flat qty; see findings)

### Layout (reconstruction contract)

```text
research/
  run_mode_a.sh / run_mode_c.sh     # one-command reproduce
  scenarios/uniswapV2Se/            # TRACKED narrative
    MODE_A_FINDINGS.md
    modeA_trade_usdc.md
    modeA_trade_weth.md
    MODE_C_FINDINGS.md              # after Mode C
  plots/                            # TRACKED plotters + stamp_meta.py
  out/uniswapV2Se/<runId>/          # GENERATED (gitignored)
    meta.json                       # params + gitCommit after stamp
    series.jsonl
    *.png

scripts/foundry/research/           # TRACKED forge drivers
  harness/ResearchTelemetry.sol
  uniswapV2Se/...
```

**Rules:** narrative + code in git; `out/` is regenerated. Do not treat gitignored PNGs as source of truth.

---

## Mode A — Uni V2 Standard Exchange rate matrix

**Question:** How do Uni V2 trades re-mark Balancer constant-product markets on SE vault shares when rate target × pair token vary?

| Setting | Value |
|---------|--------|
| Underlying | Uni V2 **WETH/USDC** |
| Initial spot | **1 WETH : 1000 USDC** |
| Drive | Uni V2 **only** (no Balancer swaps) |
| Share mint | Uni V2 **LP → SE deposit** (no single-token zap) |
| Balancer inventory | Equal raw shares × 4; pair sized to Uni ratio at init |

### Spot convention

| Market | Spot | Stored index |
|--------|------|----------------|
| Uni V2 | **USDC / WETH** | `spot_t / spot_0` |
| Balancer | **mid = pair / liveShares** | `mid_t / mid_0` |

With frozen Balancer inventory: `mid_t / mid_0 = rate_0 / rate_t` for that pool’s rate target.

- **Same rate target** ⇒ **same** Mode A path  
- **WETH-rated vs USDC-rated** ⇒ **opposite** paths when Uni tilts  

### Pitch framing (LP / market demand)

| Artifact dir | External flow | LP framing |
|--------------|---------------|------------|
| `modeA_trade_usdc` | USDC → WETH on Uni | **Market buys our WETH** |
| `modeA_trade_weth` | WETH → USDC on Uni | **Market buys our USDC** |

### Chart convention (locked)

**Do not reintroduce display invert / “price always up” pitch orientation.**

| Rule | Detail |
|------|--------|
| Framing | LP / **market demand** against our Uni liquidity |
| Uni series | Raw **USDC/WETH** index |
| Balancer series | Raw **bar ratio** `mid_t/mid_0` |
| No invert | Default = market direction as stored |
| Colors | Black = Uni · blue/cyan = WETH-rated · red/orange = USDC-rated |
| Price vs P&L | Price = bar ratios; P&L = full-exit USDC (prefer normalized) |

### Portfolio P&L (USDC)

Full exit mark (snapshot/revert): Balancer → redeem SE → remove Uni LP → mark USDC at live spot.

| Series | Definition |
|--------|------------|
| **Asset price P&L** | Value of t0 token claim at live prices − portfolio₀ |
| **Maker fees + claim change** | Full-exit value − hold(t0 claim) |
| **Total P&L** | Full-exit value − portfolio₀ |

### Manual Mode A (without runner)

```bash
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth -vv
forge script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeUsdc.s.sol:Script_ModeA_TradeUsdc -vv
python research/plots/stamp_meta.py research/out/uniswapV2Se/modeA_trade_weth \
  --script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeWeth.s.sol:Script_ModeA_TradeWeth
python research/plots/stamp_meta.py research/out/uniswapV2Se/modeA_trade_usdc \
  --script scripts/foundry/research/uniswapV2Se/Script_ModeA_TradeUsdc.s.sol:Script_ModeA_TradeUsdc
python research/plots/plot_all_mode_a.py \
  research/out/uniswapV2Se/modeA_trade_weth \
  research/out/uniswapV2Se/modeA_trade_usdc
```

---

## Mode C — Uni demand + Balancer arb closing

Same init as Mode A; after **each** Uni trade a standalone closer (`ResearchModeCCloser`) tries to capture Balancer edge in the profit asset.

```bash
./research/run_mode_c.sh
```

| Script | Market buys | Arb profit asset | Artifact dir |
|--------|-------------|------------------|--------------|
| `Script_ModeC_MarketBuysUsdc` | USDC | WETH | `modeC_market_buys_usdc/` |
| `Script_ModeC_MarketBuysWeth` | WETH | USDC | `modeC_market_buys_weth/` |

**Note:** Mode C is slower than Mode A (many snapshot probes per step).

Findings: [`scenarios/uniswapV2Se/MODE_C_FINDINGS.md`](./scenarios/uniswapV2Se/MODE_C_FINDINGS.md).

**Headline result:** after Uni demand, closer probes report **zero** residual profit (`maxBuyProbe`/`maxSellProbe` = 0); P&L matches Mode A twin — rate providers leave no free Balancer lunch under these params.

---

## Later

- Mode B: trade each Balancer market as primary drive  
- Vault-only claim telemetry (cleaner inventory charts)  
- DETF research harness (after SE foundation is solid)  
- Agents / Monte Carlo / other vault families  
