# Product Requirements Document (PRD)

## Title

Phase 3 — Single SE DETF Research Harness & Scenarios D0–D9 (Execution)

## Status

**COMPLETE** (2026-07-30) — D0–D9 + F1–F4 + F7–F9 + FINDINGS. Does not change production packages.

| Field | Value |
|-------|--------|
| **Phase** | 3 (DETF research harness + full scenario pack) |
| **Created** | 2026-07-30 |
| **Campaign (normative product/scenario law)** | [`DETF_Research_PRD.md`](./DETF_Research_PRD.md) |
| **Portfolio program** | [`research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md`](../../../papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md) |
| **Compound / expansion law** | [`DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../../contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) (**LOCKED**) |
| **Threshold law** | [`DETF_Threshold_Modes_PRD.md`](../../../../contracts/vaults/detf/DETF_Threshold_Modes_PRD.md) (**LOCKED**) |
| **SE research rails (cite, do not re-run)** | [`../../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md) |
| **Implementation plan** | [`DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md) |
| **Agent handoff** | [`AGENT_HANDOFF.md`](./AGENT_HANDOFF.md) |

**Conflict rule:**

- **Scenario pass/fail, product behavior, non-claims** → campaign [`DETF_Research_PRD.md`](./DETF_Research_PRD.md) + locked product PRDs.  
- **How to build, file layout, run order, Phase 3 acceptance** → **this document**.  
- If this PRD and the campaign PRD conflict on scenario *intent*, **campaign PRD wins** and this file is revised.

---

## Progress

| Checkpoint | Status | Notes |
|------------|--------|-------|
| Phase 3 PRD authored | **done** | 2026-07-30 |
| Shared research fixture (Uni V2 SE + Single SE DETF) | **done** | `ResearchFixture_DetfSingleSeUniV2.sol` |
| Telemetry sample schema | **done** | synth, gates, preview/exec, pending, protocolBpt, uniSpot |
| Runner `research/run_detf_single_se.sh` | **done** | bash 3.2-safe; forge → stamp → plot |
| Script D0 … D9 (one each) | **done** | all green |
| PNG F1–F4 | **done** | `out/detf/singleSe/figures/` |
| PNG F7–F9 | **done** | F7–F9 |
| FINDINGS.md + AGENT_RESEARCH_REPORT.md | **done** | RQ1–RQ10 |
| SCENARIO_LOG rows | **done** | 2026-07-30 |
| Campaign PRD Progress/Results synced | **done** | 2026-07-30 |

**Next action:** Phase 4 litepaper prose (portfolio program) — do not casually re-run D0–D9.

---

## Results summary (living)

| ID | Result | Artifact |
|----|--------|----------|
| D0 | **PASS** — inert; defaults 1.05/0.95; mint reverts; warp inert | `out/detf/singleSe/D0_inert/` |
| D1 | **PASS** — first bond → live | `D1_firstBond/` |
| D2 | **PASS** — burn-side post-bond; mint blocked | `D2_policyDeadband/` |
| D3 | **PASS** — mint-allowed; preview==exec exact | `D3_policyMintAllowed/` |
| D4 | **PASS** — burn when synth < burnTh | `D4_policyBurnGate/` |
| D5 | **PASS** — Open mint/burn; no expansion | `D5_openControl/` |
| D6 | **PASS** — capital seigniorage supply ↑ | `D6_capitalSeigniorage/` |
| D7 | **PASS** — free holder no expansion airdrop | `D7_bondVsMint/` |
| D8 | **PASS** — Policy expansion; Open twin no | `D8_naturalExpansion/` |
| D9 | **PASS** — protocol BPT principal ↑ | `D9_protocolCompound/` |
| RQ1–RQ10 | **PASS** | [`FINDINGS.md`](./FINDINGS.md) |

---

## 1. Purpose

Execute the **full** Single Standard Exchange DETF research campaign:

1. Production-first **hermetic harness** with **Uni V2 SE** attached to Single SE DETF.  
2. **One Foundry research script per scenario D0–D9**.  
3. JSONL + `meta.json` + `NOTES.md` per run.  
4. **PNG figures F1–F4 and F7–F9**.  
5. Tracked **FINDINGS** + agent handoff + `SCENARIO_LOG` updates.

Phase 3 is **closed only when D0–D9 and required figures ship** (see § Acceptance). This is stricter than the campaign PRD’s historical “litepaper minimum D0–D5”; **this Phase 3 PRD defines done for Phase 3**.

---

## 2. Locked decisions (Phase 3 execution)

Do not re-open without revising **this** PRD (or the campaign PRD if product intent changes).

| Topic | Decision |
|-------|----------|
| **Definition of done** | **Full campaign through D9** + F1–F4 + F7–F9 + FINDINGS |
| **Script structure** | **One script per `Di`** (`Script_D0_…` … `Script_D9_…`) |
| **Shared fixture** | One research fixture contract reused by all scripts |
| **SE attachment** | **Uni V2 Standard Exchange** (WETH/USDC-style hermetic; continuity with Mode A / rateProviderCompare) |
| **DETF family** | `contracts/vaults/detf/standardExchange/single/` only |
| **Removed path** | No `composed/single` |
| **Synthetic drive (D3/D4/D8)** | **Production paths only:** free-DETF primary burns when burn-allowed (unwind bond free-DETF dilution) + real Uni V2 trades. **Forbidden:** Open thresholds, deal-seed DETF, storage hacks. Uni-trades-alone is empirically insufficient post-bond (see FINDINGS RQ5). |
| **D2** | Flexible / N/A if already mint-allowed at `t_live` |
| **Policy thresholds** | Default resolve 1.05e18 / 0.95e18 |
| **Open twin** | Separate deploy; no price gates; **no natural expansion** |
| **Expansion / compound** | Per campaign PRD RQ8–RQ10; D8/D9 required in Phase 3 |
| **Production-first** | CREATE3 + registry DFPkg; no mock SUT; role names only |
| **Foundry** | `FOUNDRY_PROFILE=default` unless documented exception |
| **Artifacts** | `research/out/detf/singleSe/<runId>/` only |
| **Tracked narrative** | `research/scenarios/detf/singleSe/` |
| **Scripts path** | `scripts/foundry/research/detf/singleSe/` |
| **Telemetry** | Reuse `scripts/foundry/research/harness/ResearchTelemetry.sol` (extend fields as needed) |
| **Plots** | Offline Python under `research/plots/` (new plotters only if new *kinds*) |
| **Runner** | `research/run_detf_single_se.sh` orchestrates D0→D9 + stamp + plot |

---

## 3. Relationship to other docs

| Doc | Owns |
|-----|------|
| Campaign [`DETF_Research_PRD.md`](./DETF_Research_PRD.md) | RQ1–RQ10, scenario *specs*, non-claims, product vocabulary |
| **This Phase 3 PRD** | Harness design, script IDs, run order, file tree, telemetry schema, plot mapping, Phase 3 acceptance |
| Program doc | Portfolio Phases 0–7; Phase 3 is one portfolio phase |
| Product PRDs | Behavior when code and research disagree |

---

## 4. Scope

### In scope (Phase 3)

- Research fixture: Uni V2 SE + Single SE DETF (Policy + Open deploy helpers)  
- Scripts **D0–D9** (ten scripts)  
- Telemetry + stamp_meta  
- Runner shell  
- PNG **F1–F4, F7–F9**  
- FINDINGS + AGENT_RESEARCH_REPORT + SCENARIO_LOG  
- Sync Progress/Results on campaign PRD when runs complete  

### Out of scope (Phase 3)

- Phase 1 SE matrix re-runs  
- Multi-family DETF empirics  
- Litepaper prose draft (Phase 4)  
- Frontend R4 publish (Phase 5)  
- Monte Carlo / mainnet APY  
- Production package changes (unless true product bug; separate PR)  

---

## 5. SUT & fixture architecture

### 5.1 Subject under test

| Piece | Identity |
|-------|----------|
| DETF | Single Standard Exchange DETF (production DFPkg + instance) |
| SE leg | Uni V2 Standard Exchange vault on hermetic Uni V2 WETH/USDC (or research-equivalent pair labels) |
| Bond | Full bond NFT vault path per family |
| Modes | Policy (default thresholds) and Open (D5, D8 control) |

### 5.2 Recommended fixture composition

| Building block | Reuse source (indicative) |
|----------------|---------------------------|
| IndexedEx + Balancer + Uni V2 SE | Patterns from `scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol` and/or `TestBase_UniswapV2StandardExchange` |
| DETF package + instance | Patterns from `TestBase_SingleStandardExchangeDETF` (registry deploy, bond NFT pkg, rate provider when `rateTarget` set) |
| **Do not** | Use Aero `daiUsdcVault` as research gold SE; do not mock SE/DETF |

**Proposed contract:**

```text
scripts/foundry/research/detf/singleSe/
  ResearchFixture_DetfSingleSeUniV2.sol   # setUp: Uni V2 SE + deploy helpers
  DetfSingleSeSample.sol                  # optional: sample → JSONL helpers
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
```

### 5.3 Fixture public surface (minimum)

Fixture (or sample helper) must expose enough for scripts to:

- Deploy **Policy** DETF (default thresholds)  
- Deploy **Open** DETF  
- Fund actor with **SE vault shares** (via SE deposit / LP path)  
- Execute **first bond** (family bond entry)  
- Execute **primary mint/burn** (`exchangeIn` / preview) vaultShare ↔ detfToken  
- Drive **Uni V2 trades** (both directions as needed)  
- Read: `isReserveLive`, `syntheticPrice`, thresholds, mode, `isMintingAllowed` / `isBurningAllowed`, `totalSupply`  
- Read bond: `pendingRewards(tokenId)` when available  
- Read protocol depth: protocol-owned BPT or documented equivalent  
- Call `compoundProtocolRewards` when available  
- `vm.warp` for expansion accrual tests  

---

## 6. Scenarios (execution mapping)

Normative **assert** text lives in the campaign PRD. This table is the **Phase 3 execution map**.

| Script ID | runId (artifact dir) | Mode | Drive | Phase 3 required |
|-----------|----------------------|------|-------|------------------|
| **D0** | `D0_inert` | Policy | Deploy only; optional short warp | **Yes** |
| **D1** | `D1_firstBond` | Policy | Fund shares; first bond | **Yes** |
| **D2** | `D2_policyDeadband` | Policy | Sample at `t_live`; mint attempt if deadband | **Yes** (N/A OK) |
| **D3** | `D3_policyMintAllowed` | Policy | Real Uni trades → synth > mintThreshold → mint + preview/exec | **Yes** |
| **D4** | `D4_policyBurnGate` | Policy | Real Uni trades → synth < burnThreshold → burn path | **Yes** |
| **D5** | `D5_openControl` | Open | Live; trades as needed; warp; no expansion | **Yes** |
| **D6** | `D6_capitalSeigniorage` | Policy | Sequence of allowed primary mints | **Yes** |
| **D7** | `D7_bondVsMint` | Policy | Parallel minter vs bonder; rewards eligibility | **Yes** |
| **D8** | `D8_naturalExpansion` | Policy (+ Open control sample OK) | Rich via **real trades** + warp; pendingRewards ↑ | **Yes** |
| **D9** | `D9_protocolCompound` | Policy (or Open if compound still applies) | Accrue protocol rewards → compound → protocol BPT ↑ | **Yes** |

**Run order (mandatory for full runner):**

```text
D0 → D1 → D2 → D3 → D4 → D5 → D6 → D7 → D8 → D9
```

Partial re-runs: any single `Script_Di` must be runnable alone (fresh hermetic bootstrap per script, unless script documents a hard dependency and runner enforces it).

**Default:** each script does a **fresh** fixture `setUp` (simplest correctness). Optional later optimization: shared world only if a script explicitly documents it.

---

## 7. Telemetry schema (normative fields)

### 7.1 Every row (minimum)

| Field | Type / unit | Notes |
|-------|-------------|-------|
| `step` | uint | 0-based within script |
| `scenarioId` | string | `D0`…`D9` |
| `thresholdMode` | string | `Policy` \| `Open` |
| `isReserveLive` | bool | |
| `syntheticPrice` | 1e18 | |
| `mintThreshold` | 1e18 | resolved |
| `burnThreshold` | 1e18 | resolved |
| `isMintingAllowed` | bool | |
| `isBurningAllowed` | bool | |
| `totalSupply` | uint | detfToken |
| `uniSpotIndex` | 1e18 optional | Uni demand documentation |
| `seRateIndex` | 1e18 optional | SE rate if sampled |

### 7.2 When applicable

| Field | Scenarios |
|-------|-----------|
| `previewOut` / `execOut` / `previewExecDelta` | D3, D4, mint/burn steps |
| `pendingRewards` | D5, D7, D8 (and others if bonded) |
| `bondTokenId` | D1+ |
| `protocolBpt` or `protocolDepth` | D1, D9 |
| `compoundCalled` | D9 |
| `expansionEligible` | derived flag in NOTES or series |
| `actorLabel` | D7: `minter` \| `bonder` |

### 7.3 `meta.json` (per runId)

- `campaign`: `detf/singleSe`  
- `phase`: `3`  
- `scenarioId`, `thresholdMode`  
- `script`: forge script path + contract name  
- `gitCommit`, forge version  
- thresholds after resolve  
- expansion params if readable  
- `seAttachment`: `uniswapV2`  

---

## 8. Artifact layout

```text
research/
  scenarios/detf/singleSe/
    DETF_Research_PRD.md                 # campaign law
    DETF_Research_Phase3_PRD.md          # this file
    FINDINGS.md                          # after Phase 3
    AGENT_RESEARCH_REPORT.md             # after Phase 3
  out/detf/singleSe/
    D0_inert/{meta.json,series.jsonl,NOTES.md,*.png?}
    D1_firstBond/...
    …
    D9_protocolCompound/...
    figures/                             # optional consolidated plot dir
      F1_lifecycle.png
      F2_synthetic_thresholds.png
      …
  run_detf_single_se.sh

scripts/foundry/research/detf/singleSe/
  ResearchFixture_DetfSingleSeUniV2.sol
  Script_D0_Inert.s.sol
  … Script_D9_ProtocolCompound.s.sol

research/plots/
  plot_detf_single_se_*.py               # as needed
```

**Rule:** narrative + scripts tracked; `out/` generated (gitignored).

---

## 9. Figure mapping (Phase 3 required)

| Fig | Content | Primary runIds | Format |
|-----|---------|----------------|--------|
| **F1** | Lifecycle inert → bond → live | D0, D1 | **PNG required** |
| **F2** | Synthetic vs peg + threshold bands | D2–D4 | **PNG required** |
| **F3** | Uni demand → synthetic (Policy) | D3 | **PNG required** |
| **F4** | Preview vs execution | D3 | **PNG required** |
| **F7** | Bond vs mint books / reward eligibility | D7 | **PNG required** |
| **F8** | Expansion Policy+time vs Open no-accrual | D5, D8 | **PNG required** |
| **F9** | Protocol compound BPT before/after | D9 | **PNG required** |

F5–F6 remain **SE appendix** (existing rateProviderCompare)—not produced in Phase 3; cite only.

---

## 10. Runner requirements

`research/run_detf_single_se.sh` must support:

| Flag / mode | Behavior |
|-------------|----------|
| (default) | Run D0→D9 forge scripts, stamp meta, plot F1–F4 + F7–F9 |
| `--d0` … `--d9` | Single scenario |
| `--from D3` | Resume from Di through D9 |
| `--plot-only` | Rebuild PNGs from existing JSONL |
| `--data-only` | Forge + stamp, no plots |

Use `FOUNDRY_PROFILE=default`. Document any offline/compile constraints in script header.

---

## 11. NOTES.md (per runId)

Required before a `Di` is marked done:

```markdown
# <runId>

## One-line story
…

## Setup
- DETF: Single SE; SE: Uni V2; mode: Policy|Open
- Drive: …

## Assertions
- RQ… pass/fail with numbers

## Charts / fields
…

## Mechanism
…

## Caveats
- Hermetic; no APY; expansion/compound labeled

## Commands
forge script …
```

---

## 12. Implementation milestones

### M0 — Scaffold

1. Create `scripts/foundry/research/detf/singleSe/`  
2. Fixture compiles and deploys Uni V2 SE + inert Policy DETF  
3. Telemetry writes one row to `out/detf/singleSe/_smoke/`  

### M1 — Lifecycle

4. Script D0 + D1 complete with NOTES  
5. F1 plottable  

### M2 — Gates

6. Scripts D2–D4 complete (D2 N/A documented if needed)  
7. F2–F4 PNGs  

### M3 — Open + capital books

8. Scripts D5–D7 complete  
9. F7 PNG  

### M4 — Expansion + compound

10. Scripts D8–D9 complete  
11. F8–F9 PNGs  

### M5 — Lock

12. FINDINGS.md answers RQ1–RQ10  
13. AGENT_RESEARCH_REPORT.md  
14. SCENARIO_LOG rows  
15. Campaign PRD Progress/Results updated  
16. Runner default path green  

---

## 13. Acceptance criteria (Phase 3 done)

Phase 3 is **complete** only if all of the following hold:

1. **All scripts D0–D9** exist, run under `FOUNDRY_PROFILE=default`, and each writes `series.jsonl` + stamped `meta.json` + `NOTES.md` under the normative `runId` dirs.  
2. **PNG F1–F4 and F7–F9** exist and are reproducible via runner `--plot-only` (or documented plot commands).  
3. **FINDINGS.md** answers campaign **RQ1–RQ10** with numbers or explicit pass/fail (D2 N/A allowed with documentation).  
4. **D5** demonstrates Open primary market open **and** no natural expansion.  
5. **D8** demonstrates Policy expansion positive path under production-drive rich synthetic (free-DETF burns when burn-allowed + Uni trades) + time.  
6. **D9** demonstrates protocol compound increases protocol-owned depth (BPT or documented metric).  
7. **D3** documents preview ≈ execution (exact preferred; ≤ few-wei only if forced and explained).  
8. Synthetic moves in D3/D4/D8 use **production paths only**: free-DETF primary burns when burn-allowed + real Uni V2 trades (NOTES confirm; no Open/deal).  
9. No mock SUT; Uni V2 SE attachment; no `composed/single`.  
10. Non-claims respected (no APY, no Open expansion, no all-holder rebase).  
11. `SCENARIO_LOG.md` updated; campaign PRD Progress/Results synced.  
12. `./research/run_detf_single_se.sh` (default) completes or documented known-failing segment with issue—**prefer full green**.  

---

## 14. Non-goals / non-claims (repeat for implementers)

- Not production feature work  
- Not frontend copy ship (may inform later Phase 5)  
- Not SE residual matrix re-run  
- No guaranteed peg, APY, claim coupon, or Olympus affiliation  

---

## 15. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Hard to push synthetic ±5% with Uni trades alone | Free-DETF primary burns (when burn-allowed) + larger Uni trades; document drive in NOTES (RQ5 PARTIAL) |
| D2 already mint-allowed after bond | Mark N/A per campaign PRD; rely on D3/D4 |
| Expansion params / time scale unclear | Read deploy-time storage or package defaults; use sufficient warp; cite values in meta |
| Protocol BPT metric hard to read | Document exact getter / accounting path in NOTES before D9 “pass” |
| Fixture stack-too-deep / compile | Split helpers; `FOUNDRY_PROFILE=default`; avoid via_ir research profile issues |
| Script reuse of state bugs | Default fresh setUp per script |

---

## 16. Success criteria (summary)

| Bar | Requirement |
|-----|-------------|
| Harness | Uni V2 SE + Single SE DETF, production-first |
| Coverage | D0–D9 scripts + NOTES |
| Figures | F1–F4, F7–F9 PNGs |
| Science lock | FINDINGS + agent report + SCENARIO_LOG |
| Claim safety | Campaign non-claims enforced |

---

## 17. Status log

| Date | Event |
|------|--------|
| 2026-07-30 | Phase 3 PRD created; **done = full D0–D9**; one script per Di; path beside campaign PRD |
| 2026-07-30 | Implementation plan: [`DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md) |

---

*End of Phase 3 PRD.*
