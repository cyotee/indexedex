# Single SE DETF Research Phase 3 — Implementation and Execution Plan

## Purpose

Execute [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md): ship a **hermetic** research harness (Uni V2 SE + Single Standard Exchange DETF), **one forge script per scenario D0–D9**, JSONL telemetry, PNG figures **F1–F4 + F7–F9**, FINDINGS, and agent handoff.

Scenario **pass/fail intent** is owned by [`DETF_Research_PRD.md`](./DETF_Research_PRD.md). This plan is **how to build and run** Phase 3.

## Status

**COMPLETE** (2026-07-30) — M0–M5 done; D0–D9 + F1–F4 + F7–F9 + FINDINGS.

| Field | Value |
|-------|--------|
| **Phase 3 PRD** | [`DETF_Research_Phase3_PRD.md`](./DETF_Research_Phase3_PRD.md) |
| **Campaign PRD** | [`DETF_Research_PRD.md`](./DETF_Research_PRD.md) |
| **Program** | [`research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md`](../../../papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md) |
| **Done bar** | Full **D0–D9** + F1–F4 + F7–F9 + FINDINGS (Phase 3 PRD §13) |
| **Profile** | `FOUNDRY_PROFILE=default` |

### Locked decisions (do not re-open here)

| Topic | Decision |
|-------|----------|
| Scripts | One `Script_Di_*.s.sol` per scenario |
| SE attachment | **Uni V2** hermetic (not Aero TestBase default) |
| Synthetic drive | **Production paths only:** free-DETF primary burns when burn-allowed + real Uni V2 trades (no Open/deal). Uni-only insufficient post-bond (RQ5 PARTIAL). |
| D2 | Flexible / N/A if already mint-allowed |
| Expansion / compound | Product law LOCKED; D8/D9 **required** |
| Fresh world | Default: each script full `setUp` |
| Isolation | New trees only under `scripts/foundry/research/detf/singleSe/` and `research/out/detf/singleSe/` |

---

## Progress

| Milestone | Status | Notes |
|-----------|--------|-------|
| M0 Scaffold fixture + smoke telemetry | **done** | Fixture full API; D0 green |
| M1 D0–D1 + F1 | **done** | |
| M2 D2–D4 + F2–F4 | **done** | |
| M3 D5–D7 + F7 | **done** | |
| M4 D8–D9 + F8–F9 | **done** | |
| M5 FINDINGS + runner + SCENARIO_LOG | **done** | |

---

## 1. Goals and non-goals

### Goals

1. `ResearchFixture_DetfSingleSeUniV2` deploys production Uni V2 SE + Single SE DETF (Policy + Open helpers).  
2. Ten research scripts D0–D9 with `ResearchTelemetry` JSONL + stamped `meta.json` + `NOTES.md`.  
3. Offline PNG plots F1–F4, F7–F9.  
4. `research/run_detf_single_se.sh` orchestrates forge → stamp → plot.  
5. `FINDINGS.md` + `AGENT_RESEARCH_REPORT.md` + `SCENARIO_LOG` rows.  
6. Campaign PRD Progress/Results synced.

### Non-goals

- Production package changes (unless true product bug).  
- Re-running Uni V2 SE rateProviderCompare matrices.  
- Multi-family DETF empirics.  
- Litepaper prose (program Phase 4).  
- Frontend R4 ship (program Phase 5).  
- Monte Carlo / mainnet APY.  
- Full monorepo `forge test` as gate for every research script run.

---

## 2. Naming and layout

### Source (new only)

```text
scripts/foundry/research/detf/singleSe/
  ResearchFixture_DetfSingleSeUniV2.sol
  DetfSingleSeTelemetry.sol              # optional: JSON line builders
  Script_D0_Inert.s.sol
  Script_D1_FirstBond.s.sol
  Script_D2_PolicyDeadband.s.sol
  Script_D3_PolicyMintAllowed.s.sol
  Script_D4_PolicyBurnGate.s.sol
  Script_D5_OpenControl.s.sol
  Script_D6_CapitalSeigniorageDilution.s.sol
  Script_D7_BondVsMintBooks.s.sol
  Script_D8_NaturalExpansion.s.sol
  Script_D9_ProtocolCompound.s.sol

research/run_detf_single_se.sh

research/plots/
  plot_detf_single_se_lifecycle.py       # F1
  plot_detf_single_se_synthetic.py       # F2, F3
  plot_detf_single_se_preview.py         # F4
  plot_detf_single_se_bond_vs_mint.py    # F7
  plot_detf_single_se_expansion.py       # F8
  plot_detf_single_se_compound.py        # F9
  # or one plot_detf_single_se_all.py with --fig flags
```

### Tracked narrative

```text
research/scenarios/detf/singleSe/
  DETF_Research_PRD.md
  DETF_Research_Phase3_PRD.md
  DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  FINDINGS.md                                            # after M5
  AGENT_RESEARCH_REPORT.md                               # after M5
```

### Artifacts (generated)

```text
research/out/detf/singleSe/
  D0_inert/{meta.json,series.jsonl,NOTES.md}
  D1_firstBond/...
  D2_policyDeadband/...
  D3_policyMintAllowed/...
  D4_policyBurnGate/...
  D5_openControl/...
  D6_capitalSeigniorage/...
  D7_bondVsMint/...
  D8_naturalExpansion/...
  D9_protocolCompound/...
  figures/
    F1_lifecycle.png
    F2_synthetic_thresholds.png
    F3_demand_to_synthetic.png
    F4_preview_vs_execution.png
    F7_bond_vs_mint.png
    F8_expansion_policy_vs_open.png
    F9_protocol_compound.png
```

### Composition sketch

```text
IndexedexTest + Uni V2 SE deploy (research / TestBase patterns)
        +
Single SE DETF facets/pkg/bond NFT/rate provider (TestBase_SingleStandardExchangeDETF patterns)
        │
        ▼
ResearchFixture_DetfSingleSeUniV2
  seVault / seShare / rateTarget / uni pair+router
  deployPolicyDetf() / deployOpenDetf()
  fundSeShares() / firstBond() / tradeUni() / sampleDetf()
        │
        ▼
Script_Di  (forge script)  → ResearchTelemetry → out/detf/singleSe/<runId>/
        │
        ▼
stamp_meta.py + plot_detf_single_se_*.py
```

**Reference implementations (read, do not edit casually):**

| Need | Path |
|------|------|
| Uni V2 SE + research bootstrap | `scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol` |
| Uni V2 SE TestBase | `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol` |
| Single SE DETF deploy + bond | `contracts/vaults/detf/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol` |
| Mint/burn/preview tests | `test/foundry/spec/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Mint.t.sol` (and Burn, Bonding, Info) |
| Expansion / compound tests | `*NaturalExpansion.t.sol`, `*ProtocolCompound.t.sol` under single SE tests |
| Telemetry | `scripts/foundry/research/harness/ResearchTelemetry.sol` |
| Runner pattern | `research/run_mode_a.sh` |

---

## 3. Fixture design (M0)

### 3.1 Inheritance strategy (pick one; document in fixture NatSpec)

| Option | Pros | Cons |
|--------|------|------|
| **A (recommended)** | New fixture inherits `IndexedexTest` + vault/Balancer setup; **copy-adapt** Uni V2 SE deploy from research fixture; **copy-adapt** DETF deploy from `TestBase_SingleStandardExchangeDETF` | More code, full control |
| **B** | Inherit `TestBase_UniswapV2StandardExchange` then add DETF deploys | Clean SE; may fight diamond/test base diamond hierarchy |
| **C** | Inherit `TestBase_SingleStandardExchangeDETF` and **replace** `seVault` with Uni V2 after super | Fast but fragile (Aero default first) |

**Plan default: Option A** — avoid Aero default and deep multi-TestBase diamonds.

### 3.2 Fixture API (required)

```text
// Identity
address detf;                    // current instance under test
IStandardExchangeProxy seVault;
IERC20 seShare;
IERC20 rateTarget;               // e.g. WETH or USDC per SE rate wiring
// Uni
IUniswapV2Pair uniPair;
IUniswapV2Router uniRouter;

// Deploy
function deployPolicyDetf(string name, string symbol) returns (address);
function deployOpenDetf(string name, string symbol) returns (address);
// PkgArgs: mintThreshold=0, burnThreshold=0 → resolve defaults;
//          thresholdMode Policy|Open;
//          expansionClosureRatePerSecond=0 → product default resolve (must be ON for D8);
//          document resolved expansion params in meta

// Actors / funding
function fundSeShares(address to, uint256 lpOrDepositAmt) returns (uint256 shares);
function firstBond(address bonder, uint256 shareAmt, uint256 lock) returns (uint256 tokenId);

// Markets
function tradeUniExactIn(address tokenIn, uint256 amountIn, ...) ;
// Prefer both directions available for D3/D4

// DETF routes
function previewMint(uint256 seSharesIn) returns (uint256 detfOut);
function mintSeSharesForDetf(address user, uint256 seSharesIn) returns (uint256 detfOut);
function previewBurn(uint256 detfIn) returns (uint256 seSharesOut);
function burnDetfForSeShares(address user, uint256 detfIn) returns (uint256 seSharesOut);

// Sample
function sampleToJson(uint256 step) returns (string line);
// includes: live, synth, thresholds, mode, mint/burn allowed, supply,
// optional preview/exec, pendingRewards, protocolBpt, uni index

// Protocol
function protocolNftId() returns (uint256);
function protocolBptBalance() returns (uint256);   // document exact accounting
function compoundProtocol() returns (...);
```

### 3.3 Expansion params for research

| Concern | Plan |
|---------|------|
| D8 needs accrual | Ensure Policy deploy uses **non-zero effective** `expansionClosureRatePerSecond` (0 → default resolve is OK **if** default is non-zero). If product default is off when 0, set an explicit research rate in fixture for Policy D8 (document in meta; do not change production defaults). |
| D5 Open | Expansion must not accrue even if rate storage is non-zero (product: Open never expands). |
| Catch-up caps | Use package defaults; record in `meta.json`. |

### 3.4 Smoke (M0 exit)

1. `forge script` or fixture test: deploy Policy DETF inert.  
2. Write one JSONL row + meta under `research/out/detf/singleSe/_smoke/`.  
3. Assert `!isReserveLive()`.  

---

## 4. Per-scenario implementation (M1–M4)

Each script:

1. `new ResearchFixture_DetfSingleSeUniV2()` (or equivalent setUp).  
2. `ResearchTelemetry.initRun("detf/singleSe", "<runId>")`.  
3. Execute steps; `appendLine` after each meaningful step.  
4. `writeMeta` minimal JSON (script will be enriched by `stamp_meta.py`).  
5. Console log pass/fail assertions (script may `revert` on hard fail).

### D0 — `Script_D0_Inert` → `D0_inert`

| Step | Action |
|------|--------|
| 0 | `deployPolicyDetf` |
| 1 | Sample; assert inert; mint attempt reverts |
| 2 | `vm.warp(+1 days)` (or research constant); sample; assert no expansion reward growth (no bond or zero pending) |
| Exit | NOTES template |

### D1 — `Script_D1_FirstBond` → `D1_firstBond`

| Step | Action |
|------|--------|
| 0 | Deploy Policy |
| 1 | `fundSeShares` + `firstBond` |
| 2 | Assert live; sample supply, synth, bond id, protocol wiring |
| Exit | NOTES; residual free inventory note |

### D2 — `Script_D2_PolicyDeadband` → `D2_policyDeadband`

| Step | Action |
|------|--------|
| 0–1 | Deploy + first bond (or call shared helper sequence) |
| 2 | Read synth + `isMintingAllowed` |
| 3a | If deadband: expect mint fail; warp; no expansion |
| 3b | If mint-allowed: mark **N/A** in NOTES + meta `d2Status: "na_already_mint_allowed"` |
| Exit | Do not force deadband |

### D3 — `Script_D3_PolicyMintAllowed` → `D3_policyMintAllowed`

| Step | Action |
|------|--------|
| 0–1 | Live Policy via first bond |
| 2…n | Production drive: free-DETF primary burns when burn-allowed + Uni trades until `syntheticPrice > mintThreshold` (cap steps; fail loudly if not reached) |
| n+1 | `previewMint` then `mint`; record delta; assert ≈ equal (≤1 wei preferred) |
| Exit | Label capital seigniorage vs expansion in NOTES |

**Trade sizing:** start from Mode A research trade magnitudes; scale up if needed. Log cumulative volume in meta.

### D4 — `Script_D4_PolicyBurnGate` → `D4_policyBurnGate`

| Step | Action |
|------|--------|
| 0–1 | Live Policy; ensure actor holds DETF (mint when allowed, or bond-derived path if needed — prefer mint only after rich) |
| 2…n | Uni trades reverse direction until `syntheticPrice < burnThreshold` |
| n+1 | Assert burn allowed; preview/exec burn; assert no expansion while not mint-rich |

### D5 — `Script_D5_OpenControl` → `D5_openControl`

| Step | Action |
|------|--------|
| 0 | `deployOpenDetf` + first bond |
| 1 | Assert mint/burn allowed (live) independent of synth |
| 2 | Optional Uni trades to stress synth |
| 3 | Snapshot `pendingRewards` on user bond (if any) |
| 4 | Large warp; touch/sync; assert pending does **not** grow from expansion |
| 5 | Mint/burn once to prove routes |

### D6 — `Script_D6_CapitalSeigniorageDilution` → `D6_capitalSeigniorage`

| Step | Action |
|------|--------|
| Live Policy; ensure mint allowed via Uni trades if needed |
| Sequence of N primary mints (e.g. 3–8); sample supply, synth, composition proxies each step |
| NOTES: capital seigniorage only — not D8 expansion |

### D7 — `Script_D7_BondVsMintBooks` → `D7_bondVsMint`

| Step | Action |
|------|--------|
| Alice: first bond (bonder) |
| Bob: holds free DETF via mint when allowed (no bond) |
| Apply capital seigniorage and/or short expansion window |
| Compare: bonder `pendingRewards` vs bob free DETF (bob must **not** receive expansion airdrop) |
| Dual actor series rows with `actorLabel` |

### D8 — `Script_D8_NaturalExpansion` → `D8_naturalExpansion`

| Step | Action |
|------|--------|
| Policy live + user bond |
| Uni trades until mint-rich |
| Snapshot pendingRewards / supply / synth |
| `vm.warp` large enough for measurable accrual (tune against rate) |
| Sync/update path as product requires |
| Assert pendingRewards ↑ (or claimable free DETF ↑) |
| Optional: short Open twin subsection or separate sample proving no accrual |
| meta: expansion rate, catch-up caps, warp seconds |

### D9 — `Script_D9_ProtocolCompound` → `D9_protocolCompound`

| Step | Action |
|------|--------|
| Live instance; ensure protocol NFT can have rewards (seigniorage from mint and/or expansion) |
| Record `protocolBptBalance()` (or documented metric) |
| Call `compoundProtocolRewards()` (and/or path that auto-compounds) |
| Assert protocol depth ↑; user bond still claimable free DETF |
| NOTES: single-sided join skew accepted; no claim APY claim |

---

## 5. Telemetry and meta (implementation notes)

### JSONL line builder

Implement string concat JSON (as Mode A / DualLiquidity scripts do) **or** thin `DetfSingleSeTelemetry` library:

```text
{"step":0,"scenarioId":"D3","thresholdMode":"Policy","isReserveLive":true,
 "syntheticPrice":"...", "mintThreshold":"...", "burnThreshold":"...",
 "isMintingAllowed":true,"isBurningAllowed":false,"totalSupply":"...",
 "previewOut":"...","execOut":"...","pendingRewards":"...","protocolBpt":"...",
 "uniSpotIndex":"..."}
```

Use `ResearchTelemetry.u` / `a` for encoding.

### stamp_meta.py

Reuse `research/plots/stamp_meta.py` with `--script path:Contract`. Ensure meta includes at least:

- `campaign`, `phase`, `scenarioId`, `thresholdMode`, `seAttachment: uniswapV2`, `gitCommit`

Scripts may write a partial meta; stamp overwrites/enriches.

---

## 6. Plots (implementation notes)

| Fig | Inputs | Y / story |
|-----|--------|-----------|
| F1 | D0+D1 series or boolean timeline | live flag / supply vs step |
| F2 | D2–D4 | syntheticPrice, mintThreshold, burnThreshold vs step |
| F3 | D3 | uniSpotIndex + syntheticPrice |
| F4 | D3 | scatter or bar previewOut vs execOut |
| F7 | D7 | pendingRewards bonder vs bob free balance |
| F8 | D5+D8 | pendingRewards Policy vs Open over warp |
| F9 | D9 | protocolBpt before/after |

Prefer matplotlib + Agg backend (as other research plots). One `plot_detf_single_se_all.py` with `--fig F1` is fine.

**F5–F6:** not built here; cite SE rateProviderCompare paths in FINDINGS.

---

## 7. Runner

`research/run_detf_single_se.sh` (from repo root):

```bash
# Default: D0→D9 forge + stamp + all required plots
./research/run_detf_single_se.sh
./research/run_detf_single_se.sh --d3
./research/run_detf_single_se.sh --from D5
./research/run_detf_single_se.sh --plot-only
./research/run_detf_single_se.sh --data-only
```

Pattern after `run_mode_a.sh`:

- `set -euo pipefail`  
- `FOUNDRY_PROFILE=default`  
- `MPLBACKEND=Agg`  
- Map Di → script path + out dir  
- `forge script … -vv` then `python3 research/plots/stamp_meta.py …`  
- Plot pass last  

---

## 8. FINDINGS and handoff (M5)

### FINDINGS.md structure

1. One-paragraph headline  
2. Setup (Uni V2 SE + Single SE DETF; hermetic)  
3. RQ1–RQ10 table: pass/fail + key numbers + runId  
4. Figure index (paths under `out/` or `figures/`)  
5. Expansion vs capital seigniorage labeling  
6. Protocol compound result  
7. Caveats / non-claims  
8. Reproduce commands  

### AGENT_RESEARCH_REPORT.md

- Audience: agents/humans reuse without re-running  
- Status locked date  
- Do not re-run casually  
- Pointers to FINDINGS + figure paths  
- Expansion/compound one-liners  

### SCENARIO_LOG

One row per Di (or one summary row + per-Di) in `research/SCENARIO_LOG.md`.

### Campaign PRD

Update Progress checkboxes + Results summary table.

---

## 9. Milestone checklist (ordered work)

### M0 — Scaffold (first implementation session)

- [x] Create `scripts/foundry/research/detf/singleSe/`  
- [x] `ResearchFixture_DetfSingleSeUniV2.sol` compiles  
- [x] Uni V2 SE vault + Policy DETF deploy inert  
- [x] Telemetry smoke → `out/detf/singleSe/_smoke/`  
- [x] Document resolved expansion defaults after deploy (cast/log)  

### M1 — Lifecycle

- [x] `Script_D0_Inert` + NOTES  
- [x] `Script_D1_FirstBond` + NOTES  
- [x] F1 PNG  

### M2 — Gates

- [x] D2 (or N/A documented)  
- [x] D3 mint + preview==exec  
- [x] D4 burn gate  
- [x] F2, F3, F4 PNGs  

### M3 — Open + books

- [x] D5 Open + no expansion  
- [x] D6 capital dilution series  
- [x] D7 bond vs mint  
- [x] F7 PNG  

### M4 — Expansion + compound

- [x] D8 expansion positive (real trades + warp)  
- [x] D9 protocol compound BPT ↑  
- [x] F8, F9 PNGs  

### M5 — Lock Phase 3

- [x] `run_detf_single_se.sh` default green  
- [x] FINDINGS.md RQ1–RQ10  
- [x] AGENT_RESEARCH_REPORT.md  
- [x] SCENARIO_LOG  
- [x] Campaign PRD Progress/Results  
- [x] Phase 3 PRD Progress all done  

---

## 10. Verification / “test” plan

Research scripts are not unit tests, but each Di has **assert gates**:

| Di | Hard asserts (script reverts if false) |
|----|----------------------------------------|
| D0 | `!isReserveLive`; mint reverts; post-warp no expansion signal |
| D1 | `isReserveLive`; reservePool ≠ 0 |
| D2 | If applicable: mint reverts when `!isMintingAllowed` |
| D3 | `isMintingAllowed`; `abs(preview-exec) ≤ 1` (or documented bound) |
| D4 | Burn allowed when synth < burnThreshold; burn succeeds |
| D5 | Mint+burn succeed when live; expansion delta ≈ 0 after warp |
| D6 | supply increases across mint sequence |
| D7 | bonder rewards path ≠ free-holder expansion airdrop |
| D8 | pendingRewards (or claimable) strictly increases after warp when rich |
| D9 | protocolBpt after compound > before |

Optional: thin Foundry **test** that only checks fixture deploys (not required for Phase 3 done).

Do **not** require full `forge test` suite for research sign-off.

---

## 11. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Synthetic hard to move ±5% | Free-DETF primary burns (when burn-allowed) + increase Uni trade size/steps; fail loudly if cap hit |
| Expansion rate too small for short warp | Read resolved rate; compute warp; set explicit research rate if 0 means off |
| Protocol BPT metric ambiguous | Implement `protocolBptBalance` once; unit-check against compound tests |
| Stack too deep / compile | Split libraries; avoid fat inheritance; profile default |
| Auto-compound on touches confounds D9 | Snapshot immediately before/after explicit compound call; document auto path |
| D2 always N/A | Acceptable; D3/D4 carry gate story |

---

## 12. Acceptance (copy of Phase 3 PRD §13)

Phase 3 is done when Phase 3 PRD **§13** is fully satisfied (D0–D9, F1–F4, F7–F9, FINDINGS RQ1–RQ10, runner, claim-safe language). This plan’s M0–M5 is the delivery path to that bar.

---

## 13. Suggested first coding session (concrete)

1. Scaffold fixture Option A with Uni V2 SE + DETF Policy deploy.  
2. Log `syntheticPrice`, thresholds, expansion rate after deploy.  
3. Land D0 script end-to-end.  
4. Land D1 first bond.  
5. Stop and update Progress on this plan + Phase 3 PRD.

---

## 14. Status log

| Date | Event |
|------|--------|
| 2026-07-30 | Implementation plan authored for Phase 3 (full D0–D9) |
| 2026-07-30 | **M0/D0:** `ResearchFixture_DetfSingleSeUniV2` + `Script_D0_Inert` run successful; artifacts under `research/out/detf/singleSe/D0_inert/` |
| 2026-07-30 | **COMPLETE:** D0–D9 green; F1–F4 + F7–F9; FINDINGS RQ1–RQ10; runner + SCENARIO_LOG |

---

*End of implementation plan.*
