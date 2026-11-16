# DualLiquidity Research — Implementation and Research Execution Plan

## Purpose

Execute the [DualLiquidity Research PRD](./DualLiquidity_Research_PRD.md): ship a **new** research scenario family that measures DualLiquidity Linked Cross-Version Uniswap Vault behavior under pure **R−** (rates off, product default) and **R+** (rates on) worlds, with Mode A (leg Uni demand) then Mode B (product routes), optional Mode C (reserve arb), offline plots, and findings suitable for marketing / agent handoff.

This plan is ordered for **incremental delivery**. Each phase leaves reviewable artifacts. Prefer parallel-safe paths only (research scripts + scenario docs + `research/out/dualLiquidityLinkedCrossVersion/`).

## Status

**COMPLETE (v1)** — Mode A+B pure R+/R− on Base fork; compare plots; FINDINGS + agent report. Mode C not run.

### Locked decisions (summary)

| Topic | Decision |
|-------|----------|
| Normative PRD | [`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md) |
| SUT | Production DualLiquidity DFPkg + facets; gold fork TestBase patterns |
| Rates | `PkgArgs.useRateProviders` — pure worlds only (`false` / `true`) |
| Env | Base mainnet **fork** (`TestBase_DualLiquidityLinkedCrossVersionUniswapVault`) |
| Profile | `FOUNDRY_PROFILE=default`; offline forge OK after compile |
| Isolation | New scripts/out only; **do not** overwrite `research/out/uniswapV2Se/**` or edit other DETF packages |
| Mode order | Mode A → Mode B → Mode C (stretch) |
| Primary book | DualLiquidity share full-exit mark (normalized) |
| Reserve fee | **0.003e18 (0.3%)** — document in meta; do not use SE research 5% |

---

## 1. Goals and non-goals

### Goals

1. Research fixture that bootstraps DualLiquidity on fork (deploy package instance + **bootstrap reserve** + live share book).
2. Mode A scripts: leg underlying demand for R− and R+; residual + P&L series.
3. Mode B scripts: DualLiquidity `exchangeIn` / swap routes; preview==execution samples.
4. Offline compare plots R+ vs R−; FINDINGS + agent report.
5. Runner script with flags (`--mode-a-only`, `--mode-b-only`, `--rates-on-only`, etc.).
6. Optional Mode C / stress tier only after Mode A residual is understood.

### Non-goals

- Changing DualLiquidity production package semantics (rates optional already shipped).
- Other DETF rate refactors or their tests.
- Hermetic Uni V4 port rewrite for v1.
- Guaranteeing Mode C fills.
- Full monorepo `forge test` as gate for every research script run.

---

## 2. Naming and layout

### Source (new only)

```text
scripts/foundry/research/dualLiquidityLinkedCrossVersion/
  ResearchFixture_DualLiquidity.sol           # fork bootstrap + rates flag + telemetry
  ResearchFixture_DualLiquidity_ModeC.sol      # optional closer wiring
  Script_RatesOff_ModeA_*.s.sol
  Script_RatesOn_ModeA_*.s.sol
  Script_RatesOff_ModeB_*.s.sol
  Script_RatesOn_ModeB_*.s.sol
  Script_RatesOff_ModeC_*.s.sol                # stretch
  Script_RatesOn_ModeC_*.s.sol                 # stretch
research/run_dual_liquidity_research.sh
research/plots/
  plot_dual_liquidity_*.py                    # or reuse plot_all_mode_a + compare with field adapters
  plot_rate_provider_compare.py               # reuse if residual field names aligned
```

### Tracked narrative

```text
research/scenarios/dualLiquidityLinkedCrossVersion/
  DualLiquidity_Research_PRD.md
  DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  FINDINGS.md
  AGENT_RESEARCH_REPORT.md
```

### Artifacts

```text
research/out/dualLiquidityLinkedCrossVersion/
  rates_off/modeA_<drive>/
  rates_on/modeA_<drive>/
  rates_off/modeB_<route>/
  rates_on/modeB_<route>/
  compare/
  highVol/   # optional
```

### Inheritance / composition sketch

```text
TestBase_DualLiquidityLinkedCrossVersionUniswapVault   # gold fork deploy + bootstrap helpers
        ▲
        │  research fixture inherits OR composes via copy of bootstrap API
        │  (prefer inherit TestBase pattern used by fork tests; Script deploys fixture instance)
ResearchFixture_DualLiquidity(useRateProviders immutable)
        │
        ├─ bootstrapResearch()  // setUp-like: fork, deploy pkg, deployVault, _bootstrapReserve, fund alice book
        ├─ residual / mid / rate readers
        ├─ markFullExit* for DualLiquidity shares
        ├─ swapLegUni* for Mode A
        ├─ depositRoute* for Mode B
        └─ initTelemetry / sample / meta
```

**Anti-pattern:** `new DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` outside factory/registry path.  
**Required:** `indexedexManager.deployVault` / typed factory with `vm.prank(owner)` as TestBase does.

**Rates flag:** constructor `bool useRateProviders_` → override TestBase `_useRateProviders()` or pass into `PkgArgs` when deploying research instance (must not rely on TestBase default alone if fixture deploys its own instance).

---

## 3. Residual and mid definitions (normative for implementers)

Reserve is **3-token weighted** with legs `vaultAShare`, `vaultBShare`, `pairVaultShare`. Balancer live balances are rate-scaled when R+.

### Per-leg mid (raw)

For each reserve registration index `i` holding leg share token `S_i` and complementary value via pool math, prefer **simpler research mid**:

**Option A (recommended for v1 fairness):**  
For each SE leg share `S` with rate provider RP (or 1e18 if R−):

```text
// Live balance of leg share in pool (raw token units from getCurrentLiveBalances — already live-scaled in BV3)
// Residual vs SE redeem:
residual_i = f(mid_i, rate_i)

// Practical series (align with Uni V2 SE research spirit):
// rateIndex_i = rate_t / rate_0
// For R+: if mid tracks 1/rate in the numeraire of the rate target, midIndex * rateIndex ≈ 1
// For R−: midIndex stays ~1 while rateIndex moves
```

**Primary published residual** (document in meta + FINDINGS):

```text
// Prefer vaultA leg (commonToken-denominated RP when rates on):
residualA = midIndex_A * rateIndex_A - 1
// midIndex_A = mid_A_t / mid_A_0
// mid_A from live balances: e.g. value of leg A share in pool relative to another leg or BPT-implied —
// Implementer MUST pick one explicit formula and lock it in NatSpec + FINDINGS.
```

**Minimal implementable formula (lock this unless better is proven in Phase 0 spike):**

Use Balancer live balances for tokens at `indexA` and a reference (e.g. pair leg):

```text
midA_raw = live[indexPair] * 1e18 / live[indexA]   // pairShare per vaultAShare (or inverse; fix orientation in meta)
```

At t0 record `midA_0`, `rateA_0 = IRateProvider(rateA).getRate()` when R+; when R− still read SE rate from deployable RP **off-pool** for residual lens only (same as rateProviderCompare R−: rate exists for measurement, not on TokenConfig).

**R− measurement rates:** Even when reserve is STANDARD, research fixture may deploy or attach **off-pool** SE rate providers (or call vault preview redeem) solely for residual series—**must not** wire them into the pool. Prefer reading `StandardExchangeRateProvider` if rates-on path already deployed one; for rates-off, call `IStandardExchange` preview redeem 1e18 share → commonToken/tokenA for a synthetic rate.

Document chosen synthetic rate in NatSpec.

### Share book mark

```text
markFullExit:
  1) burn DualLiquidity shares → BPT via exchangeOut (or proportional redeem path)
  2) exit BPT → three leg shares
  3) redeem each leg SE → underlying
  4) mark underlyings in commonToken (or USD-stable common if common is stable-like test token)
```

Use snapshot/revert if needed for non-destructive sampling (same spirit as Uni V2 SE research `markFullExitUsdc`).

---

## 4. Fixture responsibilities

### `ResearchFixture_DualLiquidity`

| Method | Behavior |
|--------|----------|
| `constructor(bool useRateProviders_)` | Immutable rates policy |
| `bootstrapResearch()` | Fork + Indexedex + deploy DualLiquidity with `useRateProviders_`; call `_bootstrapReserve()`; endow research actor with DualLiquidity shares (or deposit common after live) |
| `tradeSizeMul` / `tradeSteps` | Optional volume knobs (default modest: e.g. mul=1, steps=12–24) |
| `swapLegMarket(...)` | Mode A: trade V4 poolKeyA/B and/or V2 pair via live routers |
| `depositCommon` / `exchangeInRoute` | Mode B wrappers |
| `previewExchangeIn` / exec compare | Mode B asserts |
| `initTelemetry(runId, ...)` | Write meta + sample step 0 |
| `sample(action)` | Append JSONL |
| `_buildMetaJson` | `scenarioFamily`, `useRateProviders`, `rateProviderMode`, `mode`, fees, trade knobs |

### Bootstrap checklist (mirror TestBase)

1. Bind live Base addresses (Balancer vault, weighted factory, Uni V4 PM, V2 factory/router).  
2. Deploy hermetic test tokens **or** use TestBase token deploy for common/A/B (TestBase already deploys test ERC20s + seeds V4/V2 markets).  
3. Deploy leg packages + DualLiquidity DFPkg via manager.  
4. `PkgArgs.useRateProviders = ratesOn`.  
5. `_bootstrapReserve()` → vault live.  
6. Optional: `_depositCommon(alice, amount)` so share book is non-trivial for P&L.  
7. Record t0 rates, mids, portfolio0.

### Fork / RPC

- Use same fork RPC pattern as TestBase (`TestBase_BaseFork`).  
- Research scripts: `forge script ... --fork-url $BASE_RPC` or project standard env.  
- Document required env vars in runner help.

---

## 5. Phases

### Phase 0 — Spike (fixture skeleton + one sample)

**Deliverable:** Fixture compiles; one R− deploy + bootstrap + single `sample("init")` writes meta/series under `rates_off/smoke/`.

1. [ ] Create `ResearchFixture_DualLiquidity` inheriting gold TestBase (or thin wrapper).  
2. [ ] Override rates via constructor → `PkgArgs`.  
3. [ ] `bootstrapResearch` + smoke script.  
4. [ ] Lock residual formula in NatSpec after first mid numbers look sane.  
5. [ ] Confirm R+ and R− produce **different** reserve pool addresses (salt).

**Exit:** Smoke EXIT:0; series non-empty; no other DETF files touched.

### Phase 1 — Mode A R− then R+ (modest volume)

**Scripts (minimum):**

| Script | rates | Drive |
|--------|-------|--------|
| `Script_RatesOff_ModeA_LegDemand_A` | false | Tilt market affecting vaultA (e.g. common↔tokenA V4) |
| `Script_RatesOn_ModeA_LegDemand_A` | true | Same path |
| Optional second drive | both | vaultB and/or pair V2 for symmetry |

**Loop:**

```text
initTelemetry
for step in 1..STEPS:
  swapLegMarket(fixed size * mul)
  sample("leg_demand")
```

**Plots:** stamp_meta + plot pack (fairness residual, pnl_normalized, rates if available).

**Exit:** H1/H2 numbers in scratch summary; R+ residual ~0; R− residual larger; both pure states complete.

### Phase 2 — Mode B product routes

**Scripts:**

| Script | Action |
|--------|--------|
| `Script_RatesOff_ModeB_DepositCommon` | preview + exchangeIn commonToken → shares |
| `Script_RatesOn_ModeB_DepositCommon` | same |
| Optional | deposit tokenA/tokenB; leg share deposit; BPT deposit |

**Per step or single-shot:**

```text
preview = previewExchangeIn(...)
out = exchangeIn(...)
assert preview == out or |preview-out| <= WEI_TOL
sample with route fields
```

Also record leg vault share supply or reserve live balances before/after for “nested activity” evidence.

**Exit:** H4/H5 evidence; at least one marketing-ready Mode B series.

### Phase 3 — Compare pack + findings (v1 done without Mode C)

1. [ ] `plot_dual_liquidity_compare.py` or adapt `plot_rate_provider_compare.py` with DualLiquidity field map.  
2. [ ] Outputs under `compare/modeA_*`, `compare/modeB_*`.  
3. [ ] `FINDINGS.md` H1–H5.  
4. [ ] `AGENT_RESEARCH_REPORT.md` (do not re-run guidance).  
5. [ ] Update `research/README.md` / `SCENARIO_LOG.md`.  
6. [ ] `research/run_dual_liquidity_research.sh`.

**Exit:** PRD success criteria Mode A+B + narrative met.

### Phase 4 — Mode C stretch (optional)

1. [ ] Adapt closer to 3-token weighted reserve (leg share ↔ complementary token) **or** document why 2-token closer is insufficient.  
2. [ ] Scripts R+/R−; probe fields in series.  
3. [ ] Residual vs 0.3% fee narrative (H6).  
4. [ ] Stress tier only if residual &lt; fee at modest volume.

**Exit:** H6 pass/fail honest; not required for v1 “research done.”

### Phase 5 — Verification (executor)

| # | Check |
|---|--------|
| 1 | `rates_off` and `rates_on` trees exist with non-empty `series.jsonl` + meta `useRateProviders` |
| 2 | Mode A residual R+ ≈ 0, R− diverges (or documented failure) |
| 3 | Mode B preview/exec row in series or FINDINGS table |
| 4 | Compare plots + FINDINGS + agent report |
| 5 | At least one forge log EXIT:0 and one plot EXIT:0 under scratch |
| 6 | `git status` shows no accidental edits to other DETF production packages |

---

## 6. Script catalog (v1 target)

### Mode A (required)

```text
Script_RatesOff_ModeA_LegDemand.s.sol
Script_RatesOn_ModeA_LegDemand.s.sol
```

Drive: one primary market tilt (document which pair in console + meta). Optional second script for opposite direction.

### Mode B (required)

```text
Script_RatesOff_ModeB_DepositCommon.s.sol
Script_RatesOn_ModeB_DepositCommon.s.sol
```

### Mode C (optional)

```text
Script_RatesOff_ModeC_LegDemandThenArb.s.sol
Script_RatesOn_ModeC_LegDemandThenArb.s.sol
```

### Runner flags

```bash
./research/run_dual_liquidity_research.sh
  --mode-a-only | --mode-b-only | --mode-c-only
  --rates-on-only | --rates-off-only
  --plot-only | --data-only
  --fork-url $BASE_RPC   # if not in env
```

---

## 7. Telemetry schema (v1 draft)

Each `series.jsonl` line (minimum):

```json
{
  "step": 0,
  "action": "init",
  "useRateProviders": false,
  "rateA": "...",
  "rateB": "...",
  "ratePair": "...",
  "rateAIndex": "...",
  "midA": "...",
  "midAIndex": "...",
  "residualA": "...",
  "uniSpot_A": "...",
  "portfolio0": "...",
  "portfolioExit": "...",
  "totalPnl": "...",
  "feePnl": "...",
  "pricePnl": "...",
  "previewOut": "...",
  "execOut": "...",
  "route": "deposit_common",
  "maxBuyProbe": "0",
  "maxSellProbe": "0",
  "arbFills": "0"
}
```

Omit Mode B/C fields when unused; keep keys stable once locked in Phase 0.

**meta.json extras:** `reserveSwapFee: "3000000000000000"`, `weights: [0.2e18,0.2e18,0.6e18]`, `scenarioFamily`, `product: dualLiquidityLinkedCrossVersion`.

---

## 8. Plot plan

| Plot | Source | Notes |
|------|--------|-------|
| Fairness / residual | Mode A series | R+ vs R− overlay in `compare/` |
| P&L normalized | Mode A | Marketing primary |
| Rates / uni | Mode A | Leg demand visibility |
| Mode B preview gap | Mode B | abs(exec-preview) |
| Probes | Mode C | optional |

Reuse `stamp_meta.py`, `plot_all_mode_a.py` if field aliases work; otherwise thin DualLiquidity plot adapters.

---

## 9. Parallel-work / conflict avoidance

| Do | Do not |
|----|--------|
| Add files under `scripts/foundry/research/dualLiquidityLinkedCrossVersion/` | Edit other DETF packages under `contracts/vaults/detf/**` |
| Write only `research/scenarios/dualLiquidityLinkedCrossVersion/**` narrative | Overwrite `research/out/uniswapV2Se/**` |
| Read DualLiquidity production sources | “Fix” unrelated stack-too-deep in other families unless blocking compile |
| Inherit TestBase from crossVersion fork path | Duplicate entire TestBase into a second production path |

If DualLiquidity package is mid-edit by another agent, wait for stable `useRateProviders` API (already present as of PRD writing).

---

## 10. Risk register

| Risk | Mitigation |
|------|------------|
| Fork RPC flaky / slow | Cache; fewer steps first; Mode A before Mode C |
| Residual formula ambiguous for 3-token pool | Phase 0 lock + document; primary residualA only |
| Full exit gas / complexity | Snapshot mark; fewer intermediate steps |
| V4 swap path complexity | Reuse TestBase swap helpers if any; else PoolManager/router patterns from fork tests |
| Stack-too-deep in fixture | Split sample/meta builders (Mode A lesson) |
| Mode C closer not 3-token ready | Stretch; residual-only H6 if needed |

---

## 11. Estimated effort

| Phase | Effort | Wall-clock note |
|-------|--------|-----------------|
| 0 Smoke fixture | Small–medium | First fork compile heavy |
| 1 Mode A both rates | Medium | 2–4 forge scripts |
| 2 Mode B | Medium | Preview asserts |
| 3 Compare + docs | Small | |
| 4 Mode C | Medium–large | Optional |

---

## 12. Execution checklist (track during implementation)

### Phase 0

- [x] Fixture + smoke script  
- [x] Residual formula NatSpec locked  
- [x] R+/R− pure worlds (useRateProviders flag)  

### Phase 1

- [x] Mode A R− complete + plots  
- [x] Mode A R+ complete + plots  
- [x] Scratch residual summary  

### Phase 2

- [x] Mode B R− + R+ deposit common  
- [x] preview==execution documented  

### Phase 3

- [x] compare/ plots  
- [x] FINDINGS.md H1–H5  
- [x] AGENT_RESEARCH_REPORT.md  
- [x] Runner + SCENARIO_LOG + README  

### Phase 4 (optional)

- [ ] Mode C scripts  
- [ ] H6 documented  

### Phase 5

- [x] Verification table all checked  

## Deviations

- Mode C not implemented (PRD stretch; residual ≪ 0.3% fee at modest Mode A).  
- TestBase `_useRateProviders` changed pure→view so research immutable flag works.

---

## 13. Related paths

| Path | Role |
|------|------|
| [DualLiquidity_Research_PRD.md](./DualLiquidity_Research_PRD.md) | Normative research requirements |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` | SUT |
| `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Gold bootstrap (`_bootstrapReserve`, `_depositCommon`) |
| `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` | Prior rates/fee theory |
| `scripts/foundry/research/uniswapV2Se/rateProviderCompare/` | Script/telemetry patterns to mirror |
| `research/run_rate_provider_compare.sh` | Runner pattern |

---

## 14. Next action

When authorized to implement:

1. Phase 0 smoke fixture on fork.  
2. Mode A rates_off then rates_on.  
3. Mode B.  
4. Findings + agent report.  
5. Mode C only if marketing needs fee-threshold figure on DualLiquidity specifically.

---

*Plan for handoff. Flip checkboxes during execution; append a single `## Deviations` section if needed.*
