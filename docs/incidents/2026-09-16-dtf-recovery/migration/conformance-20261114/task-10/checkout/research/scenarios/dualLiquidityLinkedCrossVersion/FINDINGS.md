# DualLiquidity Research — Findings

**Status:** Mode A + Mode B complete (pure R+/R−). Mode C not run (stretch).  
**PRD:** [`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md)  
**Plan:** [`DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md)  
**Agent handoff:** [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md)  
**Reproduce:** `./research/run_dual_liquidity_research.sh` (Base fork RPC required)

## Residual formula (locked)

```text
midA = live[pairVault] * 1e18 / live[vaultA]     // Balancer live balances
midIndexA = midA_t / midA_0
rateA = SE redeem lens vaultA → commonToken (1e18 shares), or pool RP when rates on
rateIndexA = rateA_t / rateA_0
residualA = midIndexA * rateIndexA / 1e18 - 1     // stored as 1e18 fixed-point int in series
```

## Mode A — leg Uni demand (V4 common → tokenA)

| Pure state | residualA end (1e18 fixed) | residualA (fraction) | Interpretation |
|------------|----------------------------|----------------------|----------------|
| **R+** (`useRateProviders: true`) | **−1** (dust) | **~0** | Mid re-marks with SE rate |
| **R−** (`useRateProviders: false`) | **+1.86e14** | **~+1.86e-4** | Mid lags; residual grows with path |

Drive: 12 × 500e18 exact-in on V4 commonToken→tokenA. Artifacts:

```text
research/out/dualLiquidityLinkedCrossVersion/rates_{on,off}/modeA_legDemand/
research/out/dualLiquidityLinkedCrossVersion/compare/modeA_legDemand/
```

### Hypotheses

| ID | Verdict |
|----|---------|
| **H1** R+ residual ≈ 0 | **Supported** (dust −1 wei) |
| **H2** R− residual larger | **Supported** (~1.86e-4 vs ~0) |
| **H3** Share book P&L plotable | **Supported** (`portfolioExitBpt` / `totalPnlBpt` series) |

Note: modest volume → R− residual **≪ 0.3%** reserve fee; fee-threshold arb not expected at this tier (see Uni V2 SE rateProviderCompare for fee-threshold theory).

## Mode B — deposit commonToken

| Pure state | preview vs exec |
|------------|-----------------|
| **R−** | **Exact** equality every step |
| **R+** | **≤ few-wei** divergence under WITH_RATE sizing (documented) |

Artifacts: `rates_{on,off}/modeB_depositCommon/`, `compare/modeB_depositCommon/`.

| ID | Verdict |
|----|---------|
| **H4** preview==execution | **Supported** (exact off; few-wei on) |
| **H5** nested activity | **Supported** (shares minted, reserve BPT tracked in series) |

## Mode C

**Not executed** (stretch). Residual at modest Mode A remains below 0.3% fee scale for R−.

## Marketing claims unlocked

| Claim | Evidence |
|-------|----------|
| Default DualLiquidity can run without rates | rates_off Mode A/B + meta `useRateProviders: false` |
| Opt-in rates re-mark nested mids | R+ residualA ≈ 0 |
| Without rates, lag can open | R− residualA grows |
| Closed-form deposit previews trustworthy | Mode B series |
| Nested share book markable | BPT full-exit mark series |

## Review order

1. `compare/modeA_legDemand/fairness_pnl_compare.png`  
2. `compare/modeB_depositCommon/preview_gap.png`  
3. `rates_off/modeA_legDemand/series.jsonl` vs `rates_on/...`
