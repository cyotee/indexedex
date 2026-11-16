# Agent Research Report — Rate Providers, Residual Lag, and Fee-as-Arb Threshold

**Audience:** other agents and humans who must **reuse** these results without re-running forge matrices.  
**Status:** locked findings as of 2026-07-21 (hermetic research; not mainnet measurement).  
**Do not re-run** full Mode C high-vol matrices unless parameters change — wall-clock is large. Read this report + open the cited artifacts/plots.

| Role | Path |
|------|------|
| This report (canonical summary) | `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` |
| Detailed session findings | [`FINDINGS.md`](./FINDINGS.md) |
| PRD / plans | [`RateProvider_Comparative_PRD.md`](./RateProvider_Comparative_PRD.md), [`HIGH_VOLUME_PLAN.md`](./HIGH_VOLUME_PLAN.md) |
| Related Mode A/C foundation | [`../MODE_A_FINDINGS.md`](../MODE_A_FINDINGS.md), [`../MODE_C_FINDINGS.md`](../MODE_C_FINDINGS.md) |
| Generated data (gitignored) | `research/out/uniswapV2Se/rateProviderCompare/**` |

**Reproduce only if needed:**

```bash
FOUNDRY_PROFILE=default ./research/run_rate_provider_compare.sh              # baseline
FOUNDRY_PROFILE=default ./research/run_rate_provider_compare.sh --high-vol   # mul10
FOUNDRY_PROFILE=default ./research/run_rate_provider_compare.sh --high-vol-25s48
```

---

## 1. One-paragraph answer

With **Balancer share legs wired to Standard Exchange rate providers (R+)**, Uni demand re-marks Balancer mids via rates so **mid×rate residual ≈ 0** under Uni-only Mode A; legacy Mode C under modest volume showed **no** Balancer arb. With **rates off (R−)**, mids **freeze** while SE rates track Uni, so a **redeem-vs-mid residual grows with Uni volume**. That residual is **not automatically profitable**: the closer must beat **Balancer swap fee + SE usage fee + impact + min-profit dust**. Under the research const-prod fee (**5%**), modest volume left residual **below** the fee floor (no fills); extreme volume (**mul=25, 48 steps**) pushed residual **above** fee scale and **Mode C fills appeared**. Therefore **pool swap fee acts as an economic threshold** for when lag becomes presentable/fillable arbitrage.

---

## 2. What was tested (pure states)

| Pure state | Share leg TokenConfig | Intent |
|------------|----------------------|--------|
| **R+** (`rates_on`) | All `WITH_RATE` + SE rate provider | Production-like nested mark |
| **R−** (`rates_off`) | All `STANDARD`, no rate provider | Raw BPT mid only (Liquidity-Tree-style lag) |

- **Homogeneous:** never mix R+ and R− pools in one world.  
- **Separate** scripts, fixtures, and `out/` trees; compare offline.  
- **Same** Uni seed (~10k WETH / 10M USDC), SE vault, fair init, demand path.  
- **Fee unchanged** across all volume tiers (const-prod package default **`5e16` = 5%** swap fee).  
- **Volume levers:** `tradeSizeMul` and `tradeSteps` only (not fee).

**Drives:**

- **Mode A:** Uni-only market demand (both directions).  
- **Mode C:** Uni demand then `ResearchModeCCloser` (buy-shares / sell-shares probes + optional fills).

**Residual metric (primary fairness lens):**

```text
residual ≈ mid_index × rate_index − 1
# using series fields e.g. rateWeth_pairUsdc_cross_index × rateWethIndex / 1e36 − 1
```

- **R+ fair tracking:** residual ≈ 0 after Uni moves (mid re-marks with rate).  
- **R− lag:** mid index stays ~1; residual ≈ ± rate move (grows with Uni tilt).

---

## 3. Volume ladder — empirical table

| Tier | Size / steps | Approx total notional (WETH-side) | R+ Mode A residual | R− Mode A residual | Mode C R− probes/fills |
|------|--------------|-----------------------------------|--------------------|--------------------|-------------------------|
| **Baseline** | 1 WETH / 1k USDC × 24 | ~24 WETH | **0** | **~±0.24%** | **0** |
| **mul10** | 10× size × 24 | ~240 WETH | **0** | **~±2.4%** | **0** (fee-drowned) |
| **mul25_s48** | 25× size × **48** | ~1200 WETH | **0** | **~±10–12%** | **Fills from ~step 22** |

**Interpretation:** residual scales with Uni stress under R−. Fills require residual (plus executable edge) to clear the **fee stack**, not merely “any non-zero residual.”

---

## 4. Why the fee is a threshold (agent mental model)

### 4.1 Residual ≠ profit

Residual measures **mark lag** (Balancer mid vs SE redeem fair). Closer profit is roughly:

```text
edge ≳ residual_scale − Balancer_swap_fee − SE_usage_fee − impact − MIN_PROFIT
```

Research closer: `MIN_PROFIT = 1e12` wei (dust). Probes size at 0.05% / 0.25% / 1% of pair inventory.

### 4.2 Research Balancer fee is large

Const-prod DFPkg registers pools at **5%** swap fee (`5e16`). Comments elsewhere may say “0.05%”; the **shipped research package value is 5%**. Agents must not assume retail 0.3% fee when reading these runs.

### 4.3 Threshold behavior observed

| Residual vs 5% fee | What agents saw |
|--------------------|-----------------|
| ~0.24% or ~2.4% **≪ 5%** | Residual real on R−; **probes = 0**, fills = 0 |
| ~10–12% **> 5%** | Residual large; **probes > 0**, **fills** execute (~step 22 onward) |

So **fee is a hard economic filter**: lag below fee is “mispricing on paper”; lag above fee can become **presentable / fillable arb** for routes that pay that fee.

### 4.4 Product implication (for future design work)

- **Presentation threshold:** only surface arb when estimated edge **exceeds pool fee** (plus other legs).  
- **Do not** market residual charts alone as arb opportunity.  
- **R+ default** for SE-share Balancer legs remains justified for **mark integrity** (Mode A residual 0).  
- **Fee policy** and **rate wiring** are separate knobs: rates kill *this* lag channel; fees set when *any* residual is worth trading.

---

## 5. R+ vs R− — what agents must not confuse

| Observation | R+ | R− |
|-------------|----|----|
| Mode A mid×rate residual | **0** at all volume tiers tested | Grows with Uni volume |
| Mode A LP full-exit P&L (modest Uni) | Same as R− twin (Uni SE economics) | Same |
| Mode C modest volume | Probes 0 | Probes 0 |
| Mode C extreme volume | **Also** records fills (multi-pool stress edges) | Fills from lag + routes |
| Meaning of Mode C fills under R+ | **Not** “rates failed to re-mark” — Mode A residual still 0 | Pure lag residual still visible on Mode A |

**Anti-pattern for agents:** “R+ Mode C had more fills than R− at mul25 ⇒ rates create more arb.”  
**Correct read:** under extreme Uni tilt, the matrix + closer can find **inventory / multi-leg / redeem** edges even with rates on; **fairness residual** (Mode A mid×rate) still separates R+ from R−.

---

## 6. Artifact map (open these, do not regenerate)

### Baseline (mul=1, steps=24)

```text
research/out/uniswapV2Se/rateProviderCompare/
  rates_on|rates_off / modeA|modeC _ market_buys_weth|usdc /
  compare/A_uni_only_* , compare/C_uni_plus_bal_arb_*
```

Start: `compare/A_uni_only_WETH/fairness_compare.png`

### High-vol mul10 (fee drown)

```text
.../rateProviderCompare/highVol/mul10/
```

### High-vol mul25 steps48 (**arb apparent**)

```text
.../rateProviderCompare/highVol/mul25_steps48/
  compare/C_uni_plus_bal_arb_WETH/probes_compare.png   # fills
  compare/A_uni_only_WETH/fairness_compare.png         # R− residual ~10%
  rates_*/modeC_*/series.jsonl                         # maxBuyProbe, arbFills after step ~22
```

**Meta fields to trust:** `rateProviderMode`, `tradeSizeMul`, `tradeSteps` / `tradeWethWei` / `tradeUsdcWei`, `scenarioFamily`, `gitCommit` (after stamp).

---

## 7. Code / harness pointers (no reimplementation)

| Piece | Location |
|-------|----------|
| Pure-state fixture | `scripts/foundry/research/uniswapV2Se/rateProviderCompare/ResearchFixture_RateProviderCompare.sol` |
| Mode C wiring | `ResearchFixture_RateProviderCompare_ModeC.sol` |
| Closer | `scripts/foundry/research/uniswapV2Se/ResearchModeCCloser.sol` |
| Volume params | constructor `(ratesOn, tradeSizeMul, tradeSteps)` — `0` steps → default 24 |
| Baseline scripts | `rateProviderCompare/Script_Rates*.s.sol` (mul=1) |
| mul10 scripts | `rateProviderCompare/highVol/Script_HV_*.s.sol` |
| mul25/s48 scripts | `rateProviderCompare/highVol/Script_HV25s48_*.s.sol` |
| Runner | `research/run_rate_provider_compare.sh` (`--high-vol`, `--high-vol-25s48`) |
| Compare plots | `research/plots/plot_rate_provider_compare.py` |

**R− CREATE3 note:** without rate providers, TokenConfig salt collapses four logical rate×pair cells to **two** physical pools (pair WETH / pair USDC). Fixture maps four telemetry lenses onto those two pools. Do not “fix” by expecting four distinct CREATE3 addresses under R−.

---

## 8. Locked conclusions for downstream agents

1. **Rate providers (R+)** keep Balancer SE-share mids fair under Uni demand (Mode A residual ≈ 0).  
2. **Rates off (R−)** recreate raw mid lag; residual **grows with volume**.  
3. **Fee is the arb threshold:** residual below fee stack ⇒ no fills; residual above ⇒ closer can print probes/fills (proven at mul25/s48 with **5%** fee).  
4. **Do not re-run** full high-vol Mode C unless changing fee, size, steps, or closer math — use artifacts + this report.  
5. **Next design work** (not done here): product/UX rules that **gate arb presentation on pool fee** (and document R+ multi-pool stress fills separately from mid×rate residual).

---

## 9. Open questions (explicitly unresolved)

- Exact **breakeven residual %** as a continuous function of fee (only three volume points measured).  
- Full causal breakdown of **R+ Mode C fills** under extreme stress (matrix cross-pool vs single-pool lag).  
- Behavior under **production-like** Balancer fees (e.g. 0.3%) — residual thresholds would drop; do not assume 5% thresholds apply on-chain.  
- **DualLiquidityLinked** now ships **optional** rates (`PkgArgs.useRateProviders`, default **off**); residual Mode A rates-on vs rates-off research for that family remains a follow-up (not this report’s scope).  
- SE Buffer hooks / DETF / intentional stale rates — out of scope for this family.

---

## 10. Citation checklist for agents writing docs or code

When claiming “fee acts as arb threshold,” cite:

1. This report §4.  
2. Ladder table §3.  
3. Artifacts: `highVol/mul10` (no fills) vs `highVol/mul25_steps48` (fills).  
4. Const-prod fee: `5e16` in Balancer V3 const-prod DFPkg (research hermetic).  

When claiming “rates re-mark,” cite Mode A R+ residual **0** at all tiers and [`FINDINGS.md`](./FINDINGS.md).

---

*End of agent report. Prefer updating this file when new tiers/fee experiments complete rather than spawning parallel narratives.*
