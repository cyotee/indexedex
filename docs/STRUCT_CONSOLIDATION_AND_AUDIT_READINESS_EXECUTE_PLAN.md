# Execute Plan — Struct Consolidation + Audit Readiness Review

> **For agentic workers:** This is a **read-only, multi-agent review** plan. Orchestrator launches parallel subagents, collects area reports, then writes the aggregate. **Do not modify production contracts** unless a later implementation phase is explicitly authorized.

**Goal:** Produce per-area and aggregate reports that inventory structs, flag redundant members / collapse opportunities (gas + stack-safe, no `via_ir`), and assess external-audit readiness.

**Normative law:** [`STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md`](./STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md) (v0.2+; §14 locked decisions).

**Primary skill / constraints:**

- `via_ir` forbidden; stack relief via structs/helpers only (`crane-code-style`)
- DETF role names only (`rateAsset`, `pairToken`, …) — see `Claude.md`
- Production-first verification ideas (no SUT mocks in recommendations)
- Pre-launch storage may change (with tests); hermetic gas first

**Repo root:** workspace root of IndexedEx (`lib/indexedex`).

---

## 0. Run parameters (orchestrator sets once)

| Parameter | How to set | Default |
|-----------|------------|---------|
| `MODE` | User says pilot or full; if silent, prefer **pilot** then offer full | `pilot` |
| `RUN_DATE` | ISO date of this run | today `YYYY-MM-DD` |
| `REPORT_DIR` | Output directory | `docs/reviews` |
| `PRD` | Law file | `docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md` |
| `CAPABILITY` | Subagent tools | **read-only** (no file edits to contracts; reports **are** written by agents that have write access to `docs/reviews/` only — if tool policy is global, orchestrator writes reports from subagent returns) |

**Output naming:**

```text
docs/reviews/{RUN_DATE}_struct-audit_{AREA_ID}.md
docs/reviews/{RUN_DATE}_struct-audit_AGGREGATE.md
```

Example: `docs/reviews/2026-08-08_struct-audit_A-hooks-v4.md`

---

## 1. Global constraints (every agent)

Copy into every subagent prompt:

```text
HARD RULES:
1. Read-only review of contracts/research — do not edit *.sol production code.
2. Never recommend via_ir / viaIR. Stack fixes = structs, helpers, block scope only.
3. DETF role names only (rateAsset, pairToken, underlyingVault, vaultShare, detfToken, reservePool/reserveBpt, rebasingClaimToken).
4. PkgInit/PkgArgs live on interfaces; flag if defined only on contracts.
5. Gas: collapsing structs is not always a win. Every collapse needs: gas dir, hot path?, stack risk, ABI/storage break?, confidence.
6. Storage (pre-launch): packing/layout changes allowed later with tests; still label storage migration risk.
7. Gas measurement environment: hermetic first; fork only if hermetic cannot exercise path.
8. Stay inside path allowlist. Out-of-area deps: cite as reference only.
9. Findings IDs: S-<area>-NNN (struct/gas), A-<area>-NNN (audit). Severity: Blocker/High/Medium/Low/Nit per PRD / CODE_REVIEW_PLAN.
10. Write report ONLY to the assigned OUT_FILE path (or return full markdown for orchestrator to write).
```

---

## 2. Mode definitions

### 2.1 Pilot (`MODE=pilot`) — recommended first run

| Area ID | Allowlist | OUT_FILE |
|---------|-----------|----------|
| `A-hooks-v4` | `contracts/hooks/**` | `{REPORT_DIR}/{RUN_DATE}_struct-audit_A-hooks-v4.md` |
| `A-detf-univ4` | `contracts/vaults/detf/protocols/dexes/uniswap/**` | `{REPORT_DIR}/{RUN_DATE}_struct-audit_A-detf-univ4.md` |
| `A-detf-core` | `contracts/vaults/detf/common/**` | `{REPORT_DIR}/{RUN_DATE}_struct-audit_A-detf-core.md` |

**Parallelism:** spawn **3** area subagents at once.

### 2.2 Full (`MODE=full`)

| Area ID | Allowlist | OUT_FILE | Notes |
|---------|-----------|----------|-------|
| `A-detf-core` | `contracts/vaults/detf/common/**` | `…_A-detf-core.md` | |
| `A-detf-balancer` | `contracts/vaults/detf/protocols/dexes/balancer/**` | `…_A-detf-balancer.md` | |
| `A-detf-univ4` | `contracts/vaults/detf/protocols/dexes/uniswap/**` | `…_A-detf-univ4.md` | |
| `A-se-vaults` | `contracts/vaults/**` **excluding** `contracts/vaults/detf/**` | `…_A-se-vaults.md` | |
| `A-hooks-v4` | `contracts/hooks/**` | `…_A-hooks-v4.md` | |
| `A-routers` | `contracts/routers/**` | `…_A-routers.md` | |
| `A-manager-fee-oracle` | `contracts/manager/**`, `contracts/fee/**`, `contracts/oracles/**` | `…_A-manager-fee-oracle.md` | |
| `A-interfaces-types` | `contracts/interfaces/**` | `…_A-interfaces-types.md` | Also scan interface structs defined co-located in DFPkg interfaces under allowlisted packages if found while grepping — note as dual-home |
| `A-protocols` | `contracts/protocols/**` | `…_A-protocols.md` | Large; may **wave-split** (§2.3) |
| `A-research` | `research/**` | `…_A-research.md` | Inventory + dupe vs production; deep audit optional |

**Parallelism:** prefer **4–6 concurrent**; run waves if tool budget is tight (§3.3).

### 2.3 Optional wave-split for `A-protocols` (if single agent times out)

Only if needed; otherwise one agent owns all of `contracts/protocols/**`.

| Sub-area | Paths |
|----------|--------|
| `A-protocols-dex` | `contracts/protocols/dexes/**` |
| `A-protocols-lending` | `contracts/protocols/lending/**` |
| `A-protocols-staking` | `contracts/protocols/staking/**` |

Orchestrator merges sub-reports into one `…_A-protocols.md` **or** lists all three in aggregate as separate areas (prefer single merged file for scoring simplicity).

---

## 3. Orchestrator checklist

### Task O0 — Bootstrap

- [ ] **Step 1:** Confirm `MODE` with user if not specified (`pilot` recommended).
- [ ] **Step 2:** Set `RUN_DATE` (today).
- [ ] **Step 3:** Read PRD fully: `docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md` (especially §§2–8, 14).
- [ ] **Step 4:** Skim `Claude.md` non-negotiables + `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md` for stack context.
- [ ] **Step 5:** Ensure `docs/reviews/` exists; do not overwrite prior run files without user OK (new `RUN_DATE` avoids clobber).
- [ ] **Step 6:** Write a short run header stub for aggregate (metadata only), or hold until end.

### Task O1 — Optional pre-inventory (orchestrator, cheap)

Helps detect empty areas and size budgets. **Non-blocking** if slow.

- [ ] **Step 1:** Run struct definition counts per area:

```bash
# From repo root — adapt globs per MODE
rg -c --type sol '^\s*struct\s+\w+' contracts/hooks contracts/vaults/detf/common \
  contracts/vaults/detf/protocols/dexes/uniswap 2>/dev/null | sort -t: -k2 -nr | head -40

# Full mode add:
# rg -c --type sol '^\s*struct\s+\w+' contracts/protocols research contracts/routers \
#   contracts/manager contracts/fee contracts/oracles contracts/interfaces \
#   contracts/vaults --glob '!**/detf/**' 2>/dev/null | head -60
```

- [ ] **Step 2:** Note top files by match count for prompt hints (stack-hot targets).

### Task O2 — Spawn area subagents (parallel)

- [ ] **Step 1:** For each area in the active mode table, spawn **one** subagent in parallel with:
  - `subagent_type`: `explore` (read-only) **or** `general-purpose` with instruction not to edit contracts
  - `capability_mode`: `read-only` if available; if agent must write report file, allow write **only** under `docs/reviews/`
  - `description`: `struct-audit {AREA_ID}`
  - `prompt`: **§4 Area agent prompt template** with substitutions filled
- [ ] **Step 2:** Do **not** wait serially; launch all pilot agents (or wave of full agents) together.
- [ ] **Step 3:** On subagent completion, verify `OUT_FILE` exists and has mandatory sections (§5). If content returned in chat only, **orchestrator writes** the file.

### Task O3 — Fail-soft collection

- [ ] **Step 1:** For each area: status `COMPLETE` | `PARTIAL` | `FAILED`.
- [ ] **Step 2:** Failed areas: one-paragraph error in aggregate; do not block other areas.
- [ ] **Step 3:** Partial areas: require at least inventory table + any findings found; list remaining work.

### Task O4 — Cross-cut pass (orchestrator, sequential after areas)

- [ ] **Step 1:** Build **union inventory** (struct name + file + area + kind).
- [ ] **Step 2:** Detect **cross-area duplicates** (same/near-same member sets; e.g. `HarvestParams`, `PkgArgs`, mint scratch types). Include research↔production pairs.
- [ ] **Step 3:** Resolve **conflicts** (collapse vs do-not-collapse) with explicit orchestrator decision.
- [ ] **Step 4:** Score findings per PRD §8; produce **Top 25** backlog.
- [ ] **Step 5:** Build **gas measurement shortlist** (hermetic commands only unless path needs fork).
- [ ] **Step 6:** Scorecard per area: `READY` / `NEEDS_WORK` / `BLOCKED`.

### Task O5 — Write aggregate report

- [ ] **Step 1:** Write `{REPORT_DIR}/{RUN_DATE}_struct-audit_AGGREGATE.md` using §6 schema.
- [ ] **Step 2:** Verify PRD acceptance criteria AC1–AC8.
- [ ] **Step 3:** Present user summary: Top 10 backlog bullets + path to aggregate + list of area files.
- [ ] **Step 4:** **Stop.** Do not implement refactors unless user authorizes a new implementation plan.

### Task O6 — Optional verification (non-blocking)

- [ ] Optionally run `forge build` once to note baseline compile health (do not “fix” stack-too-deep in this program).
- [ ] Do **not** run full monorepo test suite as part of this review unless user asks.

---

## 4. Area agent prompt template

Substitute `{AREA_ID}`, `{ALLOWLIST}`, `{OUT_FILE}`, `{RUN_DATE}`, `{PRD_PATH}`, `{MODE}`, and optional `{FOCUS_HINTS}`.

```text
You are an area review subagent for IndexedEx struct consolidation + audit readiness.

## Identity
- Area ID: {AREA_ID}
- Mode: {MODE}
- Run date: {RUN_DATE}
- Path allowlist (ONLY these paths for deep review):
  {ALLOWLIST}
- Output file: {OUT_FILE}
- Normative PRD: {PRD_PATH}
  Read PRD sections 2 (constraints), 3 (gas model), 6 (workstreams), 7 (report schema), 14 (locked decisions).

## Hard rules
{PASTE GLOBAL CONSTRAINTS FROM §1}

## Research-area special case
If AREA_ID is A-research:
- Mandatory: full struct inventory under research/** (Solidity + any struct-like param bags in .sol research helpers).
- Mandatory: map duplicates / mirrors of production contracts/** types.
- Optional: deep audit findings; mark research-only unless normative mainnet rehearsal.

## Workstreams (all required unless research optional audit)
1. Struct inventory table (PRD §6.1).
2. Redundant member findings (PRD §6.2).
3. Collapse / consolidation proposals C1–C6 (PRD §6.3) with gas dir, stack risk, ABI/storage break, confidence.
4. Do-not-collapse list (PRD §6.5) — required even if empty (state why empty only if zero structs).
5. Gas notes for hot paths in this area; hermetic measurement ideas.
6. Audit readiness findings (PRD §6.4) — access, reentrancy, storage, tokens, economic, tests, NatSpec, deploy rules, dead code, DETF naming.

## Method
1. Inventory:
   rg -n --type sol '^\s*struct\s+\w+' {allowlist roots}
2. For high-density or stack-hot files, read entrypoints (external/public money paths) and trace helper chains.
3. Prefer evidence with path:line ranges.
4. Do not invent gas %; use positive/neutral/negative/unknown + confidence.
5. Focus hints (optional): {FOCUS_HINTS}

## Deliverable
Write markdown to OUT_FILE with EXACT section headers from PRD §7.2:

# Struct + Audit Readiness Review — {AREA_ID}
- Date, Agent/role, Scope paths, Out of scope notes, Status, Commands/tools used
## 1. Executive summary
## 2. Struct inventory
## 3. Redundant members
## 4. Collapse / consolidation proposals
## 5. Do-not-collapse list
## 6. Gas notes
## 7. Audit readiness findings
## 8. Suggested implementation order (for later plan)
## 9. Open questions

Use finding tables with columns:
ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now?

IDs: S-{AREA_ID}-001… and A-{AREA_ID}-001…

## Done criteria for you
- Status COMPLETE if inventory done and workstreams addressed.
- Status PARTIAL if timeboxed with inventory + partial findings (list gaps in §9).
- Never edit contracts. Never recommend via_ir.
```

### 4.1 Suggested focus hints (orchestrator may paste)

| Area | Focus hints |
|------|-------------|
| `A-hooks-v4` | Orbital buffer hook Target; known stack-too-deep history; swap/liquidity callback paths |
| `A-detf-univ4` | Orbital DETF exchange in/out; rebasing claim common; burn residual structs |
| `A-detf-core` | Bond NFT HarvestParams/RedeemParams; shared factory component structs |
| `A-detf-balancer` | MultiVault / MixedBuffer / ComposedStable DeployConfig + MintSplit; family-local bond harvest clones |
| `A-se-vaults` | Slipstream Position/StrategyConfig; ConstProdReserve; BasicVault Storage packing |
| `A-routers` | Coordinator RouteStep / SwapExactInParams; Permit2 witness; nested route structs |
| `A-manager-fee-oracle` | PkgInit/PkgArgs; VaultFeeTypes BondTerms; fee oracle Storage |
| `A-interfaces-types` | Cross-cutting API; duplication of Pkg* across packages |
| `A-protocols` | SE In/Out targets across Uni/Aero/Camelot/Balancer; Aave loop repos; staking rebalance params |
| `A-research` | Scenario scripts under research/scenarios and any .sol helpers; mirror of DETF/hook production types |

---

## 5. Area report QA gate (orchestrator)

Before marking an area `COMPLETE`, check:

| Check | Fail action |
|-------|-------------|
| File exists at OUT_FILE | Write from agent return or re-spawn |
| Has §1–§9 headers | Request fix / mark PARTIAL |
| Inventory table non-empty **or** explicit “zero structs” | Re-run inventory |
| Do-not-collapse section present | Add placeholder |
| Every S-* collapse has gas dir + stack risk + ABI/storage + confidence | Reject incomplete rows |
| Every A-* Blocker/High has path:line evidence | Reject incomplete rows |
| No `via_ir` recommendation | Delete/rewrite finding |

---

## 6. Aggregate report template (orchestrator fills)

Write to `{REPORT_DIR}/{RUN_DATE}_struct-audit_AGGREGATE.md`:

```markdown
# Struct + Audit Readiness Review — AGGREGATE

- **Date:** {RUN_DATE}
- **Mode:** pilot | full
- **PRD:** docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md (v0.2+)
- **Orchestrator:** …
- **Areas scheduled / complete / partial / failed:** …

## 1. Program metadata
(table of area → status → report path → struct count)

## 2. Global inventory stats
- Total structs inventoried
- By kind (stack-relief / api / storage / result / …)
- Top 15 files by struct density

## 3. Cross-area duplicates
(table: struct pattern | areas | files | collapse class | notes)
Include research↔production mirrors.

## 4. Priority backlog (Top 25)
| Rank | Score | ID | Area | Title | Gas | Audit sev | Break? | Next step |
|------|-------|----|------|-------|-----|-----------|--------|-----------|

Scoring: PRD §8.

## 5. Merged findings (Blocker / High first)
### Blockers
### High
### Medium (summary counts + links to area files)
### Low/Nit (counts only unless critical for auditors)

## 6. Conflicts & resolutions
| Topic | Area A said | Area B said | Orchestrator decision |

## 7. Gas measurement shortlist (implementation phase)
| ID | Hermetic command | Optional fork command | Notes |

## 8. Audit readiness scorecard
| Area | Scorecard | Rationale |

## 9. Recommended follow-on artifacts
- Implementation plan path (to create later)
- Adversarial gap pointers if any
- Re-run pilot after large merges?

## 10. Out of scope / deferred debt

## 11. Acceptance criteria checklist
- [ ] AC1 … AC8 (copy from PRD §10)
```

---

## 7. Wave schedule (full mode under concurrency limits)

If max concurrent subagents ≈ 4:

| Wave | Areas |
|------|--------|
| **Wave 1** (stack-hot) | `A-hooks-v4`, `A-detf-univ4`, `A-detf-core`, `A-detf-balancer` |
| **Wave 2** (product surface) | `A-se-vaults`, `A-routers`, `A-manager-fee-oracle`, `A-interfaces-types` |
| **Wave 3** (locked expansions) | `A-protocols`, `A-research` |

If max ≥ 8: Wave 1+2 together, then Wave 3; or all at once if tool budget allows.

**Pilot:** single wave of 3 — no sequencing required.

---

## 8. Spawn API sketch (Grok / compatible)

Orchestrator issues **parallel** `spawn_subagent` (or equivalent) calls:

```text
for each area in active_mode_areas:
  spawn_subagent(
    description = "struct-audit " + AREA_ID,
    subagent_type = "explore",  # or general-purpose read-only
    capability_mode = "read-only",
    prompt = filled_template_from_§4
  )
```

Then `get_command_or_subagent_output` / wait for completions (do not busy-poll with sleep loops if the host notifies on completion).

If explore agents **cannot write files**, set:

```text
prompt += "\nReturn the FULL markdown report as your final message. Do not truncate tables."
```

Orchestrator then writes each OUT_FILE via the write tool.

---

## 9. Definition of done (this execute plan)

| # | Done when |
|---|-----------|
| D1 | All scheduled area reports on disk (or FAILED with reason) |
| D2 | Aggregate report on disk with Top 25 + scorecard + cross-dupes |
| D3 | PRD AC1–AC8 satisfied or gaps listed under aggregate §10/§11 |
| D4 | User given short summary + file paths |
| D5 | No production Solidity edits from this program |

---

## 10. User-facing summary template (orchestrator final message)

```markdown
## Struct audit review complete ({MODE}, {RUN_DATE})

**Reports**
- Aggregate: docs/reviews/{RUN_DATE}_struct-audit_AGGREGATE.md
- Areas: (bullet list of paths + COMPLETE/PARTIAL/FAILED)

**Top opportunities** (from Top 25, first 5–10)
1. …
2. …

**Audit blockers / highs** (count + 3 examples)
- …

**Not done (by design)**
- No contract refactors; no via_ir; implementation phase not started.

**Suggested next**
- Authorize implementation plan for Top N, or run full mode if this was pilot.
```

---

## 11. Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-08-08 | Initial execute plan for parallel multi-agent review per PRD v0.2 |

**Related:** PRD `docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md`
