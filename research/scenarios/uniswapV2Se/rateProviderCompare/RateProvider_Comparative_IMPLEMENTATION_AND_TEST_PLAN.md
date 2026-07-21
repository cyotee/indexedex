# Rate Provider Comparative — Implementation and Research Execution Plan

## Purpose

Execute the [PRD](./RateProvider_Comparative_PRD.md): ship a **new** research scenario family that compares Balancer share legs **with** vs **without** Standard Exchange rate providers under identical Uni V2 SE demand, using **inheritance/import** of existing Mode A/C research code **without modifying** legacy Mode A/C scripts or their artifact paths.

This plan is ordered for incremental delivery: each phase leaves reviewable artifacts.

## Status

**COMPLETE** — pure-state R+/R− fixtures, 8 scripts, runner, Mode A+C matrix, compare plots, FINDINGS.

### Locked decisions (summary)

| Topic | Decision |
|-------|----------|
| Isolation | New scripts + new `out/rateProviderCompare/`; no edits to `Script_ModeA_*` / `Script_ModeC_*` |
| **Homogeneous state** | **One Rate Provider policy per run** — all SE-share pools R+ **or** all R−; never mixed in one bootstrap |
| **Separate worlds** | Distinct fixture instances, scripts, and artifact dirs for `rates_on` vs `rates_off` |
| R+ | Every share leg `WITH_RATE` + SE rate provider |
| R− | Every share leg `STANDARD` (no rate provider) |
| Reuse | Inherit Mode A matrix fixture / Mode C pattern; override token config (+ R− fair init) + meta tags |
| Drive | Mode A–style Uni-only + Mode C–style arb closer; both demand directions **per pure state** |
| Profile | `FOUNDRY_PROFILE=default` |
| Hypothesis | R+ probes ≈ 0; R− probes / residual diverge under same Uni path |

---

## 1. Goals and non-goals

### Goals

1. Implement **R+** and **R−** research fixtures that share bootstrap with Mode A via inheritance.
2. Provide **new** forge scripts for Mode A–equivalent and Mode C–equivalent drives under each variant.
3. Emit telemetry + plots for all runs; emit **comparison** plots/tables for R+ vs R−.
4. Document findings against pre-registered H1–H3 in the PRD.
5. Leave a reproduce runner (`run_rate_provider_compare.sh`) consistent with `run_mode_a.sh` / `run_mode_c.sh`.

### Non-goals (this plan)

- Changing production DETF/SE/Balancer packages for mainnet semantics.
- Editing legacy Mode A/C research scripts or overwriting `research/out/uniswapV2Se/modeA_*` / `modeC_*`.
- **Mixed-policy deployments** (some pools rate-aware, some not) — deferred until a product reason exists.
- SE Buffer hook loops, off-fair init, Monte Carlo, multi-protocol SE matrix (follow-ups).
- Guaranteeing non-zero R− fills if fees kill edge — then document residual series instead.

---

## 2. Naming and layout

### Source (new only)

```text
scripts/foundry/research/uniswapV2Se/rateProviderCompare/
  ResearchFixture_RateProviderCompare.sol    # abstract: ratesOn flag → TokenConfig
  ResearchFixture_RateProviderCompare_ModeC.sol  # optional: Mode C + closer on compare fixture
  Script_RatesOn_ModeA_MarketBuysWeth.s.sol
  Script_RatesOn_ModeA_MarketBuysUsdc.s.sol
  Script_RatesOff_ModeA_MarketBuysWeth.s.sol
  Script_RatesOff_ModeA_MarketBuysUsdc.s.sol
  Script_RatesOn_ModeC_MarketBuysWeth.s.sol
  Script_RatesOn_ModeC_MarketBuysUsdc.s.sol
  Script_RatesOff_ModeC_MarketBuysWeth.s.sol
  Script_RatesOff_ModeC_MarketBuysUsdc.s.sol
```

**Inheritance sketch (normative intent):**

```text
ResearchFixture_UniswapV2SeRateMatrix          # existing — DO NOT edit for this scenario
        ▲
        │ override _tokenConfigs / matrix deploy / init only
ResearchFixture_RateProviderCompare            # ratesOn: bool — applies to ALL matrix pools
        ▲
        │
ResearchFixture_RateProviderCompare_ModeC      # bootstrapModeC + closer (mirror ResearchFixture_ModeC)
```

**Homogeneous construction:** `ratesOn` is fixed for the entire fixture lifetime. Every pool created in `_deployMatrixPools` / `_tokenConfigs` uses that single policy. There is **no** per-pool override that mixes WITH_RATE and STANDARD in one instance.

Scripts: `new` fixture with **one** policy → `bootstrapResearch` / `bootstrapModeC` → `initTelemetry` with **new runId paths** → drive loop (copy structure from Mode A/C scripts; do not subclass legacy script contracts).

### Preferred override point

In parent fixture, `_tokenConfigs` currently sets:

```solidity
// share leg
tokenType: TokenType.WITH_RATE,
rateProvider: matrixRateProvider[i],
```

**R+ (`ratesOn == true`):** same for **every** matrix index `i` — WITH_RATE + appropriate WETH/USDC rate provider.

**R− (`ratesOn == false`):** for **every** matrix index `i`:

```solidity
tokenType: TokenType.STANDARD,
rateProvider: IRateProvider(address(0)),
```

Do not deploy a parallel set of “rates on” pools inside an R− run (or the reverse). Pair topology may still vary (WETH vs USDC pair); share **policy** may not.

**R− init fairness:** parent `_pairAmountForInit` uses `rateProvider.getRate()` for liveShares. For R− pools, **do not** use a zero rate. Override `_pairAmountForInit` (or matrix init) to size pair from:

- same-asset: pair amount = raw shares (1:1 units at seed), or  
- cross: `rawShares`-equivalent value via Uni reserves **as if** converting the SE redeem basket at t0  

Document the chosen formula in NatSpec on the compare fixture. Goal: t0 mid ≈ fair so **Uni demand** creates R− lag, not accidental init skew (init skew is a later scenario).

### Telemetry / meta

- Reuse `sample()` from parent if possible.
- Override `initTelemetry` **or** post-write meta via script helper so `rateProviderMode` and `scenarioFamily` are set without bloating parent (prefer compare fixture override of meta builder only).

### Plots

```text
research/plots/
  plot_index_vs_fairness.py          # reuse as-is on each run dir
  plot_all_mode_a.py                 # reuse (already includes fairness plot)
  plot_rate_provider_compare.py      # NEW: side-by-side R+ vs R−
  stamp_meta.py                      # reuse
```

`plot_rate_provider_compare.py` inputs: two run dirs (rates_on + rates_off, same mode + demand). Outputs under `research/out/.../rateProviderCompare/compare/`.

### Tracked narrative

```text
research/scenarios/uniswapV2Se/rateProviderCompare/
  RateProvider_Comparative_PRD.md                         # normative
  RateProvider_Comparative_IMPLEMENTATION_AND_TEST_PLAN.md # this file
  FINDINGS.md                                             # after runs
  rates_on_modeA_market_buys_weth.md                      # per-run notes as needed
  ...
```

### Artifacts

See PRD layout under `research/out/uniswapV2Se/rateProviderCompare/`.

### Runner

```text
research/run_rate_provider_compare.sh
  # FOUNDRY_PROFILE=default
  # flags: --mode-a-only | --mode-c-only | --plot-only | --rates-on-only | --rates-off-only
```

---

## 3. Phases

### Phase 0 — Docs (this delivery)

- [x] PRD  
- [x] Implementation plan  
- [ ] Link from `research/README.md` + `SCENARIO_LOG.md` (stub row “planned”)

### Phase 1 — Fixture skeleton (R+ pure world)

**Deliverable:** `ResearchFixture_RateProviderCompare(ratesOn=true)` — **all** matrix pools WITH_RATE; behavioral twin of Mode A.

1. Add compare fixture; `ratesOn` constructor/immutable applies to **entire** matrix.
2. R+ TokenConfig: WITH_RATE on every share leg (no STANDARD pools in this instance).
3. Script: `Script_RatesOn_ModeA_MarketBuysWeth` → `research/out/.../rates_on/modeA_market_buys_weth/` only.
4. Plot pack; sanity vs legacy `modeA_trade_usdc` within tolerance.

**Exit:** R+ Mode A one direction green; no legacy script edits; no mixed-policy pools.

### Phase 2 — R− pure world + fair init

1. Separate scripts/instances with `ratesOn=false` only — **all** share legs STANDARD.
2. Override init sizing so t0 is fair without live rate on share leg.
3. Scripts: R− Mode A both demand directions under `rates_off/` only (no rates_on pools co-deployed).
4. Telemetry: mid does **not** track `1/rate` as in R+; residual grows under Uni demand (H2).
5. Prefer Python residual from existing fields first; add JSONL fields only if required.

**Exit:** R− Mode A both directions complete with plots + notes; still zero mixed-policy deploys.

### Phase 3 — Mode C closer on both variants

1. `ResearchFixture_RateProviderCompare_ModeC` (or compose closer like `ResearchFixture_ModeC`).
2. Scripts: R+ and R− × market buys WETH/USDC.
3. Log fills + maxBuy/SellProbe every step (same as Mode C scripts).
4. **H1 check:** R+ probes ≈ 0; R− probes/fills or residual series.

**Exit:** Full Mode C matrix for R+ and R−; findings draft for H1.

### Phase 4 — Comparison pack + findings

1. `plot_rate_provider_compare.py`:
   - Panel: R+ vs R− uni index (should match).
   - Panel: residual / probe series overlay.
   - Panel: LP total P&L / start and fee P&L.
2. `compare/summary.json` optional machine summary.
3. `FINDINGS.md` with H1–H3 verdicts, link to old Liquidity Tree theory vs rate-aware marks.
4. Update `SCENARIO_LOG.md`, `research/README.md`.

**Exit:** Scenario “done” per PRD acceptance.

### Phase 5 — Optional follow-ups (not required for v1 done)

- Larger `TRADE_STEPS` / size if R− residual exists but fills fail on fees (`MIN_PROFIT`).
- Single-pool focus run for pedagogy.
- Off-fair init comparative (separate PRD).
- SE Buffer hook recirculation (separate PRD).

---

## 4. Implementation details

### 4.1 Script pattern (copy structure, new contracts)

Each script should look like Mode A/C entrypoints:

```solidity
// NEW file only
contract Script_RatesOff_ModeA_MarketBuysWeth is Script {
    function run() external {
        ResearchFixture_RateProviderCompare f =
            new ResearchFixture_RateProviderCompare(/* ratesOn=false */);
        f.bootstrapResearch();
        f.initTelemetry("rateProviderCompare/rates_off/modeA_market_buys_weth", true);
        // loop: swapUniExactIn + sample — same as Mode A
    }
}
```

**Do not** subclass `Script_ModeA_TradeWeth`. Duplicate the thin `run()` loop (≤40 lines) to keep legacy entrypoints frozen.

### 4.2 RunId / telemetry paths

Parent `ResearchTelemetry.initRun("uniswapV2Se", runId_)` writes `research/out/uniswapV2Se/<runId>/`.

Use runIds:

```text
rateProviderCompare/rates_on/modeA_market_buys_weth
rateProviderCompare/rates_off/modeA_market_buys_weth
...
```

Confirm `vm.createDir` creates nested paths (parent already uses `createDir(..., true)`).

### 4.3 Mode C integration

Mirror `ResearchFixture_ModeC`:

- After `bootstrapResearch`, deploy `ResearchModeCCloser`, set `researchModeId = 1`.
- `configureCloser` after `initTelemetry`.
- Per step: `swapUniExactIn` → `closeBalancerArbs` → `sample`.

Import closer from existing path; **do not** fork closer unless R− requires a bugfix (then fix closer for both, note in deviations).

### 4.4 Comparison plot requirements

Minimum compare outputs:

| File | Content |
|------|---------|
| `probes_compare.png` | R+ vs R− maxBuyProbe (and fills) for same demand |
| `fairness_compare.png` | R+ mid×rate residual vs R− redeem-vs-mid residual |
| `pnl_compare.png` | R+ vs R− totalPnl/start and feePnl |

Single-run packs: call existing `plot_all_mode_a.py` per run dir.

### 4.5 Production-first / research rules

- No mocks of SE, manager, Balancer vault, rate provider packages.
- Crane Uni V2 stubs for hermetic deploy (already Mode A).
- Mintable USDC / WETH funding for traders only.
- Label R− clearly as research lag model, not production recommendation.

---

## 5. Verification plan (scenario v1)

1. **Structural:** New scripts exist; `git diff` shows no changes to `Script_ModeA_*` / `Script_ModeC_*` (unless agreed bugfix).
2. **R+ sanity:** `rates_on/modeA_market_buys_weth` uni end index within ~same band as legacy Mode A twin (~1.0048 for buys WETH).
3. **R− Mode A:** series non-empty; `meta.rateProviderMode == "off"`.
4. **Mode C probes:** R+ max probes 0 (or dust); R− documented positive residual and/or fills.
5. **Plots:** each run has `index_vs_fairness.png`; `compare/` has three compare plots.
6. **Narrative:** `FINDINGS.md` states H1–H3 pass/fail with numbers.
7. **Reproduce:** `./research/run_rate_provider_compare.sh --mode-a-only` (or full) exits 0 after warm cache.

---

## 6. Phase checklist (execution tracking)

### Phase 0 — Docs

- [x] PRD written
- [x] Implementation plan written
- [x] README + SCENARIO_LOG stub links

### Phase 1 — R+ fixture parity

- [x] `ResearchFixture_RateProviderCompare` (rates on)
- [x] Scripts Mode A both directions → `rates_on/...`
- [x] Plots + notes; sanity vs legacy Mode A

### Phase 2 — R−

- [x] STANDARD TokenConfig + fair init override
- [x] Scripts Mode A both directions → `rates_off/...`
- [x] Residual analysis (Python and/or JSONL fields)

### Phase 3 — Mode C both variants

- [x] Mode C fixture/scripts for rates_on and rates_off
- [x] Probe/fill logs; H1 evaluation

### Phase 4 — Compare + findings

- [x] `plot_rate_provider_compare.py` + compare artifacts
- [x] `FINDINGS.md` + SCENARIO_LOG + README
- [x] Runner script complete

---

## 7. Estimated effort

| Phase | Effort (order of magnitude) |
|-------|-----------------------------|
| 0 Docs | Done in this session |
| 1 R+ parity | Small (thin inheritance + scripts) |
| 2 R− + init | Medium (fair init without rate) |
| 3 Mode C ×4 | Medium (runtime: Mode C slow) |
| 4 Compare + findings | Small–medium |

Mode C wall time dominates (snapshot probes). Prefer `--offline` if forge hangs on network finalize.

---

## 8. Related paths

| Path | Role |
|------|------|
| `scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol` | Parent fixture (read-only for this scenario) |
| `scripts/foundry/research/uniswapV2Se/ResearchFixture_ModeC.sol` | Mode C pattern to mirror |
| `scripts/foundry/research/uniswapV2Se/ResearchModeCCloser.sol` | Arb closer reuse |
| `research/plots/*` | Existing plot pack |
| `research/scenarios/uniswapV2Se/rateProviderCompare/*` | This family |

---

## 9. Next action after plan approval

Implement **Phase 0 remainder** (README/SCENARIO_LOG stubs) then **Phase 1** fixture + one R+ Mode A script end-to-end before building R−.
