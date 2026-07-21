# Rate Provider Comparative — Findings

**Status:** Complete (baseline + mul10 + **mul25/steps48 with arb fills**).  
**Agent handoff report (read first):** [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md)  
**PRD:** [`RateProvider_Comparative_PRD.md`](./RateProvider_Comparative_PRD.md)  
**Plan:** [`RateProvider_Comparative_IMPLEMENTATION_AND_TEST_PLAN.md`](./RateProvider_Comparative_IMPLEMENTATION_AND_TEST_PLAN.md) · [`HIGH_VOLUME_PLAN.md`](./HIGH_VOLUME_PLAN.md)  
**Reproduce:**  
- Baseline: `./research/run_rate_provider_compare.sh`  
- High-vol (mul=10, fee unchanged): `./research/run_rate_provider_compare.sh --high-vol`  
- Arb-apparent tier: `./research/run_rate_provider_compare.sh --high-vol-25s48`

## Setup (locked)

| Axis | R+ (`rates_on`) | R− (`rates_off`) |
|------|-----------------|------------------|
| Share legs | All `TokenType.WITH_RATE` + SE rate providers | All `TokenType.STANDARD`, no rate providers |
| Worlds | Separate forge scripts / artifact trees | Same |
| Init | Fair size from `getRate()` | Fair size from `getRate()` (sizing only; not wired into pool) |
| Drive | Mode A Uni-only; Mode C Uni + `ResearchModeCCloser` | Same demand path |
| Physical pools | 4 CREATE3 pools (rate×pair in salt) | **2** physical pools (pair WETH / pair USDC) — salt collapses without rate providers; 4 logical lenses retained for telemetry |

## Artifact root (review here)

```text
research/out/uniswapV2Se/rateProviderCompare/
  rates_on/{modeA,modeC}_market_buys_{weth,usdc}/   # series.jsonl, meta.json, plots
  rates_off/{modeA,modeC}_market_buys_{weth,usdc}/
  compare/
    A_uni_only_{WETH,USDC}/
    C_uni_plus_bal_arb_{WETH,USDC}/
      fairness_compare.png   # ← start here
      pnl_compare.png
      probes_compare.png
      summary.json
```

Tracked narrative: this file + PRD/plan under `research/scenarios/uniswapV2Se/rateProviderCompare/`.

## Mode A results (Uni demand only)

### Headline numbers (step 24)

| Demand | Uni index (both) | R+ midW index | R− midW index | R+ mid×rate residual | R− mid×rate residual | Total P&L / start (both ≈) | Fee USDC (both ≈) |
|--------|------------------|---------------|---------------|----------------------|----------------------|----------------------------|-------------------|
| Market buys WETH | **1.00480** | **1.00239** | **1.00000** | **0** | **−0.00239** | **+0.479%** | **+7.33** |
| Market buys USDC | **0.99522** | **0.99761** | **1.00000** | **0** | **+0.00240** | **−0.477%** | **+7.29** |

Source: `compare/A_uni_only_*/summary.json` and per-run `series.jsonl`.

### Interpretation

1. **Uni path is identical** across pure states (same seed, same trades) — control holds.
2. **H2 (Mode A fairness) supported:**  
   - **R+:** Balancer mid index tracks `1/rate` so `mid_index × rate_index ≈ 1` for every sample (max |residual| = 0 on both demands).  
   - **R−:** Raw mid stays at 1.0 (live balances fixed; no rate scaling). Residual magnitude equals the SE rate move (~24 bps at end of the 24-step path).
3. **LP full-exit P&L is the same under R+ and R−** for Uni-only Mode A. Rate wiring on Balancer re-marks *mids* but does not change the SE vault claim → LP → token exit book when the driver never trades Balancer. Maker fee (~7.3 USDC) is Uni SE inventory economics, not rate-provider arbitrage.
4. Chart gap on R+ (`price_index` slopes differ) is **not** redeem-vs-buy arb residual — confirmed residual series is flat zero.

### Review charts first

1. `compare/A_uni_only_WETH/fairness_compare.png` — residual panel is the smoking gun  
2. `compare/A_uni_only_WETH/pnl_compare.png` — overlay P&L (R+/R− coincide)  
3. Per-run `index_vs_fairness.png` under `rates_on/` vs `rates_off/`

## Mode C results (Uni + Balancer closer)

| Demand | R+ maxBuyProbe | R+ fills | R− maxBuyProbe | R− fills | R+ residual end | R− residual end | Total P&L / start |
|--------|----------------|----------|----------------|----------|-----------------|-----------------|-------------------|
| Market buys WETH | **0** | **0** | **0** | **0** | **0** | **−0.00239** | **+0.479%** (both) |
| Market buys USDC | **0** | **0** | **0** | **0** | **0** | **+0.00240** | **−0.477%** (both) |

Source: `compare/C_uni_plus_bal_arb_*/summary.json`.

### Interpretation

1. **R+ Mode C = Mode A twin:** probes 0, fills 0, residual 0 — rate re-mark leaves no free Balancer lunch after Uni (reproduces legacy Mode C finding in the pure R+ world).
2. **R− residual remains (~±24 bps)** after the closer runs — mid still frozen, rates still moved. The closer did **not** erase the mark lag.
3. **R− probes also 0** under this fee/liquidity stack: residual is real on the mid×rate lens, but `ResearchModeCCloser`’s buy/sell-share routes report no positive profit after Balancer + SE usage fees. **Do not read “probes=0” as “R− is fair.”** Use residual series / fairness plots as the H2 evidence.
4. LP full-exit P&L again matches R+ — alice’s book is still primarily Uni SE inventory; unharvested mark residual does not force a different exit mark when Balancer legs exit at raw ratios.

### Hypotheses (final)

| ID | Claim | Verdict |
|----|-------|---------|
| **H1** | R+ closer probes ≈ 0; R− probes/fills diverge | **Partial:** R+ probes **0** (supported). R− **fills/probes also 0** under default fees — fillable arb not demonstrated. Residual (not probes) is the R− divergence signal. |
| **H2** | R+ mid tracks 1/rate; R− lags under same Uni | **Supported** (Mode A and Mode C residual series). |
| **H3** | Product should default to rate providers for SE-share Balancer legs | **Supported for mark integrity / fairness.** R+ keeps mid fair without external rebalancing. R− freezes mid and opens residual. LP $ under Uni-only demand is rate-agnostic; product value of rates is **pricing correctness**, not free Mode-A maker edge. |

## Product recommendation

- **Default ON (R+)** for Balancer pools that hold Standard Exchange shares when the design goal is redeem-fair marks without continuous arb rebalancing.
- **R− is the control world** that visualizes “Liquidity Tree / raw BPT” lag: mid freezes while SE rates track Uni.
- **Rate providers re-mark; they do not invent Mode A arb** after Uni when residual is already zero.
- **~24 bps residual after 24 small Uni steps was fee-drowned for the closer** — larger skew, thinner Balancer fees, or different routes would be needed to show fillable R− arb. Document residual, not fills, for this param set.

## Implementation notes

- R− CREATE3: package salt is TokenConfig hash. Without rate providers, `rateWeth_pairWeth` and `rateUsdc_pairWeth` collide. Fixture deploys **two** physical pools and maps four matrix lenses; Mode C closer passes unique pools only.
- Parent virtual hooks (minimal): `_tokenConfigs`, `_pairAmountForInit`, `_buildMetaJson`, `_deployMatrixPools`, `_bootstrapSharesAndInitPools`.
- Legacy `Script_ModeA_*` / `Script_ModeC_*` and `modeA_*` / `modeC_*` trees **untouched**.

## High-volume matrix (mul=10, Balancer fee unchanged)

**Purpose:** Grow Uni tilt via **larger per-step size** (10 WETH / 10 000 USDC, still 24 steps) without changing the const-prod **5%** Balancer fee.

**Artifacts (do not overwrite baseline):**
```text
research/out/uniswapV2Se/rateProviderCompare/highVol/mul10/
  rates_{on,off}/{modeA,modeC}_market_buys_{weth,usdc}/
  compare/{A_uni_only,C_uni_plus_bal_arb}_{WETH,USDC}/
```

### Residual: baseline vs high-vol (Mode A, end of path)

| Demand | R+ residual (bl / HV) | R− residual (baseline) | R− residual (mul=10) | Uni index HV |
|--------|----------------------|------------------------|----------------------|--------------|
| Market buys WETH | **0 / 0** | **−0.239%** | **−2.337%** (~10×) | **1.0485** |
| Market buys USDC | **0 / 0** | **+0.240%** | **+2.400%** (~10×) | **0.9537** |

### Mode C probes at mul=10

| Demand | R+ probes/fills | R− residual end | R− probes/fills |
|--------|-----------------|-----------------|-----------------|
| Market buys WETH | 0 / 0 | **−2.337%** | **0 / 0** |
| Market buys USDC | 0 / 0 | **+2.400%** | **0 / 0** |

### Interpretation

1. **Volume scales residual as expected** under R−: ~10× trade size → ~10× residual magnitude; R+ stays fair (residual 0).
2. **Fillable arb still did not appear** at ~2.4% residual with **5% Balancer swap fee** — edge remains below the closer’s fee+impact floor (honest fee-drown, not “no lag”).
3. **Implication:** further mul (e.g. 25–50) could push residual toward fee-scale, **or** a research fee cut is required to see probes; this goal intentionally left fee fixed.

### Review charts

1. `highVol/mul10/compare/A_uni_only_WETH/fairness_compare.png`  
2. `highVol/mul10/compare/C_uni_plus_bal_arb_WETH/probes_compare.png` (flat zeros, residual in fairness panel)

## High-volume matrix (mul=25, steps=48, Balancer fee unchanged) — **arb becomes apparent**

**Params:** 25 WETH / 25 000 USDC per step × **48** steps (fee still 5%).  
**Artifacts:** `research/out/uniswapV2Se/rateProviderCompare/highVol/mul25_steps48/`  
**Reproduce:** `./research/run_rate_provider_compare.sh --high-vol-25s48`

### Mode A residual (no closer)

| Demand | R+ residual | R− residual | Uni index end |
|--------|-------------|-------------|---------------|
| Market buys WETH | **0** | **~−10.7%** | ~**1.254** |
| Market buys USDC | **0** | (mirror large positive) | ~**0.797** |

R+ still fair without Balancer flow. R− lag is now **well above** the 5% pool fee scale.

### Mode C probes / fills (first time arb is fillable)

| Demand | R+ fills (sum) | R− fills (sum) | First positive probe step (both) | Notes |
|--------|----------------|----------------|----------------------------------|-------|
| Market buys WETH | **~93** | **~46** | **~22** | R− cum arb profit large; residual remains after closes |
| Market buys USDC | **~95** | **~47** | **~22** | Same pattern |

**H1 at extreme volume (honest):**

1. **R−:** Residual grows with Uni tilt; once large enough vs **5% Balancer fee + SE fees + impact**, closer probes flip positive (~step 22) and **fills execute**. Arb is **apparent**.
2. **R+:** Mode A residual still **0**. Mode C at this stress level **also** records positive probes/fills (often more fills than R−) — rate re-mark does not eliminate all multi-pool / inventory / redeem edges under **large** Uni path + active closer. Do **not** read R+ fills as “rates off lag”; residual series still separates pure mark lag (R− Mode A) from re-mark-aware worlds (R+ Mode A residual 0).
3. **Product next step (your plan):** treat **pool swap fee as the profit threshold** for presenting arb: lag/edge must clear fee before UX or bots should surface opportunity. This matrix is the empirical proof that crossing that threshold makes fills real.

### Review

1. `highVol/mul25_steps48/compare/C_uni_plus_bal_arb_WETH/probes_compare.png`  
2. `highVol/mul25_steps48/compare/A_uni_only_WETH/fairness_compare.png`  
3. Per-run `series.jsonl` `maxBuyProbe` / `arbFills` after step ~22  

## Open questions / follow-ups

1. **Done at mul25/s48:** R− arb fills proven under unchanged 5% fee.  
2. **Design:** Use pool fee as display/execution threshold for arb (next product/research plan).  
3. Explain R+ Mode C fills under extreme stress (multi-pool matrix edges vs pure mid×rate residual).  
4. Intentional lag/skew scenarios if product wants non-zero R+ arb surface by design.
