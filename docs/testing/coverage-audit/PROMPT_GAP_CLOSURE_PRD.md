# Agent prompt — Author the Gap Closure PRD from Stage 1 coverage-audit reports

> **How to use:** Open this file as the sole task prompt for a planning agent.  
> **Repo root:** IndexedEx (`lib/indexedex` or monorepo checkout that contains `docs/testing/coverage-audit/`).  
> **Kind:** Planning / product-law document only. **Do not implement production or test code in this run.**

---

## Mission

Read the **Stage 1 Test Coverage Audit** outputs (complete decision-grade gap reports + ranked work-package backlog). Then write a **PRD** that authorizes and constrains the **fix program** for those gaps: production CODE where class is CODE/BOTH, and production-first Foundry tests where class is TEST/THEATER.

**Primary output path (create):**

```text
docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md
```

**Optional companion (only if time remains after PRD is complete and self-consistent):**

```text
docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md
```

Prefer finishing the **PRD** first. The implementation plan is a later execute-plan style expansion of the PRD + backlog; do not skip PRD quality for a shallow plan.

---

## Hard rules (non-negotiable)

1. **No committed production `*.sol` edits** and **no permanent `test/**` suite implementation** in this agent run. PRD (and optional plan) under `docs/testing/**` only.
2. **Never recommend `via_ir`.** Never count MockStandardExchange / `vm.mockCall` on SUT as closed coverage.
3. **DETF role names only** in the PRD (never product brands like RICH/RICHIR):  
   `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / `reserveBpt`, `rebasingClaimToken`.
4. **Deploy bar:** facets via CREATE3 / FactoryService; vault/DETF DFPkgs via **IndexedEx manager vault registry** (`indexedexManager.deploy*DFPkg` / registry path). Never recommend `new` production facets/DFPkgs on user paths.
5. **Wave 0 serial:** shared commons CODE (`BasicVaultCommon` / secure pull) lands **before** parallel product I suites that depend on fixed semantics.
6. **Worktree / branch prefix:** `gap_cover_` (L-TCA-8). Every WP worktree/branch in the PRD must use this prefix.
7. **Blocker CODE:** require runtime proof before calling a free-mint/free-extract bug “closed.” Stage 1 already **confirmed** helper free-credit under `repro/TCA-COMMON-001/`; product e2e Blockers labeled `RUNTIME_UNPROVEN` must include a proof-first task.
8. **Anti-theater:** happy-path `pretransferred=true` with real transfer is **not** I1–I3 coverage. J acceptance must call the **proxy**, not facet implementation address.
9. **Supersession (L-TCA-4):** this fix program owns I/J/K CODE+TEST work packages from the coverage-audit backlog. Link struct-audit / 2026-07 report IDs for traceability; do not fork a competing fix list.
10. **Ship-blocking:** all money products (vaults, DETFs, SE packages, hooks, fund routers) remain in scope — do not DEFER as “not launch.”
11. **Fork P0 = hermetic severity (L-TCA-5)** for fork-first products (e.g. DualLiquidity). Prefer `foundry.toml` `*_alchemy` RPC aliases + `ALCHEMY_KEY` (L-TCA-6).
12. Do **not** open `gap_cover_*` worktrees or implement Stage 3 in this run.

---

## Required reading order (do not skip)

### A. Stage 1 law (why the audit exists)

| Order | Path | Why |
|------:|------|-----|
| 1 | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` | Normative bar: layers H…L3, catalog A–K, patterns PAT-*, severity/class, WP schema §8, locks L-TCA-1…8, Stage 2/3 handoff §§13–14 |
| 2 | `docs/testing/TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md` | What Stage 1 produced; Stage 2 handoff contract |
| 3 | `Claude.md` (repo root router) + open `docs/agent/INDEXEDEX_AGENT_LAW.md` if DETF/deploy law needed | Non-negotiable deploy/test law |

### B. Stage 1 outputs (source of truth for gaps)

| Order | Path | Why |
|------:|------|-----|
| 4 | `docs/testing/coverage-audit/AGGREGATE.md` | Executive heatmap, global matrices, PAT-I-ABS / PAT-J-OMIT monorepo statements, deduped Blockers, wave sketch, PRD §12 DoD check |
| 5 | `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` | **Primary WP inventory** — 44 formal WPs + finding→WP index for all 69 Blocker/High TCA IDs |
| 6 | `docs/testing/coverage-audit/PILOT_EXIT.md` | Pilot gate + runtime proof summary |
| 7 | `docs/testing/coverage-audit/00_SCOPE_PARTITION.md` | Product ownership by area |
| 8 | `docs/testing/coverage-audit/repro/TCA-COMMON-001/` | Confirmed PAT-I-ABS helper free-credit (COMMANDS.md, notes.md, forge.log) |

### C. Area reports (deep dive as needed — at least all Blocker products)

Read fully for any product with Blocker CODE or High CODE in aggregate:

| Area report | Focus |
|-------------|--------|
| `areas/T-basic-protocol-commons.md` | Wave-0 PAT-I-ABS epicenter; theater unit tests |
| `areas/T-detf-multi-vault.md` | Gold A–H; package `_pullToken` / burn; I/J gaps |
| `areas/T-detf-single-se.md` | Single SE DETF PAT-I-ABS × packages |
| `areas/T-detf-composed-stable.md` | ComposedStable / MixedBuffer / Rebasing blind pull |
| `areas/T-detf-dual-liquidity.md` | `_receive` / `_receiveOut`; fork-first |
| `areas/T-se-aerodrome-camelot-univ2.md` | SE inheritors of BasicVaultCommon |
| `areas/T-se-univ4-aave-balancer.md` | Uni V4 SE; Aave free share mint |
| `areas/T-hooks-v4.md` | Hook CP free extract; Dual gate |
| `areas/T-manager-fee-registry.md` | J-OMIT seigniorage query; FeeCollector |
| `areas/T-routers-permit2.md` | Permit2 I5 / J gaps (no PAT-I-ABS free-mint on coordinator) |
| `areas/T-detf-single-vault-seigniorage.md` | **Products removed** — do not re-plan dead SUTs |

Skim remaining Medium clusters only after Blocker/High WPs are fully reflected in the PRD.

### D. Skills / ship gate (bar for “fixed”)

| Path | Why |
|------|-----|
| `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` (or `.grok` / `.claude` mirrors) | Catalog A–K, anti-theater |
| `…/references/implementation-test-dod.md` | Ship-gate checklist → PRD acceptance language |
| `crane-testing`, `indexedex-testing`, `indexedex-adversarial-testing` | Production-first tests, registry deploy, DETF/SE extensions |

### E. Prior seeds (link only; do not trust over Stage 1)

- `docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md`
- `docs/testing/FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md`
- `docs/NEGATIVE_TEST_COVERAGE_REPORT.md`
- Struct-audit reviews under `docs/reviews/` (if cited in area reports)

Stage 1 **supersedes** these for I/J/K fix ownership. Cite them as historical; prefer TCA-* finding IDs and WP-IDs from the backlog.

---

## What the PRD must achieve

The PRD is the **product and process law** for closing Stage 1 gaps. A later execute-plan / implementer agent should be able to open only:

1. This PRD  
2. `WORK_PACKAGE_BACKLOG.md`  
3. Linked area findings  

…and implement Wave 0 → Wave N without re-auditing the monorepo.

### Problems the PRD must treat as in-scope

| Theme | Evidence anchor | Typical class |
|-------|-----------------|---------------|
| **PAT-I-ABS free credit / free mint / free extract** | `BasicVaultCommon`; DETF `_pullToken`; DualLiquidity `_receive*`; Uni V4 SE; Aave Stata; hooks CP | CODE (+ TEST) |
| **PAT-THEATER-PRE** | Happy pretransfer tests; unit tests asserting free credit | THEATER → replace with I1–I3 |
| **Missing I1–I3** | Nearly all money pretransfer surfaces | TEST after CODE |
| **PAT-J-OMIT / weak J1–J3** | Sparse facet declaration; missing proxy smoke; fee seigniorage typo | CODE and/or TEST |
| **PAT-K-DONATE residual** | Absolute inventory + pretransfer | TEST (and CODE if law requires) |
| **Thin adversarial / no Uni V2 SE adversarial** | SE + MixedBuffer + hooks Dual | TEST |
| **Permit2 / router P0 holes** | Coordinator replay, wrong spender, exact selectors | TEST |
| **L1–L3 property depth** | Products still G after I/J close | later waves |

### Explicit non-goals for the PRD’s fix program

- Re-auditing the monorepo from scratch (Stage 1 is done).
- Re-authoring MultiVault A–H gold suite (extend with I/J/K only).
- Reintroducing removed SingleVaultDetf / SeigniorageDETF products.
- Frontend / indexer / e2e outside Foundry.
- Formal verification, Echidna/Medusa campaigns, `via_ir`.
- Changing DETF product economics / fee schedules without `NEEDS_OWNER`.
- Deep rewrites of pure vendored `lib/**` upstream except where IndexedEx SUT call-ins require a shared pull library.

---

## Required PRD structure

Write `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` with **at least** these sections:

### 1. Header table

| Field | Content |
|-------|---------|
| Status | DRAFT or READY-FOR-IMPLEMENTATION |
| Kind | Fix / gap-closure PRD (authorizes Stage 3 only after acceptance of this PRD + optional execute plan) |
| Depends on Stage 1 | Paths to AGGREGATE + WORK_PACKAGE_BACKLOG + area reports |
| Primary skills | crane-adversarial-testing, implementation-test-dod, crane-testing, indexedex-testing, indexedex-adversarial-testing |
| Worktree prefix | `gap_cover_` |
| Fork RPC | `*_alchemy` + `ALCHEMY_KEY` |

### 2. Intent & success definition

- Why free absolute pretransfer credit and missing I/J proofs are ship-blocking.
- Success = Blocker/High WPs closed with **production-first** tests that would have failed before CODE fixes; no greenwash.
- Explicit: Stage 1 helper free-credit is **confirmed**; product e2e proofs still required where Blocker CODE is RUNTIME_UNPROVEN.

### 3. Normative coverage bar (import, do not weaken)

Reference Stage 1 PRD §2 layers and catalog. Restate minimum close criteria for:

- **I1–I3** (no free mint when vault holds inventory; short delivery; residual reuse)
- **J1–J3** (Target API ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ **proxy** callable)
- **K1** where balance-based credit exists
- Anti-theater rules for pretransfer and facet declaration

### 4. Locked decisions

Import and reaffirm L-TCA-2…8 as they apply to **fix** work. Add any new locks needed for the fix program (e.g. L-CLAIM-3 delta law, Wave 0 serial). Number them `L-GAPS-1…N` if new.

### 5. Scope — products & ownership

Table of ship-blocking products (from aggregate inventory) with:

- Owning area report path  
- Worst severity  
- Primary WP-IDs from backlog  
- Note removed products (SingleVault / Seigniorage DETF) as out of scope  

### 6. Problem statement by epic (must include)

For each epic, cite **TCA-*** IDs and **WP-*** IDs from the backlog:

1. **Wave-0 commons pull** — `WP-I-COMMON-001`, `WP-I-COMMON-002`, `WP-I-CLONE-001`  
2. **DETF package-local pull/burn** — MultiVault, Single SE, ComposedStable, MixedBuffer  
3. **DualLiquidity receive paths**  
4. **SE BasicVaultCommon consumers** (Aero/Camelot/UniV2) + Uni V4 / Aave  
5. **Hooks free extract / free gates**  
6. **Claim foreign-token residual** — `WP-I-CLAIM-001`  
7. **J-surface epics** (DETF, SE, hooks, manager, routers)  
8. **Permit2 / FeeCollector / exact-selector N hygiene**  

For each epic: problem, blast radius, class CODE|TEST|BOTH, wave, depends-on.

### 7. Work package law

- Backlog is normative for WP-IDs; PRD may **refine** acceptance language but must not drop Blocker/High without explicit DEFER + reason.
- Schema fields required on every Blocker/High WP (mirror Stage 1 PRD §8): touch sets, `gap_cover_*` worktree, forge acceptance, anti-theater, wave, dependencies.
- Parallelism: same file → serial; different packages → parallel after Wave 0 API freeze.

### 8. Implementation waves (normative for Stage 3)

| Wave | Contents | Serial constraints |
|------|----------|--------------------|
| 0 | Commons delta-pretransfer CODE + unit I1–I3; start clone alignment | **Serial** on `BasicVaultCommon` |
| 1 | Product Blocker CODE + I1–I3 + J1–J3 per package | Parallel by package after 0 |
| 2 | Remaining A–H ports, SE adversarial expand, K1, theater kill, Permit2 I5, FeeCollector | After 0; prefer after 1 CODE |
| 3 | L1/L3 property layer | After I CODE on that product |
| 4 | P2 / stub hygiene | Opportunistic |

### 9. Testing requirements (production-first)

- Gold TestBases and registry deploy paths only.  
- Catalog test names: `test_I1_*`, `test_J1_*`, etc.  
- Exact revert selectors (no bare `expectRevert` as acceptance).  
- For CODE WPs: red-then-green narrative (test fails pre-fix, passes post-fix) preferred in worklogs.  
- Fork: `FOUNDRY_PROFILE=fork` + `*_alchemy` endpoints.  
- Skills + `implementation-test-dod.md` are the ship gate.

### 10. Runtime proof requirements

- Wave-0 commons: already confirmed; regression suite must keep free-credit impossible.  
- Each remaining Blocker CODE product: proof task (hermetic preferred) before severity can be closed as fixed.  
- Repro artifacts may live under `docs/testing/coverage-audit/repro/<FINDING_ID>/` (no secrets).

### 11. Risks, conflicts, NEEDS_OWNER

Lift open questions from area reports (donation beneficiary law, free residual intentionality on some hooks, typed error selection). Mark true product-law ambiguity as `NEEDS_OWNER`; do not invent economics.

### 12. Definition of Done (this fix program)

Checklist form, e.g.:

- [ ] All Blocker WPs merged with runtime-backed acceptance  
- [ ] All High WPs merged or explicitly deferred with severity-preserving reason  
- [ ] No mock SUT counted as coverage  
- [ ] I1–I3 present on every money pretransfer surface touched  
- [ ] J1–J3 on every diamond package touched  
- [ ] Wave 0 commons landed before dependent product I suites  
- [ ] `forge test` green on all touched paths; fork paths documented for DualLiquidity etc.  
- [ ] Theater tests that greenwashed free credit removed or inverted  

### 13. Handoff to execute plan / Stage 3

State that implementers must:

1. Read this PRD + assigned WP from backlog + linked TCA findings  
2. Use `gap_cover_*` worktrees  
3. Fix CODE first when class is CODE/BOTH  
4. Not greenwash free mint  
5. Paste forge evidence in PR/worklog  

Provide a one-block prompt for the agent that will write  
`TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` (waves, merge order, subagent prompts, forge commands).

### 14. Revision history

Date + “Initial gap-closure PRD from Stage 1 coverage-audit (2026-08-09 run).”

---

## Quality bar for the PRD (self-check before finishing)

Reject your own draft if any fail:

| Check | Pass condition |
|-------|----------------|
| Traceability | Every Blocker TCA ID from aggregate appears under an epic or WP citation |
| Backlog alignment | All 44 WP-IDs from `WORK_PACKAGE_BACKLOG.md` are acknowledged (list or wave map); none silently dropped |
| Wave 0 | Commons CODE is serial and first |
| Runtime | Confirmed helper proof cited; unproven product Blockers require proof tasks |
| Anti-theater | Explicit I1 and J3 rules |
| Deploy law | Registry + CREATE3 restated |
| Role names | No banned DETF brand names |
| Scope | Removed SingleVault/Seigniorage not treated as live products |
| Actionability | Stage 3 agent could start Wave 0 without re-reading all 11 area reports end-to-end (backlog + PRD enough) |

---

## Suggested agent workflow

1. Read sections A–B completely; skim C for Blocker products.  
2. Build a private checklist: 69 High/Blocker IDs × WP-ID from backlog index (must match).  
3. Draft PRD structure empty → fill epics from AGGREGATE §2 + §6 + backlog ranking.  
4. Write wave tables and DoD.  
5. Self-check against the quality bar.  
6. Write the file to `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md`.  
7. Return a short summary: path, epic count, wave map, open NEEDS_OWNER items, and the Stage-3 / execute-plan handoff blurb.

---

## Copy-paste start message (for the human or orchestrator)

```text
You are the Stage 2 PRD author for IndexedEx gap closure.

Open and follow exactly:
  docs/testing/coverage-audit/PROMPT_GAP_CLOSURE_PRD.md

Primary inputs:
  docs/testing/coverage-audit/AGGREGATE.md
  docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md
  docs/testing/coverage-audit/areas/**
  docs/testing/TEST_COVERAGE_AUDIT_PRD.md

Write:
  docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md

Do not implement contracts or permanent tests. Do not open gap_cover_* worktrees.
When done, summarize path, waves, and any NEEDS_OWNER items.
```

---

## Reference: Stage 1 headline (do not re-discover)

- **PAT-I-ABS confirmed** on `BasicVaultCommon` free absolute pretransfer credit (`repro/TCA-COMMON-001/`).  
- Clones across DETF / SE / DualLiquidity / hooks / Aave.  
- MultiVault A–H remains gold; maturity ~3 under full A–K bar.  
- Wave 0: `WP-I-COMMON-001` (+ theater kill / I suite).  
- 44 WPs, 69 Blocker/High findings indexed in backlog.
