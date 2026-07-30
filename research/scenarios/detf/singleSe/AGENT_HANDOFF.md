# Agent handoff — Single SE DETF research (Phase 3 + litepaper)

| Field | Value |
|-------|--------|
| **Written** | 2026-07-30 |
| **Updated** | 2026-07-30 — Phase 3 **COMPLETE**; Mode B writing started |
| **Repo** | IndexedEx monorepo root (this file lives under `research/scenarios/detf/singleSe/`) |
| **Audience** | (1) **Implementation agent** — only if re-running / fixing harness; (2) **Research / writing agent** — **current default** |

**Read this entire file before coding or writing.** Do not re-open locked product or research decisions below without an explicit human PRD revision.

---

## 1. Mission (two modes)

### Mode A — Implementation agent (Phase 3)

**Status: COMPLETE (2026-07-30).** Do not re-run full D0–D9 casually.

**Artifacts locked:**

- Scripts D0–D9 under `scripts/foundry/research/detf/singleSe/`
- Out trees `research/out/detf/singleSe/D{0..9}_*/` + `figures/F1–F4,F7–F9`
- [`FINDINGS.md`](./FINDINGS.md) · [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md)
- Runner: `./research/run_detf_single_se.sh`
- Progress tables on campaign PRD, Phase 3 PRD, implementation plan show complete

**Re-run only if:** product PRD change (thresholds / expansion / compound), fixture SE attachment change, or missing local artifacts.

### Mode B — Research / writing agent (**do this next**)

**Goal:** Advance litepaper program Phases 1–2 and 4–5 using Phase 3 FINDINGS (do not re-run matrices casually).

**Primary docs:**

1. [`research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md`](../../../papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md)  
2. Phase 3 FINDINGS + agent report (this directory)  
3. SE rails (cite only): [`../../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md)  
4. Product narrative: [`docs/marketing/DETF_NARRATIVE_SPINE.md`](../../../../docs/marketing/DETF_NARRATIVE_SPINE.md)  
5. Compound/expansion handoff: [`contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md`](../../../../contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md)  

**Progress (Mode B):**

| Deliverable | Status |
|-------------|--------|
| Phase 1 figure harvest F5–F6 | **done** — [`FIGURE_MANIFEST.md`](../../../papers/detf-litepaper/FIGURE_MANIFEST.md) |
| Phase 2 `FORMAL_DEFINITIONS.md` | **done** |
| Phase 4 litepaper draft | **done** — [`LITEOPAPER_DRAFT.md`](../../../papers/detf-litepaper/LITEOPAPER_DRAFT.md) |
| Phase 5 frontend research notes (expansion/compound) | **done** — `detf.ts` + `bond-vs-mint.ts` |
| `MARKETING_AND_PERFORMANCE_FINDINGS.md` DETF section | **done** |
| Phase 0 BRIEF / OUTLINE polish | optional |
| PDF / public polish / R4 figure embeds | pending human review |

**Success:** Formal definitions + litepaper draft grounded in measured claims; frontend research notes aligned; science roll-up updated.

---

## 2. What this project is

Research campaign to **prove DETF merits** for a **litepaper** (then optional whitepaper):

- Hermetic, **production-first** Foundry research scripts (not unit-test replacements).  
- Gold family: **Single Standard Exchange DETF** only.  
- SE leg for research: **Uni V2 WETH/USDC** (narrative continuity with Mode A / rateProviderCompare).  
- Also covers **protocol compound** + **natural supply expansion** (product law LOCKED 2026-07-30).

**Not goals:** mainnet APY, Monte Carlo yield, re-running SE rate matrices, multi-family empirics, `composed/single` (removed).

---

## 3. Locked decisions (do not reopen)

| Topic | Decision |
|-------|----------|
| Gold DETF | `contracts/vaults/detf/standardExchange/single/` only |
| Removed package | **No** `composed/single` / SingleVaultDetf |
| SE attachment | **Uni V2 SE** hermetic — **not** Aero TestBase default |
| Synthetic drive (D3/D4/D8) | **Production paths only:** free-DETF primary burns when burn-allowed + real Uni V2 trades (no Open/deal). Uni-only insufficient post-bond (RQ5 PARTIAL) |
| D2 deadband | Flexible: **N/A OK** if already mint-allowed at `t_live` |
| Phase 3 done bar | **Full D0–D9** + PNG **F1–F4 and F7–F9** + FINDINGS RQ1–RQ10 — **MET** |
| Scripts | **One forge script per Di** |
| Fresh world | Default: each script full fixture bootstrap |
| Policy thresholds | Default resolve **1.05e18 / 0.95e18** |
| Open | No price gates when live; **never natural expansion** |
| Expansion | Policy + live + synth > mintThreshold only; bond ledger only |
| Protocol compound | Protocol NFT rewards → protocol BPT; users claim free DETF |
| Foundry | `FOUNDRY_PROFILE=default` |
| Production-first | CREATE3 + registry DFPkg; **no mock SUT** |
| Chart framing | Research README conventions; no invented APY |

**Conflict rule:** Product PRDs (threshold modes, compound/expansion) win on behavior. Campaign PRD wins on scenario intent. Phase 3 PRD wins on Phase 3 acceptance. Implementation plan wins on file layout / milestone order.

---

## 4. Progress at handoff

### Done (implementation)

| Item | Location / note |
|------|-----------------|
| Campaign PRD | `DETF_Research_PRD.md` |
| Phase 3 PRD | `DETF_Research_Phase3_PRD.md` |
| Implementation plan | `DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md` (**COMPLETE**) |
| Litepaper program | `research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md` |
| Research fixture | `scripts/foundry/research/detf/singleSe/ResearchFixture_DetfSingleSeUniV2.sol` |
| Scripts D0–D9 | all under `scripts/foundry/research/detf/singleSe/` |
| Out + figures | `research/out/detf/singleSe/` (D0–D9 + F1–F4, F7–F9) |
| FINDINGS + agent report | this directory |
| Runner | `research/run_detf_single_se.sh` |

### Done / in progress (writing)

| Item | Status |
|------|--------|
| `FORMAL_DEFINITIONS.md` | done |
| `FIGURE_MANIFEST.md` (F1–F9 incl. SE F5–F6) | done |
| `LITEOPAPER_DRAFT.md` | done (Phase 4 draft) |
| Frontend research notes expansion/compound | done (`detf.ts`, `bond-vs-mint.ts`) |
| Marketing roll-up DETF section | done |

---

## 5. Doc and code map

```text
research/
  papers/detf-litepaper/
    RESEARCH_AND_WRITING_PROGRAM.md
    FORMAL_DEFINITIONS.md              # Phase 2
    FIGURE_MANIFEST.md                 # Phase 1 + 3 figures
    LITEOPAPER_DRAFT.md                # Phase 4 draft
  scenarios/detf/singleSe/
    AGENT_HANDOFF.md                   # THIS FILE
    DETF_Research_PRD.md
    DETF_Research_Phase3_PRD.md
    DETF_Research_Phase3_IMPLEMENTATION_AND_TEST_PLAN.md
    FINDINGS.md
    AGENT_RESEARCH_REPORT.md
  out/detf/singleSe/                   # generated (gitignored)
  run_detf_single_se.sh

scripts/foundry/research/detf/singleSe/
  ResearchFixture_DetfSingleSeUniV2.sol
  Script_D0_Inert.s.sol … Script_D9_ProtocolCompound.s.sol
```

---

## 6. Implementation agent — work order (maintenance only)

| Order | Work |
|-------|------|
| 1 | If artifacts missing: `./research/run_detf_single_se.sh` |
| 2 | If product law changes: update scripts + FINDINGS + figures; re-lock agent report |
| 3 | Do **not** re-run `run_rate_provider_compare.sh` unless SE params change |

### Reproduce D0 (sanity)

```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D0_Inert.s.sol:Script_D0_Inert -vv
```

### Hard constraints

- No `MockStandardExchange` / mock DETF / manager.  
- No `composed/single`.  
- Label **capital seigniorage** vs **natural expansion** separately.  
- D3/D4/D8: no Open/deal synthetic drive.

---

## 7. Research / writing agent — work order

| Order | Work |
|-------|------|
| 1 | Read FINDINGS + AGENT_RESEARCH_REPORT; do **not** re-run full D0–D9 casually |
| 2 | ~~Phase 1 F5–F6 harvest~~ **done** (FIGURE_MANIFEST) |
| 3 | ~~Phase 2 FORMAL_DEFINITIONS~~ **done** |
| 4 | ~~Phase 4 litepaper draft~~ **done** — human review / PDF polish next |
| 5 | Phase 5: frontend `/research` notes (Policy/Open expansion; bond rewards; compound) per product-voice + handoff |
| 6 | Update `MARKETING_AND_PERFORMANCE_FINDINGS.md` with DETF section |
| 7 | Optional: BRIEF.md / OUTLINE.md / CLAIMS_MATRIX.md Phase 0 polish |

**Claims matrix:** C1–C13 in litepaper program (C12 expansion, C13 protocol compound).

---

## 8. Research questions (campaign) — all answered in FINDINGS

| ID | Topic | Result |
|----|--------|--------|
| RQ1–RQ2 | Inert → first bond live | PASS |
| RQ3–RQ5 | Policy mint/burn + synthetic drive | PASS (RQ5 partial: Uni alone insufficient) |
| RQ6 | Preview == execution | PASS exact |
| RQ7 | Open ungated primary market | PASS |
| RQ8 | Expansion only Policy+rich | PASS |
| RQ9 | Expansion/seigniorage on bond ledger | PASS |
| RQ10 | Protocol compound → protocol BPT | PASS |

---

## 9. Prompt templates

### For research/writing agent (current)

```text
You are continuing IndexedEx DETF litepaper research writing after Phase 3 implementation.

Read:
- research/scenarios/detf/singleSe/AGENT_HANDOFF.md
- research/scenarios/detf/singleSe/FINDINGS.md
- research/scenarios/detf/singleSe/AGENT_RESEARCH_REPORT.md
- research/papers/detf-litepaper/LITEOPAPER_DRAFT.md
- research/papers/detf-litepaper/FORMAL_DEFINITIONS.md
- research/papers/detf-litepaper/FIGURE_MANIFEST.md
- research/papers/detf-litepaper/RESEARCH_AND_WRITING_PROGRAM.md
- contracts/vaults/detf/DETF_Protocol_Compound_And_Supply_Expansion_HANDOFF_FOR_DOCS_AND_UI.md

Phase 3 is LOCKED. Do not re-run full hermetic matrices unless FINDINGS are missing.

Continue Phase 5: frontend research note alignment + MARKETING_AND_PERFORMANCE_FINDINGS DETF section.
No invented APY; Open does not expand; label capital seigniorage vs natural expansion.
```

### For implementation agent (maintenance)

```text
Phase 3 is complete. Only re-run ./research/run_detf_single_se.sh if artifacts missing or product law changed.
Read AGENT_HANDOFF.md + FINDINGS.md first. Do not re-run SE rateProviderCompare.
```

---

## 10. Definition of “implementation agent done”

- [x] Scripts D0–D9 exist and run under `FOUNDRY_PROFILE=default`  
- [x] Each runId has series.jsonl + meta.json + NOTES.md  
- [x] PNG F1–F4 and F7–F9 exist and are reproducible  
- [x] FINDINGS answers RQ1–RQ10  
- [x] AGENT_RESEARCH_REPORT.md written  
- [x] SCENARIO_LOG / Progress tables complete  
- [x] No mock SUT; Uni V2 SE; claim-safe language  

---

## 11. Status log

| Date | Event |
|------|--------|
| 2026-07-30 | Handoff written: planning complete; D0 PASS; D1–D9 for next agent |
| 2026-07-30 | Phase 3 complete (D0–D9 + figures + FINDINGS) |
| 2026-07-30 | Mode B: FORMAL_DEFINITIONS, FIGURE_MANIFEST, LITEOPAPER_DRAFT authored; handoff flipped to writing |

---

*End of handoff.*
