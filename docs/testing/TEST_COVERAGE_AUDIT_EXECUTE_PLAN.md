# Execute Plan — Test Coverage Audit (Stage 1)

> **For agentic workers:** This is a **Stage 1 review** plan. Orchestrator launches parallel area subagents, collects reports, runs Blocker runtime proofs where required, then writes the aggregate + work-package backlog.  
> **Do not** implement production fixes or permanent test suites. **Do not** start Stage 3 worktrees.  
> **May** write under `docs/testing/coverage-audit/**` only (reports + optional `repro/` evidence).

**Goal:** Produce decision-grade coverage-gap reports and a ranked work-package backlog so a later agent can write `TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` and spawn `gap_cover_*` implementers.

**Normative law:** [`TEST_COVERAGE_AUDIT_PRD.md`](./TEST_COVERAGE_AUDIT_PRD.md) (especially §§2–8, **§15 pilot**, **§19 locks L-TCA-1…8**).

**Primary skills / bar:**

| Skill / doc | Role |
|-------------|------|
| `crane-adversarial-testing` | Catalog **A–K**, I/J patterns, anti-theater |
| `…/references/implementation-test-dod.md` | Ship-gate checklist → WP acceptance language |
| `crane-testing` | LR-7, surface matrix, production-first |
| `indexedex-testing` / `indexedex-adversarial-testing` | Registry path, DETF/SE extensions |
| `Claude.md` / `INDEXEDEX_AGENT_LAW.md` | Deploy + test non-negotiables |

**Repo root:** IndexedEx workspace (`lib/indexedex`).

**Downstream (not this plan):**

| Stage | Deliverable |
|-------|-------------|
| 2 | `docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` (planner agent) |
| 3 | Worktrees/branches `gap_cover_*` + parallel CODE/TEST agents |

---

## 0. Run parameters (orchestrator sets once)

| Parameter | How to set | Default / locked |
|-----------|------------|------------------|
| `MODE` | `pilot` then `full` after pilot exit | **`pilot` first** (L-TCA-1) — do not start full until §6 exit criteria pass |
| `RUN_DATE` | ISO date of this run | today `YYYY-MM-DD` |
| `REPORT_ROOT` | Output tree | `docs/testing/coverage-audit` |
| `PRD` | Law file | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` |
| `ALCHEMY` | Env for fork proof | `ALCHEMY_KEY` set; use `foundry.toml` `*_alchemy` aliases (L-TCA-6) |
| `FORK_PROFILE` | Foundry profile | `FOUNDRY_PROFILE=fork` for fork paths |
| `MAX_PARALLEL` | Concurrent area agents | **3** pilot; **4–6** full (wave if needed) |

**Output layout (fixed):**

```text
docs/testing/coverage-audit/
  00_SCOPE_PARTITION.md
  01_METHODOLOGY_NOTES.md          # optional
  areas/
    T-basic-protocol-commons.md
    T-detf-multi-vault.md
    …
  repro/                           # L-TCA-7
    <FINDING_ID>/
      COMMANDS.md
      forge.log
      notes.md
  AGGREGATE.md                     # pilot: thin; full: complete
  WORK_PACKAGE_BACKLOG.md
  PILOT_EXIT.md                    # short gate record before full spawn
```

Do **not** overwrite a prior complete full-pass aggregate without user OK; use dated copies under `docs/testing/coverage-audit/archive/{RUN_DATE}/` if re-running.

---

## 1. Global constraints (paste into every subagent)

```text
HARD RULES (TEST COVERAGE AUDIT STAGE 1):
1. No committed edits to production *.sol or permanent test suites under test/**.
   Allowed writes: docs/testing/coverage-audit/** only (area report + optional repro/).
2. Never recommend via_ir. Never count MockStandardExchange / vm.mockCall-on-SUT as coverage.
3. DETF role names only: rateAsset, pairToken, underlyingVault, vaultShare, detfToken,
   reservePool/reserveBpt, rebasingClaimToken.
4. Deploy bar: facets CREATE3/FactoryService; vault/DETF DFPkgs via indexedexManager registry path.
5. Coverage bar layers: H N D J I K A-H P L1 L2 L3 (PRD §2.2). Catalog A–K including I/J/K.
6. Pattern hunt mandatory: PAT-I-ABS, PAT-J-OMIT, PAT-J-CTRL, PAT-K-DONATE, PAT-THEATER-PRE,
   PAT-THEATER-FACET, PAT-PREV, PAT-MOCK (PRD §2.4).
7. Finding class: CODE | TEST | THEATER | DEFER | NEEDS_OWNER. Severity: Blocker|High|Medium|Low|Info.
8. Finding IDs: TCA-<AREA_SHORT>-NNN (e.g. TCA-COMMON-001, TCA-SE-AC-003).
9. Blocker + CODE requires RUNTIME PROOF (PRD §3.8 / L-TCA-3): command + outcome.
   If impossible: max High + RUNTIME_UNPROVEN (unless static is overwhelming — still label).
10. Repro evidence may go under docs/testing/coverage-audit/repro/<FINDING_ID>/ (L-TCA-7).
    Never commit ALCHEMY_KEY or secrets.
11. Fork RPC: prefer foundry.toml *_alchemy endpoints (L-TCA-6), e.g. --fork-url base_mainnet_alchemy.
12. J bar: Target API ⊆ facetFuncs ⊆ facetCuts ⊆ loupe ⊆ call on PROXY (not facet impl address).
13. I bar: happy-path pretransferred with real transfer is NOT coverage for I1–I3.
14. Ship-blocking products: ALL money vaults/DETFs/SE/hooks/fund routers (L-TCA-2) — do not DEFER as "not launch".
15. Fork-first products: missing fork P0 = equal severity to hermetic gaps (L-TCA-5).
16. This program SUPERSEDES struct-audit for I/J/K test/security WPs (L-TCA-4); link prior IDs, do not drop work.
17. Stay in path allowlist. Out-of-area: reference only.
18. Write report ONLY to OUT_FILE (or return full markdown for orchestrator to write).
19. For each Blocker/High: include concrete test name, setup sketch, pass criteria, suggested WP-ID.
20. Do not implement fixes. Do not create gap_cover_* worktrees (Stage 3 only).
```

---

## 2. Mode definitions

### 2.1 Pilot (`MODE=pilot`) — **mandatory first** (L-TCA-1)

| Area ID | Production allowlist | Test allowlist (primary) | OUT_FILE | Focus |
|---------|----------------------|--------------------------|----------|--------|
| `T-basic-protocol-commons` | `contracts/vaults/basic/**`, secure-transfer / common vault libs used by SE/DETF (e.g. `BasicVaultCommon.sol` and call sites as **reference**), protocol claim/NFT **transfer** helpers under `contracts/vaults/**` commons as applicable | `test/**` negatives touching pretransfer/secure transfer; `docs/NEGATIVE_TEST_COVERAGE_REPORT.md` as seed | `…/areas/T-basic-protocol-commons.md` | **PAT-I-ABS epicenter**; K sync; shared CODE WP draft |
| `T-detf-multi-vault` | Multi-vault-weighted DETF package under `contracts/vaults/detf/**` | `test/**/multi-vault-weighted/**` incl. `adversarial/` | `…/areas/T-detf-multi-vault.md` | Gold baseline; theater; I/J/K presence or explicit defer |
| `T-se-aerodrome-camelot-univ2` | Aerodrome + Camelot + Uni V2 SE vault packages under `contracts/` | Matching SE TestBases + `test/**` for those protocols + shared SE adversarial if any | `…/areas/T-se-aerodrome-camelot-univ2.md` | Routes, pretransfer, I1–I3, J |

**Parallelism:** spawn **3** area subagents at once.

**Pilot-only runtime (orchestrator or commons agent):** at least one PAT-I-ABS runtime attempt (L-TCA-3 / pilot exit).

### 2.2 Full (`MODE=full`) — only after §6 pilot exit

| Area ID | Production allowlist | Test roots | OUT_FILE |
|---------|----------------------|------------|----------|
| `T-detf-single-se` | Single SE DETF packages | `test/**/standardExchange/single/**` | `…/T-detf-single-se.md` |
| `T-detf-composed-stable` | Composed stable + mixed buffer DETF | `test/**/stable/**`, `mixedBuffer/**` | `…/T-detf-composed-stable.md` |
| `T-detf-single-vault-seigniorage` | SingleVault + Seigniorage DETF | matching tests | `…/T-detf-single-vault-seigniorage.md` |
| `T-detf-dual-liquidity` | DualLiquidity cross-version | fork + hermetic dual-liquidity paths | `…/T-detf-dual-liquidity.md` |
| `T-se-univ4-aave-balancer` | Uni V4 SE, Aave Stata SE, Balancer SE/routers | matching | `…/T-se-univ4-aave-balancer.md` |
| `T-hooks-v4` | `contracts/hooks/**` | hook tests | `…/T-hooks-v4.md` |
| `T-manager-fee-registry` | manager, fee, oracles, vault registry | matching | `…/T-manager-fee-registry.md` |
| `T-routers-permit2` | routers + Permit2 paths | matching | `…/T-routers-permit2.md` |

**Optional add-ons (if time):** `T-slipstream-buffer`, `T-research-contracts` (PRD §4).

**Re-run pilot areas in full?** Prefer **reuse** pilot area reports; re-open only if full-pass inventory finds missing products. Aggregate must still **include** pilot products in global matrices.

**Parallelism:** waves of **4–6**; recommended full waves:

| Wave | Areas |
|------|--------|
| F1 | `T-detf-single-se`, `T-detf-composed-stable`, `T-detf-single-vault-seigniorage`, `T-detf-dual-liquidity` |
| F2 | `T-se-univ4-aave-balancer`, `T-hooks-v4`, `T-manager-fee-registry`, `T-routers-permit2` |
| F3 (optional) | slipstream / research |

---

## 3. Orchestrator checklist

### Task O0 — Bootstrap

- [ ] **Step 1:** Set `MODE=pilot`, `RUN_DATE`.
- [ ] **Step 2:** Read PRD fully (`TEST_COVERAGE_AUDIT_PRD.md`), especially §§2, 3.8, 7–8, 15, **19**.
- [ ] **Step 3:** Skim skills: adversarial catalog I/J/K + DoD; `indexedex-testing` negatives; agent law test gaps.
- [ ] **Step 4:** Confirm `ALCHEMY_KEY` present if any pilot/full work needs fork proof; note in methodology if absent.
- [ ] **Step 5:** Create dirs:

```bash
mkdir -p docs/testing/coverage-audit/areas docs/testing/coverage-audit/repro
```

- [ ] **Step 6:** Write `docs/testing/coverage-audit/00_SCOPE_PARTITION.md` from §2.1 (pilot) table + excluded paths (`frontend/**`, `broadcast/**`, `out/**`, `lib/**` product law except Crane patterns).

### Task O1 — Cheap pre-inventory (non-blocking)

```bash
# Trust-flag / surface / theater signals (repo root)
rg -n --type sol 'pretransferred' contracts test --glob '!lib/**' | head -80
rg -n --type sol 'function facetFuncs' contracts --glob '!lib/**' | head -40
rg -n --type sol 'controlFacetFuncs' test contracts --glob '!lib/**' | head -40
rg -n --type sol 'function test_I[0-9]_|function test_A1_|function test_J[0-9]_' test | head -40
rg -n --type sol 'adversarial/' test -g '*.sol' -l | head -40
rg -n --type sol 'function testFuzz_|function invariant_' test --glob '!lib/**' | head -40
rg -n --type sol 'MockStandardExchange|vm\.mockCall' test --glob '!lib/**' | head -40
```

Optional list (if compile healthy):

```bash
forge test --list --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' 2>/dev/null | head -50
```

Record command summary in `01_METHODOLOGY_NOTES.md` if useful.

### Task O2 — Spawn pilot area subagents (parallel)

- [ ] **Step 1:** Spawn **3** agents (one per pilot area) with:
  - Prefer `explore` or `general-purpose` with **read-write only** for `docs/testing/coverage-audit/**`
  - `description`: `coverage-audit {AREA_ID}`
  - `prompt`: **§4 Area agent prompt** with substitutions
- [ ] **Step 2:** Launch in **parallel**, not serial.
- [ ] **Step 3:** On completion, validate each `OUT_FILE` against §5 QA. If body only in chat, orchestrator writes the file.

### Task O3 — Pilot runtime proof (Blocker candidates)

- [ ] **Step 1:** From commons + SE pilot findings, pick top **PAT-I-ABS** / free-mint candidate.
- [ ] **Step 2:** Obtain runtime proof per PRD §3.8:
  - Hermetic preferred; if fork-only path:  
    `FOUNDRY_PROFILE=fork forge test … --fork-url base_mainnet_alchemy` (or correct `*_alchemy` alias).
  - Or throwaway local script; log under `repro/<FINDING_ID>/`.
- [ ] **Step 3:** Update finding status: `confirmed` | `not reproducible` | `BUILD_BLOCKED` | `RUNTIME_UNPROVEN`.
- [ ] **Step 4:** If confirmed Blocker CODE, ensure WP stub in area report + pilot backlog.

### Task O4 — Pilot aggregate + exit gate

- [ ] **Step 1:** Write **thin** `AGGREGATE.md` (pilot products only) + `WORK_PACKAGE_BACKLOG.md` (≥5 real WPs if gaps exist; include any Blocker).
- [ ] **Step 2:** Write `PILOT_EXIT.md` checklist (copy §6).
- [ ] **Step 3:** If exit fails, fix schema/report issues and re-run failed areas only.
- [ ] **Step 4:** Present user: pilot maturity scores, top WPs, path to files. **Ask to proceed to full** unless user pre-authorized full after pilot.

### Task O5 — Full pass spawn (after pilot exit)

- [ ] **Step 1:** Update `00_SCOPE_PARTITION.md` with full tables.
- [ ] **Step 2:** Spawn Wave F1 then F2 (fail-soft).
- [ ] **Step 3:** Optional specialists after ≥3 hits (PRD §3.5): trust-flag cross-cut, facet surface cross-cut, fuzz specialist, theater hunter.
- [ ] **Step 4:** Collect COMPLETE / PARTIAL / FAILED.

### Task O6 — Full aggregate + backlog

- [ ] **Step 1:** Dedupe findings; resolve conflicts; global layer + catalog + PAT matrices.
- [ ] **Step 2:** Diff vs 2026-07 adversarial + fuzz reports (Still gap / Closed / New / Stale).
- [ ] **Step 3:** Rank WPs (PRD §9); full §8 fields for all Blocker/High.
- [ ] **Step 4:** Wave sketch for Stage 2 (Wave 0 commons serial; product parallel; L1 later).
- [ ] **Step 5:** Write final `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md`.
- [ ] **Step 6:** Verify Stage 1 DoD (PRD §12).
- [ ] **Step 7:** **Stop.** Hand off to Stage 2 planner. Do **not** open `gap_cover_*` worktrees.

### Task O7 — Optional specialists (prompts in §4.2)

Trigger rules from PRD §3.5. Specialists write:

- `docs/testing/coverage-audit/specialists/trust-flag-crosscut.md`
- `docs/testing/coverage-audit/specialists/facet-surface-crosscut.md`
- `docs/testing/coverage-audit/specialists/fuzz-invariant.md`
- `docs/testing/coverage-audit/specialists/theater-hunt.md`

Orchestrator merges into aggregate / backlog (no duplicate conflicting WPs).

---

## 4. Area agent prompt template

Substitute: `{AREA_ID}`, `{PROD_ALLOWLIST}`, `{TEST_ALLOWLIST}`, `{OUT_FILE}`, `{RUN_DATE}`, `{PRD_PATH}`, `{MODE}`, `{FOCUS}`, `{REPORT_ROOT}`.

```text
You are a Stage 1 area subagent for the IndexedEx Test Coverage Audit.

## Identity
- Area ID: {AREA_ID}
- Mode: {MODE}
- Run date: {RUN_DATE}
- Production path allowlist (deep review ONLY):
  {PROD_ALLOWLIST}
- Test path allowlist (primary):
  {TEST_ALLOWLIST}
- Output file: {OUT_FILE}
- Focus: {FOCUS}
- Normative PRD: {PRD_PATH}
  Read: §2 coverage bar, §2.4 patterns, §3.8 runtime Blockers, §5 inventory, §6 workstreams, §7.2 report schema, §8 WP stubs, §19 locks.
- Skills bar: crane-adversarial-testing (A–K, I/J), implementation-test-dod.md, crane-testing LR-7 surface matrix, indexedex-testing / indexedex-adversarial-testing.
- Prior seeds (re-verify, do not trust): docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md, FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md, NEGATIVE_TEST_COVERAGE_REPORT.md, docs/reviews/2026-08-08_struct-audit_*.md

## Hard rules
{PASTE §1 GLOBAL CONSTRAINTS}

## Workstreams (all required)
WS1 Product inventory — packages, Targets, Facets, DFPkgs, TestBases, test roots, deploy path quality.
WS2 Layer matrix — H N D J I K A-H P L1 L2 L3 as F/P/G/N/A/S + maturity 0–5.
WS3 Catalog matrix — A–K with evidence test names or G.
WS4 Pattern hunt — PAT-* findings with CODE/TEST/THEATER.
WS5 Theater audit — misleading tests (happy-only pretransfer, controlFacetFuncs from Facet only, facet-not-proxy, bare expectRevert, mock SUT).
WS6 Prior-report diff — Still gap / Closed / New / Stale for this area’s products.
WS7 Work package stubs — PRD §8 fields for every Blocker/High (cluster Mediums OK).
WS8 Open questions — NEEDS_OWNER, BUILD_BLOCKED, RUNTIME_UNPROVEN.

## Method hints
1. rg pretransferred, facetFuncs, controlFacetFuncs, adversarial/, testFuzz_, invariant_, MockStandardExchange in allowlists.
2. For each Facet: compare Target external/public product API vs facetFuncs (J1). Note if controls come from Target or Facet.
3. Prefer evidence of proxy deploy path in tests (indexedexManager.deploy*DFPkg / gold TestBase).
4. I1–I3: search for tests that claim pretransferred without transfer while vault holds inventory — absence is a gap.
5. If you believe Blocker CODE: attempt runtime proof if feasible in-area; else label needs orchestrator runtime and severity High max + RUNTIME_UNPROVEN, or confirm with static + request O3.
6. Repro logs: {REPORT_ROOT}/repro/<FINDING_ID>/ (COMMANDS.md, forge.log, notes.md) — optional but preferred for Blockers.

## Output
Write complete markdown to {OUT_FILE} matching PRD §7.2 sections 1–10.
Finding IDs: TCA-… unique within area.
Do not edit production or test/** suites.
When done, return: status COMPLETE|PARTIAL|FAILED, path to OUT_FILE, Blocker/High counts, top 5 WP-IDs.
```

### 4.1 Pilot focus strings (copy into `{FOCUS}`)

| Area | `{FOCUS}` |
|------|-----------|
| `T-basic-protocol-commons` | PAT-I-ABS in BasicVaultCommon and shared pull/credit; absolute balance vs delta; recommend single Wave-0 CODE WP; K donation sync; list all call sites as blast radius |
| `T-detf-multi-vault` | Gold adversarial suite completeness for A–K; theater; whether I1–I3/J1–J3 exist as tests; do not rewrite suite — score and gap only |
| `T-se-aerodrome-camelot-univ2` | SE exchangeIn/Out pretransfer; donation; route negatives; declaration+proxy; shared SE adversarial if present |

### 4.2 Specialist prompt (short)

```text
You are a specialist for Stage 1 coverage audit: {SPECIALIST_NAME}.
Read all area reports under docs/testing/coverage-audit/areas/ that match your trigger.
Unify recommendations into ONE cross-cutting analysis at {OUT_FILE}.
Do not re-score entire products; produce epic WPs (Wave 0 style) with touch sets and deps.
Hard rules same as Stage 1 (no product/test implementation).
PRD specialist table §3.5.
```

---

## 5. Area report QA (orchestrator)

Reject / send back if missing:

| Check | Required |
|-------|----------|
| Header table (date, status, paths) | yes |
| Executive summary + maturity scores | yes |
| Product inventory table | yes |
| Layer matrix H…L3 | yes |
| Catalog A–K matrix | yes |
| Findings with class + severity + evidence | if any gaps |
| Theater list (even if empty) | yes |
| Prior-report diff | yes |
| WP stubs for Blocker/High | yes |
| Commands run | yes |
| No production code patches | yes |

---

## 6. Pilot exit criteria (`PILOT_EXIT.md`)

All must be true before `MODE=full`:

- [ ] Three pilot area reports `COMPLETE` (or `PARTIAL` with inventory + findings still usable)
- [ ] Each report passes §5 QA
- [ ] Thin `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` exist (≥5 WPs **or** explicit clean bill with evidence)
- [ ] At least one **runtime** attempt on top PAT-I-ABS candidate documented (`repro/` or finding notes)
- [ ] Schema issues fixed (finding IDs, WP fields, no mock-SUT counted as coverage)
- [ ] User notified of pilot results (or pre-authorized auto-continue)

---

## 7. Aggregate + backlog QA (full pass)

### 7.1 `AGGREGATE.md` must include (PRD §7.4)

1. Metadata (date, areas status, PRD locks cited)
2. Executive summary + maturity heatmap
3. Global layer matrix
4. Global catalog A–K matrix
5. PAT incidence + epicenters
6. Deduped Blocker/High findings (link areas)
7. Conflicts & decisions
8. Diff vs 2026-07 adversarial + fuzz reports
9. Recommended implementation waves (sketch only)
10. Link to `WORK_PACKAGE_BACKLOG.md`

### 7.2 `WORK_PACKAGE_BACKLOG.md` must include (PRD §8)

For **every Blocker/High** WP:

- WP-ID, title, severity, class, products, finding IDs  
- Problem, production touch set, test touch set, out-of-scope  
- Depends on / parallelizable with  
- **Suggested worktree** with prefix **`gap_cover_`** (L-TCA-8)  
- Implementation notes (skills, gold copy paths)  
- Acceptance forge commands + required `test_*` / catalog IDs  
- Anti-theater checks  
- Wave assignment (0–4)

Sorted by PRD §9 composite score. Medium may be clustered into epic WPs.

---

## 8. Runtime proof playbook (orchestrator / commons)

### 8.1 Hermetic

```bash
# List candidate tests first
forge test --list --match-path 'test/foundry/spec/**/*pretransfer*' 2>/dev/null | head -40

# Targeted run (example — replace with real paths from inventory)
forge test --match-path 'test/foundry/spec/<path>' --match-test '<test>' -vv
```

### 8.2 Fork (Alchemy — L-TCA-6)

```bash
# Requires ALCHEMY_KEY in environment (never commit)
export ALCHEMY_KEY=…   # agent env / user env only

FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/**' \
  --fork-url base_mainnet_alchemy \
  -vv
```

Pick chain alias matching product gold TestBase (`base_mainnet_alchemy`, `ethereum_mainnet_alchemy`, etc. from `foundry.toml` `[rpc_endpoints]`).

### 8.3 Repro directory

```text
docs/testing/coverage-audit/repro/TCA-COMMON-001/
  COMMANDS.md      # exact commands
  forge.log        # truncated OK if huge
  notes.md         # expected vs actual balances; confirmed|not reproducible|BUILD_BLOCKED
```

---

## 9. Stage 2 handoff (after Stage 1 complete)

Orchestrator final message to user should include:

1. Paths: `AGGREGATE.md`, `WORK_PACKAGE_BACKLOG.md`, area list  
2. Blocker count + whether PAT-I-ABS confirmed  
3. Recommended next prompt:

```text
Read docs/testing/TEST_COVERAGE_AUDIT_PRD.md §13 and docs/testing/coverage-audit/AGGREGATE.md
+ WORK_PACKAGE_BACKLOG.md. Write docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md:
waves, gap_cover_* worktrees/branches, serial Wave 0 commons, parallel product WPs,
subagent prompts, forge acceptance, merge order. Do not implement code yet.
```

**Do not** execute Stage 3 in this plan.

---

## 10. Failure modes

| Failure | Action |
|---------|--------|
| Area agent edits `contracts/` | Discard diffs; re-run agent with stricter prompt |
| Area times out | Mark PARTIAL; keep inventory; optional second pass |
| Compile broken | Inventory still required; `BUILD_BLOCKED` on runtime; continue |
| No `ALCHEMY_KEY` | Hermetic proofs only; fork gaps still High/Blocker with env note |
| Agent marks I covered via happy pretransfer only | QA fail; send back |
| Agent counts facet declaration without proxy | QA fail; J incomplete |
| Pilot skipped | **Stop** — violates L-TCA-1 unless user override recorded in `PILOT_EXIT.md` |

---

## 11. Definition of Done (this execute plan)

Stage 1 execution is done when:

- [ ] Pilot completed and `PILOT_EXIT.md` green  
- [ ] Full areas COMPLETE/PARTIAL/FAILED recorded  
- [ ] `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` pass §7  
- [ ] PRD §12 Stage 1 DoD checklist complete  
- [ ] No production/test suite implementation landed  
- [ ] User has handoff prompt for Stage 2 planner  

---

## 12. Quick reference — locked decisions

| ID | Lock |
|----|------|
| L-TCA-1 | Pilot first |
| L-TCA-2 | All money products ship-blocking |
| L-TCA-3 | Runtime proof for Blocker CODE |
| L-TCA-4 | Supersede struct-audit for I/J/K WPs |
| L-TCA-5 | Fork P0 = hermetic severity |
| L-TCA-6 | Alchemy `*_alchemy` RPC aliases |
| L-TCA-7 | `repro/` logs allowed |
| L-TCA-8 | `gap_cover_` worktree/branch prefix |

---

## 13. Revision history

| Date | Change |
|------|--------|
| 2026-08-09 | Initial execute plan for Stage 1 coverage audit (pilot → full → aggregate → Stage 2 handoff) |
