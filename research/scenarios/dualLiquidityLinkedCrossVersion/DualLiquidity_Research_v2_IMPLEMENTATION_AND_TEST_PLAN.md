# DualLiquidity Research v2 — Implementation and Execution Plan

## Purpose

Execute the [DualLiquidity Research v2 PRD](./DualLiquidity_Research_v2_PRD.md): ship **linked volume attribution** and **share-book hero charts** for DualLiquidity, without re-running the full v1 R+/R− residual matrix.

## Status

**PLANNED** — ready for execution after PRD acceptance.

### Locked decisions (summary)

| Topic | Decision |
|-------|----------|
| Normative PRD | [`DualLiquidity_Research_v2_PRD.md`](./DualLiquidity_Research_v2_PRD.md) |
| Primary | Mode B **route matrix** volume attribution (rates-off) |
| Mode B routes | Broader matrix: P0 deposits common/tokenA/tokenB; P1 SE-share deposits + tokenA↔tokenB swap; P2 optional (see PRD) |
| H2 bar | **BPT + ≥1 SE leg** (aggregate across matrix OK) |
| Mode A mark | **v1 full-exit as-is** |
| Scale | **Match v1** Mode B / Mode A sizes unless smoke flat |
| Rates-on | **Not in default runner** |
| Secondary | Mode A share full-exit P&L (rates-off) |
| Stretch | Elevated size; rates-on twin; Mode C if residual → ~0.3% |
| Out root | `research/out/dualLiquidityLinkedCrossVersion/v2/` only |
| v1 trees | **Do not overwrite** `rates_*` / `compare/` from 2026-07-21 |
| SUT | Production DualLiquidity + existing research fixture |
| Profile | `FOUNDRY_PROFILE=default` |
| Fee | Reserve **0.3%** (`0.003e18`) in meta |

---

## 1. Goals and non-goals

### Goals

1. Lock **attribution model** (which balances count as “leg activity”).
2. Extend fixture sampling for volume + share-book fields.
3. Mode B rates-off scripts → `volume_by_leg` plot.
4. Mode A rates-off scripts → share-book P&L plot (polish v1 mark path).
5. `FINDINGS_v2.md`, roll-up update, SCENARIO_LOG.
6. Optional elevated tier only if Mode B multi-surface signal is weak.

### Non-goals

- Re-proving residual fairness (cite v1).
- Mode C as a done gate.
- Other DETF packages / Uni V2 SE artifact overwrites.
- Mainnet APY.

---

## 2. Naming and layout

### Source

```text
scripts/foundry/research/dualLiquidityLinkedCrossVersion/
  ResearchFixture_DualLiquidity.sol              # EXTEND (volume + attribution + multi-route helpers)
  Script_V2_RatesOff_ModeB_DepositCommon.s.sol   # P0
  Script_V2_RatesOff_ModeB_DepositTokenA.s.sol   # P0
  Script_V2_RatesOff_ModeB_DepositTokenB.s.sol   # P0
  Script_V2_RatesOff_ModeB_DepositPairShare.s.sol  # P1
  Script_V2_RatesOff_ModeB_DepositVaultAShare.s.sol  # P1 (optional vaultB twin)
  Script_V2_RatesOff_ModeB_SwapTokenATokenB.s.sol    # P1 volume driver
  Script_V2_RatesOff_ModeA_LegDemand.s.sol
  # P2 / optional: swap_common_*, deposit_bpt, rates_on twins
research/run_dual_liquidity_research_v2.sh
research/plots/plot_dual_liquidity_v2.py
```

### Tracked narrative

```text
research/scenarios/dualLiquidityLinkedCrossVersion/
  DualLiquidity_Research_v2_PRD.md
  DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md   # this file
  FINDINGS_v2.md                                              # after runs
```

### Artifacts

```text
research/out/dualLiquidityLinkedCrossVersion/v2/
  rates_off/modeB_depositCommon/
  rates_off/modeA_legDemand/
  rates_off/modeB_<route>/          # optional second route
  rates_on/...                      # optional
  elevated/...                      # optional
  stress/...                        # Mode C only
```

### Inheritance

```text
ResearchFixture_DualLiquidity (v1)
        │
        ├─ sampleVolumeAttribution()   // NEW
        ├─ sampleShareBookMark()       // polish / alias v1 full-exit
        └─ writeMetaV2()               // researchVersion: 2, attributionModel
```

Scripts: thin wrappers that set `outDir` under `v2/`, call bootstrap, loop drive + sample.

**Anti-pattern:** `new` package/facets; overwriting v1 `out/` leaves.

---

## 3. Attribution model (normative — lock in Phase 0)

Pick **one** stack and document it in every meta as `attributionModel`.

### Recommended default (`reserve_live_plus_alice_shares`)

| Surface | Measurement each step |
|---------|------------------------|
| `vaultA` | `reservePool` live balance of vaultA SE share token (raw, 1e18) **and/or** Δ vs t0 |
| `vaultB` | Same for vaultB share |
| `pairVault` | Same for pairVault share |
| `reserveBpt` | Alice DualLiquidity path: diamond-held free BPT + alice share claim via full-exit BPT if distinct — **document** |
| Alice shares | DualLiquidity ERC-20 balance + full-exit mark |

Also record absolute levels (not only Δ) so plots can show cumulative activity.

### Alternative (if live balances noisy)

`alice_and_diamond_free_inventory` — free SE shares + BPT on diamond and alice only (ignore pool live). Prefer default first; switch only if Phase 0 smoke fails interpretability.

### Forbidden

- Silent mixing of different stacks mid-campaign.
- Inferring “volume” solely from DualLiquidity `totalSupply` without nested fields.

---

## 4. Telemetry schema (minimum JSONL fields)

Reuse v1 fields where present; **add**:

```text
# identity
step, routeTag, useRateProviders, researchVersion

# volume (absolute after step)
liveVaultA, liveVaultB, livePairVault,   // reserve live SE share balances
balAliceShares, balDiamondBpt,          // or documented equivalents
dLiveVaultA, dLiveVaultB, dLivePairVault, dBalAliceShares, dBalDiamondBpt

# share book
markFullExit, pnlNorm, portfolioExitBpt   // align names with v1 if possible

# Mode B quality
previewOut, execOut, previewGap

# optional residual (not hero)
residualA, midIndexA, rateIndexA
```

`meta.json` extras: `researchVersion: 2`, `attributionModel`, `reserveSwapFee`, `mode`, `runId`, sizes/steps, `gitCommit`.

---

## 5. Phases

### Phase 0 — Fixture + smoke (½–1 day wall-clock incl. fork)

1. Read v1 fixture sample path; add volume readers (reserve live balances for three SE share tokens).
2. Smoke: bootstrap rates-off → 1–3 Mode B deposits → print live vaultA/B/pair + alice shares + BPT.
3. Confirm non-zero Δ somewhere nested; freeze `attributionModel` string.
4. Write sample JSONL line shape; no full matrix yet.

**Exit:** smoke series under `v2/rates_off/smoke/` (optional) or developer notes in plan checklist.

### Phase 1 — Mode B rates-off route matrix (**primary**)

1. **P0 scripts** at **v1 Mode B sizes/steps**: `deposit_common`, `deposit_tokenA`, `deposit_tokenB`.
2. Artifacts: `v2/rates_off/modeB_<routeTag>/{series.jsonl,meta.json}` per route.
3. **P1** same session if time: `deposit_pairShare`, `deposit_vaultAShare` (± vaultB), `swap_tokenA_tokenB`.
4. Plot: per-route `volume_by_leg.png` + optional multi-route atlas panel.
5. H2 evaluation: **aggregate** across matrix — need BPT + ≥1 SE leg non-zero somewhere; not every route.

**Exit:** H1/H2 pass/fail visible from plots + series; unsupported routes logged, not forced.

### Phase 2 — Mode A rates-off share book

1. Script: modest V4 common→tokenA path (v1 Mode A size OK).
2. Artifacts: `v2/rates_off/modeA_legDemand/`.
3. Plot: `share_book_pnl.png` / reuse pnl_normalized conventions.
4. Residual series optional; cite v1 for fairness narrative.

**Exit:** H3 plot ready for roll-up graph map.

### Phase 3 — Narrative + roll-up

1. Write `FINDINGS_v2.md` (H1–H4, graph paths, marketing checklist).
2. Append section to `AGENT_RESEARCH_REPORT.md` **or** create `AGENT_RESEARCH_REPORT_v2.md`.
3. Update:
   - `research/MARKETING_AND_PERFORMANCE_FINDINGS.md` (§3.4, §4, §5, changelog)
   - `research/SCENARIO_LOG.md`
   - `research/README.md` if it lists campaigns
4. Stamp meta with git commit.

**Exit:** v2 marked complete in FINDINGS_v2 without Mode C.

### Phase 4 — Optional only

| Trigger | Action |
|---------|--------|
| Mode B only moves one surface weakly | Elevated deposit size / steps under `v2/elevated/` |
| Deck needs rates panel | Single rates-on Mode B or Mode A twin |
| residualA approaches 0.3% | Mode C stretch under `v2/stress/` |

---

## 6. Runner sketch

```bash
# research/run_dual_liquidity_research_v2.sh
FOUNDRY_PROFILE=default
# flags:
#   --smoke | --mode-b-only | --mode-a-only | --elevated
#   --routes p0 | p0p1 | all   (default: p0p1)
#   --route <routeTag>         (single route)
# rates-on NOT in default path
# requires Base fork RPC (foundry.toml base_mainnet_alchemy + key)
```

Order default: smoke → Mode B P0 → Mode B P1 → Mode A → plot → stamp.

Do **not** invoke full monorepo `forge test` as a gate for research scripts.

---

## 7. Plot requirements

| Output | Input | Notes |
|--------|-------|-------|
| `volume_by_leg.png` | Mode B series | Cumulative `dLive*` or absolute live balances; legend vaultA/B/pair/BPT |
| `share_book_pnl.png` | Mode A series | Normalized mark; LP/holder framing |
| `inventory.png` | either | Optional composition |

Reuse `research/plots/common.py` / stamp helpers. Prefer new `plot_dual_liquidity_v2.py` over breaking v1 compare plots.

---

## 8. Verification checklist

### Structural

- [ ] No writes outside DualLiquidity research scripts, plots, scenario docs, `out/.../v2/`
- [ ] v1 `out/dualLiquidityLinkedCrossVersion/rates_*` untouched
- [ ] Production deploy path only

### Empirical

- [ ] Mode B series has attribution fields populated
- [ ] `volume_by_leg.png` exists and is human-readable
- [ ] Mode A share-book plot exists
- [ ] H1–H4 recorded pass/fail in FINDINGS_v2

### Marketing

- [ ] Roll-up §5: “volume engine” claim moved to ready **or** explicit partial with caveats
- [ ] Graph map points at `v2/...` paths

---

## 9. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Fork flaky / slow | Smoke first; cache build; Mode B before Mode A |
| Live balances of SE shares don’t move on deposit-only | Document join path; measure diamond BPT + SE mint into pool; elevated size; second route |
| Stack-too-deep in sample | Split helpers (v1 pattern: storage alice, split sample) |
| Overclaim equal multi-leg flow | H2 = multi-surface, not equal weights |

---

## 10. Execution order (checklist)

0. [ ] Phase 0 attribution lock + smoke  
1. [ ] Phase 1 Mode B volume  
2. [ ] Phase 2 Mode A share book  
3. [ ] Phase 3 FINDINGS_v2 + roll-up + log  
4. [ ] Phase 4 only if needed  

---

## Related

| Doc | Role |
|-----|------|
| [v2 PRD](./DualLiquidity_Research_v2_PRD.md) | Normative questions / success |
| [v1 FINDINGS](./FINDINGS.md) | Rates + preview (cite) |
| [v1 agent report](./AGENT_RESEARCH_REPORT.md) | Prior handoff |
| [Marketing roll-up](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) | Claims index |

---

*Ready to implement when PRD accepted. First code touch: fixture volume sample + Mode B out path under `v2/`.*
