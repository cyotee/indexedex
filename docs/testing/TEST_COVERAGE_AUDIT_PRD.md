# Product Requirements Document (PRD)

## Title

**Test Coverage Audit + Gap Closure Reports** — agent-orchestrated, parallel review of production money paths vs existing Foundry coverage, producing decision-grade gap reports that feed a later implementation plan (code fixes + missing tests in parallel worktrees)

## Status

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** — process law for review phase only; **open items LOCKED 2026-08-09** (§19) |
| **Kind** | **Review PRD** (reports only; no committed product/test diffs). Does **not** authorize Stage 3 implementation. |
| **Primary output** | Area reports + one aggregate under `docs/testing/coverage-audit/` (see §7) |
| **Downstream consumers** | (1) Agent that writes **coverage-audit → implementation plan** from reports; (2) Agent that executes that plan with worktrees + parallel fix/test subagents |
| **Hard constraints** | No **committed** product/test edits in Stage 1; **`via_ir` forbidden**; production-first testing law; DETF role names only; vault/DETF DFPkgs via manager registry; facets via CREATE3 / FactoryService |
| **Ship-blocking scope** | **All** money-moving vaults / DETFs / SE packages / hooks under `contracts/` (and their production entry routers) — see §19 |
| **Execution shape** | **Pilot first**, then full partition — see §15 / §19 |
| **Blocker proof bar** | **Runtime proof required** for Blocker CODE claims — see §3.8 / §19 |
| **Relation to struct-audit fixes** | **Supersedes** for test/security gap ownership (I/J/K CODE+TEST WPs) — see §10 / §19 |
| **Fork RPC** | Prefer `foundry.toml` `*_alchemy` endpoints + `ALCHEMY_KEY` (L-TCA-6) |
| **Repro artifacts** | Allowed under `docs/testing/coverage-audit/repro/` (L-TCA-7) |
| **Worktree / branch prefix** | `gap_cover_` (L-TCA-8) |
| **Related skills (normative bar)** | `crane-testing`, `crane-adversarial-testing` (catalog **A–K**, ship gate `implementation-test-dod.md`), `indexedex-testing`, `indexedex-adversarial-testing` |
| **Related law** | `Claude.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md` (§ Test Patterns / non-negotiable gaps) |
| **Prior coverage artifacts (inputs, not truth)** | `docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md`, `ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md`, `FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md`, `FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md`, `docs/NEGATIVE_TEST_COVERAGE_REPORT.md`, `docs/test-coverage-report.md`, `docs/TEST_ANALYSIS_REPORT.md`, struct-audit reviews under `docs/reviews/2026-08-08_*` |
| **Execute plan** | [`docs/testing/TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md`](./TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md) — Stage 1 orchestrator steps, pilot/full, prompts, QA |
| **Fix implementation plan (later)** | *Out of scope* until aggregate report accepted; expected path: `docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` |

---

## 0. Intent (why this exists)

### 0.1 Problem

IndexedEx has strong **methodology** (Crane LR-7, adversarial catalogs, gold MultiVault suites) and several **historical gap reports**, but implementor agents still shipped:

1. **Trust-flag free mint** — `pretransferred=true` (and similar) credited caller-claimed amounts against absolute vault balances without proving an inbound **balance delta** (existing reserves / donations treated as the user’s transfer).
2. **Diamond surface holes** — Target entrypoints omitted from Facet `facetFuncs()`, so DFPkg proxies never exposed those functions; Facet declaration tests rubber-stamped incomplete control lists.
3. **Catalog skew** — adversarial programs covered donation (A) and reentrancy (C) more thoroughly than trust-flag abuse (**I**), proxy surface (**J**), and reserve-sync free credit (**K**).
4. **Layer skew** — fixed adversarial L0 cases without L1 fuzz / L2–L3 invariant depth on DETF and many SE surfaces (see fuzz gap report).
5. **Stale coverage truth** — prior adversarial/fuzz reports (2026-07) and partial negative reports may not match current trees after ports and directory reorgs.

Without a **fresh, catalog-complete, product-partitioned audit**, a fix-wave agent will thrash: re-implement already-green suites, miss production bugs, or write test theater.

### 0.2 Goals

1. **Re-inventory** in-scope products: production packages, gold TestBases, hermetic/fork/adversarial/fuzz/invariant suites as they exist **today**.
2. **Map coverage** against the **full** normative bar (happy path, negative/exact selectors, adversarial A–K, declaration + proxy surface J, trust-flag I, accounting sync K, preview≡execute, property L1–L3).
3. **Separate** findings into:
   - **CODE** — production bug / missing guard (fix before or with tests).
   - **TEST** — missing or weak tests for existing correct behavior.
   - **THEATER** — tests that claim security but do not prove it (rubber-stamp controls, happy-path-only pretransfer, bare `expectRevert`, mock SUT).
4. **Emit work-package-ready reports** so a later implementation plan can assign **non-overlapping worktrees** and parallel subagents for fixes + tests.
5. **Refresh** (do not blindly trust) prior adversarial/fuzz matrices; cite what changed vs 2026-07 reports.
6. **Parallelize** via orchestrator + area subagents with one schema (§7).

### 0.3 Non-goals (this PRD’s execution phase)

- Writing or editing production Solidity, tests, or foundry.toml.
- Enabling `via_ir` or package-specific IR profiles.
- Full formal verification, Echidna/Medusa campaigns, or external audit engagement.
- Frontend, indexer, or non-Foundry e2e.
- Re-authoring product economics / fee schedules / DETF family law (flag product-law ambiguity as `NEEDS_OWNER` only).
- Replacing MultiVault gold adversarial suite; use it as baseline, not a rewrite target unless theater is found.
- Deep review of pure vendored `lib/**` upstream (except Crane test infrastructure patterns and when IndexedEx SUT calls into ports).
- Implementing the gap closure — that is a **later** PRD/plan fed by this program’s reports.

### 0.4 Success definition

A decision-grade **aggregate report** such that a planning agent can, without re-exploring the monorepo from scratch:

1. List every in-scope product with maturity scores per coverage layer.
2. Enumerate **P0/P1** gaps with finding IDs, evidence paths, recommended tests (and code fixes when CODE).
3. Produce a **work-package DAG** (dependencies, parallelizable sets, suggested worktree names).
4. Define **acceptance tests** (exact `forge test --match-path` / `--match-test` patterns) per package.
5. Hand off cleanly to `TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` authorship.

**This PRD is done when the aggregate report is accepted — not when tests are green.**

---

## 1. Definitions

| Term | Meaning |
|------|---------|
| **Product / surface** | Deployable user-facing vault, DETF, SE package, hook vault, router, manager/fee component under review |
| **SUT** | Subject under test — real production diamond/instance via factories + registry; never a mock of the product |
| **Happy path** | Documented success flows with realistic funding and minOut |
| **Negative test** | Expected revert with **exact selector** (typed encoding preferred) + state-unchanged asserts |
| **Adversarial suite** | Catalog-driven abuse tests under `adversarial/` driving production entry points |
| **Catalog ID** | Attack/coverage ID from Crane adversarial skill: **A–H** classic, **I** trust-flag, **J** surface, **K** accounting-sync |
| **Coverage layer** | L0 example · L1 property fuzz · L2 sequence invariant · L3 Foundry handler invariant (see fuzz gap report methodology) |
| **Declaration test** | Facet/Package Behavior tests (`Behavior_IFacet`, DFPkg metadata) |
| **Proxy smoke** | Call product selectors on the **deployed diamond**, not the facet implementation address |
| **Theater** | Test or control list that cannot fail if the production bug class is present |
| **Work package (WP)** | Self-contained fix+test unit for one implementer/worktree (schema §8) |
| **Area** | Non-overlapping path/product slice for one review subagent |
| **Orchestrator** | Parent agent: partition, spawn, merge, aggregate, rank backlog |
| **Finding** | One actionable gap with severity, class (CODE/TEST/THEATER), evidence, close plan |

### 1.1 Severity (review findings)

| Severity | Meaning | Closure expectation |
|----------|---------|---------------------|
| **Blocker** | Free mint / free principal / unbounded extract / silent missing money API on proxy | Must be in first implementation wave; CODE before greenwash |
| **High** | P0 catalog missing on live money path; trust-flag I1–I3 absent; J surface hole on documented API | First or second wave |
| **Medium** | P1 catalog, weak exact selectors, preview/execute drift on non-primary route, L1 fuzz missing on hot math | Before major release / audit |
| **Low** | P2, docs/NatSpec defer hygiene, redundant tests, naming | Opportunistic |
| **Info** | Already covered; baseline note; intentional economic risk documented | No WP required |

### 1.2 Finding class

| Class | Meaning |
|-------|---------|
| **CODE** | Production behavior wrong or incomplete; implementer must change contracts (then tests) |
| **TEST** | Production appears correct; missing/weak proof in Foundry |
| **THEATER** | Existing test misleads (fix or replace test; may also need CODE if SUT wrong) |
| **DEFER** | Explicitly out of wave with reason (gas grief N-max, peer port, fork MEV reconstruction) |
| **NEEDS_OWNER** | Product-law ambiguity (e.g. should donations revert or benefit next depositor?) |

---

## 2. Normative coverage bar (what “complete” means)

Reviewers **must** score products against this bar. Skills are source of truth; this section is the audit checklist form.

### 2.1 Ship-gate references (read before reviewing)

| Source | Use |
|--------|-----|
| `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` | Catalog A–K, I/J mandatory patterns, anti-theater |
| `.../references/attack-catalog-template.md` | ID table for mapping |
| `.../references/implementation-test-dod.md` | Implementor DoD (maps to WP acceptance) |
| `lib/crane/.claude/skills/crane-testing/SKILL.md` | LR-7, surface matrix, production-first |
| `.claude/skills/indexedex-testing/SKILL.md` (or `.grok` mirror) | Registry path, mandatory negatives |
| `.claude/skills/indexedex-adversarial-testing/` | DETF/SE extensions + checklist |
| Gold suite | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/` |

### 2.2 Layers to score (per product)

| Layer ID | Name | Minimum for money products |
|----------|------|----------------------------|
| **H** | Happy-path matrix on production TestBase | Required |
| **N** | Negative / exact selectors (zero, deadline, access, slippage) | Required |
| **D** | Facet + Package declaration (Behavior) | Required for every Facet/DFPkg |
| **J** | Surface: Target API ⊆ facetFuncs ⊆ facetCuts ⊆ loupe ⊆ proxy callable | **P0** |
| **I** | Trust-flag / claimed amount (I1–I3 min if flag exists) | **P0** if `pretransferred` / Permit2 / msg.value credit |
| **K** | Reserve sync / donation mis-credit | **P0** if balance-based credit |
| **A–H** | Classic adversarial catalog (applicable subset) | **P0** subset per product class |
| **P** | Preview ≡ execute | Required where preview exists |
| **L1** | Property fuzz on hot conservation/math | Strongly recommended; score gap if absent |
| **L2/L3** | Sequence / handler invariants | Score; DETF currently critical gap historically |

### 2.3 Product-class P0 subsets (default)

Orchestrator may refine; reviewers must not invent weaker subsets without reason.

| Product class | Default P0 catalog / layers |
|---------------|----------------------------|
| **DETF (bond/claim)** | A1, A3, B1*, B3*, C1–C3, D2, D3, D6, E1, E5, F2–F3, H2, H3, **I1–I3**, **J1–J3**, **K1**, H, N, D, P |
| **Standard Exchange vault** | A1, C (in/out), E1, E5, H3, F (if unowned), **I1–I3**, **J1–J3**, **K1**, H, N, D, P |
| **Hook diamond package** | Route guards, residual, reentrancy if hooks call out, **J** full, flag/mining config tests, H, N |
| **Router / Permit2 coordinator** | Signature replay, allowance, wrong spender, **I5**, exact fail, H, N |
| **Manager / fee oracle** | Access, fee non-dilution properties, registry wiring, D, J |

\* B1/B3 N/A when no synthetic thresholds — substitute rate/route conservation.

### 2.4 Explicit known bug patterns (must hunt)

Every area agent **shall** actively search for these (not wait for catalog coincidence):

| Pattern ID | Symptom | Typical CODE fix direction | Required TEST proof |
|------------|---------|----------------------------|---------------------|
| **PAT-I-ABS** | `pretransferred` returns claimed amount after `balanceOf >= amount` without delta | Measure delta vs last reserve / balBefore; update snapshot | I1–I3 |
| **PAT-J-OMIT** | Target external/public money or documented view missing from `facetFuncs` | Add selectors + package cuts | J1–J3 |
| **PAT-J-CTRL** | `controlFacetFuncs` mirrors incomplete Facet | Controls from Target/interface | J1 |
| **PAT-K-DONATE** | Next deposit credits prior donation via raw balance | Strict mismatch revert or documented beneficiary + no victim loss | K1 |
| **PAT-THEATER-PRE** | Only happy `pretransferred=true` with real transfer | Add false claim cases | I1 |
| **PAT-THEATER-FACET** | Declaration tests never deploy package/proxy | Loupe + proxy smoke | J2–J3 |
| **PAT-PREV** | Preview ignores fees / wrong route vs execute | Align or remove unsupported preview | P |
| **PAT-MOCK** | Spec uses Mock SE / mockCall on SUT | Redeploy on gold TestBase path | H + adversarial on real SUT |

### 2.5 Product law anchors (do not contradict)

When scoring claim / pretransfer / fees, align with locked law where present (e.g. struct-audit fixes PRD **L-CLAIM-3**: `pretransferred=true` always requires proof of balance increase). If code and law disagree → finding class **CODE** (or **NEEDS_OWNER** only if law is unclear).

---

## 3. Program architecture (orchestrator → reports → later implement)

### 3.1 End-to-end pipeline (this PRD is stage 1 only)

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 1 — THIS PRD (review only)                                         │
│  Orchestrator partitions Areas → parallel review subagents →             │
│  area reports → aggregate report + WP backlog                            │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 2 — Planning agent (separate)                                      │
│  Reads aggregate report → writes TEST_COVERAGE_GAP_CLOSURE_              │
│  IMPLEMENTATION_PLAN.md (waves, worktrees, subagent prompts, deps)       │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 3 — Implementation orchestrator (separate)                         │
│  Worktrees + parallel CODE/TEST agents; production-first; forge green    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Stage 1 agents must not start Stage 3.** They may sketch WP IDs and acceptance commands so Stage 2 is cheap.

### 3.2 Stage 1 roles

```text
Orchestrator
  ├─ freeze inventory methodology + area map
  ├─ spawn Area review agents (parallel, read-only)
  ├─ optional specialists (see §3.4)
  ├─ merge, dedupe, conflict-resolve
  └─ write AGGREGATE report + global WP backlog
```

### 3.3 Orchestrator requirements

The Stage 1 orchestrator **shall**:

1. Read this PRD + `Claude.md` non-negotiables + adversarial/testing skills (including catalog I/J/K and DoD) before spawning.
2. Produce a **scope partition table** (Area → production paths → test paths → excluded) **before** subagents start; write it to `docs/testing/coverage-audit/00_SCOPE_PARTITION.md`.
3. Spawn subagents **in parallel** with **identical output schema** (§7).
4. Assign **non-overlapping** report paths (`docs/testing/coverage-audit/areas/<AREA_ID>.md`).
5. After returns:
   - Dedupe findings by `(product, pattern ID or catalog ID, path)`.
   - Resolve conflicts (e.g. one agent says CODE, another TEST) in a **Conflicts** section with one decision.
   - Build **global matrices**: catalog×product, layer×product, PAT×product.
   - Rank **Top N** work packages (default N=40) by severity × exploitability × blast radius (§8).
   - Diff vs 2026-07 adversarial/fuzz reports: **Still gap / Closed / New / Stale claim**.
6. **Not** edit production or test code.
7. Record commands used (`rg`, `find`, optional `forge test --list` samples) for reproducibility.

### 3.4 Subagent requirements (every area agent)

Each area agent **shall**:

1. Stay in path allowlist; out-of-area deps as **reference only**.
2. Complete workstreams in §6.
3. Emit report matching §7.
4. Prefer evidence: file paths, line ranges, test function names, whether test hits **proxy**.
5. Mark uncertainty (`unknown`, `needs runtime`, `needs product owner`).
6. Never recommend `via_ir`.
7. Classify every finding as CODE / TEST / THEATER / DEFER / NEEDS_OWNER.
8. For each High/Blocker: propose **at least one** concrete test name + setup sketch + pass criteria (implementers copy into plan).
9. Prefer production-first law when judging “covered”: mock-SUT tests do not count as H/A–K coverage.

### 3.5 Optional specialist agents

| Specialist | When to spawn |
|------------|---------------|
| **Trust-flag / accounting cross-cut** | After areas return ≥3 PAT-I-ABS or PAT-K hits — unify recommended fix in shared commons (`BasicVaultCommon`, ERC4626 service, DETF transfer lib) |
| **Facet surface cross-cut** | ≥3 PAT-J-OMIT — produce monorepo Target↔facetFuncs diff methodology + script sketch |
| **Fuzz/invariant specialist** | DETF/SE L1–L3 still empty — propose Handler surfaces without writing code |
| **Theater hunter** | Spot-check “security” tests that never assert balance deltas |

### 3.6 Parallelism rules

| Rule | Detail |
|------|--------|
| Min areas (full pass) | ≥6 |
| Pilot (optional) | 2–3 areas first to validate schema, then full pass |
| Max concurrent | Prefer 4–8 |
| Isolation | One report file per area; no shared mutable docs except orchestrator aggregate |
| Fail soft | Area `FAILED`/`PARTIAL` must not drop others |
| Time box | Orchestrator may mark `PARTIAL` with remaining inventory list |

### 3.7 Tooling hints

- Explore / general-purpose agents for Stage 1; **no commits** of product or test tree changes.
- `rg` for: `pretransferred`, `facetFuncs`, `controlFacetFuncs`, `function test_I`, `function test_A1`, `adversarial/`, `testFuzz_`, `invariant_`, `vm.mockCall`, `MockStandardExchange`.
- Diff Target `function` external/public vs Facet `facetFuncs` arrays (manual or scripted list).
- List tests: `forge test --list --match-path '...'` when environment allows (do not block inventory on compile failures — note `BUILD_BLOCKED`).
- Prefer static mapping + targeted forge; full-suite runs only when needed for Blocker proof or to falsify “already green” claims.

### 3.8 Runtime proof for Blocker CODE claims (locked)

For findings classified **Blocker** + **CODE** (e.g. free mint via `pretransferred`, free principal, unbounded extract, money API missing on proxy that integrators must call):

1. **Static evidence alone is insufficient** to ship the finding as Blocker CODE.
2. Reviewer **shall** obtain **runtime proof** where the environment allows:
   - Prefer: existing test that fails to catch the bug, or a **throwaway** local repro (not committed) that shows the bad state transition (e.g. attacker share balance increases with no transfer).
   - Or: `forge test` / scripted call path against production-deployed instance in hermetic (or fork if that is the only path).
3. Record in the finding: exact command, observed balances/reverts, and whether the bug is **confirmed** / **not reproducible** / **BUILD_BLOCKED**.
4. If runtime is impossible (`BUILD_BLOCKED`, missing TestBase), keep severity **High** max unless static evidence is overwhelming **and** label `RUNTIME_UNPROVEN`; Stage 2 must include a proof-first task.
5. **Still no committed** production or permanent **test suite** diffs in Stage 1 — do not land fix PRs under this stage.
6. **Repro evidence may be stored** under `docs/testing/coverage-audit/repro/` (commands, forge logs, balance dumps, short throwaway snippets used only for proof). Prefer logs + commands over long-lived PoC contracts; never commit secrets/`ALCHEMY_KEY`.

Medium/Low CODE findings may remain static-only with lower confidence.

---

## 4. Default area partition

Orchestrator may refine names/paths but must keep **non-overlapping production ownership**. Tests may be cited across areas when shared; the **owning** area is where the SUT package lives.

| Area ID | Production (primary) | Tests (primary) | Focus |
|---------|----------------------|-----------------|-------|
| `T-detf-multi-vault` | `contracts/vaults/detf/**/multi-vault-weighted/**` (+ shared common used only as ref) | `test/**/multi-vault-weighted/**` | Gold baseline; verify I/J/K present or explicit defer; theater audit |
| `T-detf-single-se` | Single SE DETF package(s) | matching `test/**/standardExchange/single/**` | Port completeness vs MultiVault; I/J/K |
| `T-detf-composed-stable` | Composed stable / mixed buffer DETF | matching `test/**/stable/**`, `mixedBuffer/**` | Multi-leg residual, claim, G nested |
| `T-detf-single-vault-seigniorage` | SingleVault + Seigniorage DETF surfaces | matching tests | Bond/NFT, gates, I/J |
| `T-detf-dual-liquidity` | DualLiquidity cross-version vault | fork + hermetic dual-liquidity tests | Catalog consolidation; ShareInflation vs I/K; **fork P0 gaps = equal severity to hermetic** (§19) |
| `T-se-aerodrome-camelot-univ2` | Aerodrome / Camelot / Uni V2 SE vaults | `test/**` + protocol TestBases | Shared SE adversarial; pretransfer; routes |
| `T-se-univ4-aave-balancer` | Uni V4 SE, Aave Stata SE, Balancer SE routers | matching | Fork/hermetic; I/J; router negatives |
| `T-hooks-v4` | `contracts/hooks/**` | hook package tests | Flags, deployHookVault, J surface, residual |
| `T-basic-protocol-commons` | `BasicVaultCommon`, protocol DETF commons, claim/NFT targets, secure transfer libs | unit/spec negatives | **PAT-I-ABS epicenter**; shared fix recommendations |
| `T-manager-fee-registry` | manager, fee collector, fee oracle, vault registry | matching | Access, wiring, non-dilution properties |
| `T-routers-permit2` | routers, Permit2 paths | matching | I5, signature, allowance theater |

**Optional full-pass add-ons:**

| Area ID | Scope |
|---------|--------|
| `T-slipstream-buffer` | Slipstream / buffer pool invariants (L3 gold exists — score reuse) |
| `T-research-contracts` | Only if `research/**` still contains deployable product-like contracts with tests |

**Out of scope paths (default):** `frontend/**`, `broadcast/**`, `out/**`, `cache/**`, pure docs marketing, Godot/game skills noise.

---

## 5. Inventory methodology (per area)

For each product in the area:

### 5.1 Locate

1. DFPkg / Facets / Targets / common libs.
2. Gold `TestBase_*` inheritance chain.
3. Spec tests, fork tests, `adversarial/`, fuzz, invariant handlers.
4. Prior report claims for this product (adversarial + fuzz gap reports).

### 5.2 Map

| Artifact | Record |
|----------|--------|
| Product name + role names used | DETF roles only if DETF |
| Deploy path in tests | registry? create3? `new`? mock? |
| Catalog IDs present as `test_<ID>_` or NatSpec map | list |
| Layers H/N/D/J/I/K/A–H/P/L1–L3 | F / P / G / N/A / S (stub) |
| Trust-flag entrypoints | function signatures with `pretransferred` / permit |
| Facet list | each facet path + whether control list is Target-derived (evidence) |

### 5.3 Hunt patterns

Run through §2.4 pattern table; for each hit open a finding.

### 5.4 Score maturity

| Score | Meaning |
|-------|---------|
| **0** | No meaningful production-path tests |
| **1** | Happy only / mocks / theater |
| **2** | Happy + some negatives; missing I or J |
| **3** | Strong H/N/D; partial adversarial; I or J incomplete |
| **4** | P0 adversarial + I/J/K (as applicable) green; weak L1+ |
| **5** | P0/P1 + property layer + gold-comparable to MultiVault |

---

## 6. Workstreams (every area agent)

| WS | Name | Output in area report |
|----|------|------------------------|
| **WS1** | Product inventory | Table of packages + TestBases + test roots |
| **WS2** | Layer matrix | H/N/D/J/I/K/A–H/P/L1–L3 scores |
| **WS3** | Catalog matrix | A–K IDs: F/P/G/N/A + evidence test names |
| **WS4** | Pattern hunt | PAT-* findings with CODE/TEST/THEATER |
| **WS5** | Theater audit | List of misleading tests + why |
| **WS6** | Prior-report diff | Still gap / Closed / New vs 2026-07 docs |
| **WS7** | Work package drafts | WP stubs (§8) for every Blocker/High and clustered Mediums |
| **WS8** | Open questions | NEEDS_OWNER + build blockers |

---

## 7. Report schemas (normative)

### 7.1 Directory layout

```text
docs/testing/coverage-audit/
  00_SCOPE_PARTITION.md          # orchestrator, before parallel work
  01_METHODOLOGY_NOTES.md        # optional: commands, tool versions
  areas/
    T-detf-multi-vault.md
    T-detf-single-se.md
    ...
  repro/                         # optional Stage 1 runtime proof logs (L-TCA-7)
    <FINDING_ID>/
      cmd.sh                     # or COMMANDS.md
      forge.log
      notes.md                   # balances, selectors, outcome
  AGGREGATE.md                   # orchestrator final
  WORK_PACKAGE_BACKLOG.md        # ranked WPs for Stage 2 planner
```

### 7.2 Area report template

Each `areas/<AREA_ID>.md` **must** include:

```markdown
# Test Coverage Audit — <AREA_ID>

| Field | Value |
|-------|--------|
| Date | YYYY-MM-DD |
| Agent / run | |
| Status | COMPLETE \| PARTIAL \| FAILED |
| Production paths | |
| Test paths | |
| Skills / PRD version cited | TEST_COVERAGE_AUDIT_PRD |

## 1. Executive summary
- Maturity scores by product (0–5)
- Blocker/High counts
- Top 5 recommended WPs

## 2. Product inventory
| Product | DFPkg / key Targets | TestBase | Test roots | Deploy path quality |

## 3. Layer matrix
| Product | H | N | D | J | I | K | A-H | P | L1 | L2 | L3 | Notes |

## 4. Catalog matrix (A–K)
| ID | Product… | Evidence (test name or G) |

## 5. Findings
### 5.x [FINDING_ID] severity · class · pattern/catalog
- Summary
- Evidence (paths:lines, test names)
- Why bar fails
- Recommended CODE change (if any)
- Recommended TEST (name, setup, pass criteria, match-path)
- Suggested WP id
- Priority

## 6. Theater list
| Test / control | Why theater | Fix |

## 7. Prior-report diff
| Claim (doc) | Status now |

## 8. Work package stubs
(see §8 fields — at least for Blocker/High)

## 9. Deferred / N/A / NEEDS_OWNER

## 10. Commands run
```

### 7.3 Finding ID format

```text
TCA-<AREA_SHORT>-<NNN>
```

Examples: `TCA-SE-AC-001`, `TCA-DETF-MV-012`, `TCA-COMMON-003`.

Aggregate may remap to stable global IDs `TCA-G-###` when deduping.

### 7.4 Aggregate report template (`AGGREGATE.md`)

Must include:

1. **Program metadata** — date, areas COMPLETE/PARTIAL/FAILED, PRD status.
2. **Executive summary** — maturity heatmap, Blocker list, shared commons epics (I/J).
3. **Global layer matrix** (products × layers).
4. **Global catalog matrix** (products × A–K).
5. **Pattern incidence** (PAT-* counts and epicenters).
6. **Deduped findings** (all Blocker/High; Medium if space; link area reports).
7. **Conflicts & decisions**.
8. **Diff vs 2026-07 adversarial + fuzz reports**.
9. **Recommended implementation waves** (input to Stage 2 — not a full plan):
   - Wave 0: shared commons CODE (BasicVaultCommon / secure pull) + shared test harness
   - Wave 1: Blocker/High CODE+TEST per product parallel sets
   - Wave 2: remaining P0 adversarial ports
   - Wave 3: L1/L3 property layer
10. **Link** to `WORK_PACKAGE_BACKLOG.md`.

### 7.5 Work package backlog file

`WORK_PACKAGE_BACKLOG.md` is the **primary handoff** to the Stage 2 planning agent. Schema in §8.

---

## 8. Work package schema (for Stage 2 / Stage 3)

Each WP must be implementable in **one worktree** by **one agent** (or a tightly coupled CODE+TEST pair) without editing another WP’s primary files.

| Field | Required | Description |
|-------|----------|-------------|
| **WP-ID** | yes | e.g. `WP-I-COMMON-001`, `WP-J-DETF-NFT-002` |
| **Title** | yes | Short imperative |
| **Severity** | yes | Blocker/High/Medium/Low |
| **Class** | yes | CODE / TEST / BOTH |
| **Products** | yes | Affected packages |
| **Finding IDs** | yes | TCA-* links |
| **Problem** | yes | 2–5 sentences |
| **Production files (touch set)** | if CODE | Explicit paths; minimize blast radius |
| **Test files (touch set)** | yes | New or existing paths |
| **Out of scope files** | yes | Prevent thrash |
| **Depends on** | yes | Other WP-IDs or `none` |
| **Parallelizable with** | yes | WP-IDs safe concurrent |
| **Suggested worktree** | yes | Prefix **`gap_cover_`** — e.g. `gap_cover_i-common`, branch `gap_cover/i-common` |
| **Implementation notes** | yes | Pointers to skills, gold tests to copy |
| **Acceptance** | yes | Exact forge commands + required `test_*` names / catalog IDs |
| **Anti-theater checks** | yes | e.g. “I1 must not transfer tokens”; “J3 calls proxy” |
| **Estimate** | optional | S/M/L |

### 8.1 Wave guidance (normative for planners)

| Wave | Contents |
|------|----------|
| **0** | Shared CODE for PAT-I-ABS / secure transfer; shared adversarial harness helpers; do **not** fork all products until commons land if they share the bug |
| **1** | Per-product Blocker/High: remaining CODE + I1–I3 + J1–J3 |
| **2** | Remaining classic A–H P0 ports; K1; theater replacement |
| **3** | L1 fuzz + L2/L3 invariants; P1 catalog |
| **4** | P2 / optional BasicVault / stub retirement |

### 8.2 Parallelism constraints for Stage 3 (document in backlog)

- WPs that edit the **same** common lib (`BasicVaultCommon`, shared DETF transfer) are **serial** or single WP.
- Product-local adversarial suites under different `test/.../adversarial/` trees are **parallel**.
- Facet selector fixes may be parallel **per package** if DFPkgs do not share facet contracts.
- Never parallel two agents on the same Facet file without merge plan.

---

## 9. Scoring and ranking

### 9.1 Composite priority (for Top N WP backlog)

```text
score = severity_weight × exploitability × blast_radius × (1 if CODE else 0.7)
```

| Factor | Weights |
|--------|---------|
| severity_weight | Blocker=5, High=4, Medium=2, Low=1 |
| exploitability | 3 = external user, single tx; 2 = needs capital/special token; 1 = admin/config only |
| blast_radius | 3 = shared commons / all vaults; 2 = whole DETF family; 1 = single package |

Orchestrator sorts descending; ties break by CODE first, then shared commons.

### 9.2 Maturity heatmap (aggregate)

Table: Product × maturity 0–5 + worst open severity. Used for executive readout.

---

## 10. Relationship to prior documents

| Document | How Stage 1 uses it |
|----------|---------------------|
| `ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` | Seed matrix; **re-verify** every cell; catalog was A–H only — add I/J/K columns |
| `ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md` | Historical waves; mark done vs residual; do not assume IMPLEMENTED claims without evidence |
| `FUZZ_INVARIANT_COVERAGE_*` | Seed L1–L3 gaps; re-count `testFuzz_` / `invariant_` / handlers |
| `NEGATIVE_TEST_COVERAGE_REPORT.md` | Seed pretransfer/donation negatives; expand monorepo-wide |
| `docs/reviews/2026-08-08_struct-audit_*` | CODE findings that imply missing tests (facet holes, pretransfer law) — link, don’t re-litigate structs |
| `STRUCT_AUDIT_FIXES_PRD.md` | Product law anchors (e.g. L-CLAIM-3) remain valid; **this program owns** I/J/K **test/security gap WPs** (CODE+TEST), even when struct-audit already flagged the same surfaces |
| Skills / `implementation-test-dod.md` | Normative bar for “closed” |

**Supersession:**

- For **catalog completeness**, this PRD + current Crane adversarial skill (A–K) supersede A–H-only matrices.
- For **test/security gap work packages** (missing tests, theater, trust-flag free mint, facet/proxy holes, donation sync): **this program supersedes** struct-audit “fix later” lists — Stage 2/3 plans from **this** backlog, not parallel competing fix lists. Link struct-audit finding IDs for traceability; do not drop CODE work because it was “already mentioned” elsewhere.
- For **product economics / claim unwind / fee beneficiary law**, locked product PRDs (including struct-audit fixes §2 where accepted) win over reviewer opinion (`NEEDS_OWNER` if conflict).

---

## 11. Hard constraints (non-negotiable)

1. **No committed** product or permanent test tree edits in Stage 1 (reports only under `docs/testing/coverage-audit/`). Runtime proof and throwaway local repros are allowed per §3.8; do not leave PoC contracts in the repo.
2. **`via_ir` forbidden** in any recommendation.
3. **No mock SUT** counted as coverage for money products.
4. **DETF role names** only in reports.
5. **Exact selectors** required in recommended negatives — no bare `expectRevert()` as acceptance.
6. **Proxy vs facet**: J acceptance must specify **proxy** calls after registry/factory deploy.
7. **Delta vs absolute balance**: I acceptance must prove free-mint impossible when vault already holds inventory.
8. **Real exploit → CODE first** in WP notes; do not plan green tests that assert buggy free mint as “expected” without `NEEDS_OWNER` + product decision.
9. Facets/DFPkgs: recommendations must use CREATE3 + registry paths, never `new` production facets.

---

## 12. Definition of Done (Stage 1)

Stage 1 is complete when:

- [ ] `00_SCOPE_PARTITION.md` exists and was used for spawning.
- [ ] Every planned area is `COMPLETE` or `PARTIAL`/`FAILED` with reason.
- [ ] Every area report validates against §7.2 sections 1–10.
- [ ] `AGGREGATE.md` includes global matrices, pattern incidence, prior-report diff, wave sketch.
- [ ] `WORK_PACKAGE_BACKLOG.md` has ranked WPs with full §8 fields for all Blocker/High (Medium clustered OK).
- [ ] At least one explicit finding or clean bill for **PAT-I-ABS** on shared transfer commons, with **runtime** attempt per §3.8 / L-TCA-3.
- [ ] At least one monorepo-level statement on **PAT-J-OMIT** (epic list or clean bill).
- [ ] Ship-blocking products (§19 L-TCA-2) all appear in area inventory (pilot + full).
- [ ] No Stage 3 implementation or committed product/test fixes under this PRD.

---

## 13. Stage 2 planner requirements (handoff contract)

The agent writing `TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md` **shall**:

1. Treat `WORK_PACKAGE_BACKLOG.md` + `AGGREGATE.md` as primary inputs.
2. Expand WPs into executable tasks: worktree names, branch names, subagent prompts, merge order, verification commands.
3. Respect Wave 0 commons serialization.
4. Embed skills: `crane-testing`, `crane-adversarial-testing`, `indexedex-testing`, `indexedex-adversarial-testing`, DoD reference.
5. Require per-WP: production-first deploy, anti-theater checks, catalog test naming `test_<ID>_…`.
6. Not re-open product law settled in other PRDs without `NEEDS_OWNER` escalation.
7. Define final program acceptance: all Blocker/High WPs merged; `forge test` green on touched paths; deferred IDs in suite NatSpec.

*(Stage 2 plan is not authored in this PRD.)*

---

## 14. Stage 3 implementer requirements (handoff contract)

Implementers / implementation subagents **shall**:

1. Read the WP + linked findings + DoD before coding.
2. Use worktree/branch names prefixed with **`gap_cover_`** (L-TCA-8).
3. Prefer **fix production CODE** when class is CODE/BOTH, then tests that would have failed before the fix.
4. Never greenwash free mint.
5. Use gold TestBases and registry deploy paths; fork tests via **Alchemy** `rpc_endpoints` aliases (L-TCA-6).
6. Add I1–I3 / J1–J3 when WP touches those surfaces.
7. Leave unrelated products untouched.
8. Run WP acceptance forge commands and paste evidence in PR/worklog.

*(Stage 3 execution is not authorized by this PRD alone.)*

---

## 15. Pilot first (locked), then full pass

Stage 1 **shall not** start the full area partition until pilot exit criteria pass (unless the user explicitly overrides).

### 15.1 Pilot areas (mandatory set)

| Pilot areas | Why |
|-------------|-----|
| `T-basic-protocol-commons` | PAT-I-ABS epicenter; unblocks all vaults |
| `T-detf-multi-vault` | Gold baseline + theater check + I/J/K on best suite |
| `T-se-aerodrome-camelot-univ2` | High traffic SE + pretransfer paths |

### 15.2 Pilot exit criteria

- [ ] Three area reports match §7.2
- [ ] Thin pilot `AGGREGATE.md` + sample `WORK_PACKAGE_BACKLOG.md` (≥5 real WPs, including any confirmed Blocker)
- [ ] Schema issues fixed before full spawn
- [ ] At least one **runtime** attempt on the top PAT-I-ABS candidate (success or BUILD_BLOCKED documented)

### 15.3 Full pass

After pilot exit: spawn remaining areas in §4 (all ship-blocking money products).

---

## 16. Risks

| Risk | Mitigation |
|------|------------|
| Stale 2026-07 matrices trusted blindly | Mandatory prior-report **diff** with evidence |
| Area overlap on shared commons | Commons owned by `T-basic-protocol-commons`; others reference |
| Reviewers mark “covered” from facet-only tests | J bar requires proxy |
| Scope explosion into full audit | Severity cap; P2 DEFER; time box PARTIAL |
| Compile broken → no forge --list | Static mapping still required; mark BUILD_BLOCKED |
| Stage 1 starts implementing fixes | Explicit non-goal; orchestrator rejects **committed** code diffs (throwaway runtime proof OK) |
| Fork RPC unavailable | Prefer `*_alchemy` endpoints + `ALCHEMY_KEY` (L-TCA-6); else BUILD_BLOCKED / RUNTIME_UNPROVEN; keep severity, flag env for Stage 2 |

---

## 17. Revision history

| Date | Change |
|------|--------|
| 2026-08-09 | Initial PRD: Stage 1 coverage audit program; catalog A–K + patterns I/J/K; multi-stage handoff to planning and parallel implementation |
| 2026-08-09 | Locked open items (§19): pilot-first; all money products ship-blocking; runtime proof for Blockers; supersede struct-audit for I/J/K WPs; fork gaps equal priority |
| 2026-08-09 | L-TCA-6 Alchemy RPC aliases; L-TCA-7 repro/ logs allowed; L-TCA-8 `gap_cover_` worktree/branch prefix |

---

## 18. Quick links for agents

| Need | Open |
|------|------|
| This process law | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` |
| Adversarial method | `lib/crane/.claude/skills/crane-adversarial-testing/` |
| Ship-gate checklist | `.../references/implementation-test-dod.md` |
| DETF checklist | `.claude/skills/indexedex-adversarial-testing/references/detf-adversarial-checklist.md` |
| Agent law tests | `docs/agent/INDEXEDEX_AGENT_LAW.md` |
| Gold adversarial suite | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/` |
| Historical adversarial gaps | `docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` |
| Historical fuzz gaps | `docs/testing/FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md` |

---

## 19. Locked decisions (2026-08-09)

Product-owner answers; **normative** for Stages 1–3.

| ID | Decision | Implication |
|----|----------|-------------|
| **L-TCA-1** | **Pilot first**, then full monorepo partition | §15 is mandatory; full spawn only after pilot exit (unless user overrides) |
| **L-TCA-2** | **Ship-blocking set = all money products** under `contracts/` vaults, DETFs, SE packages, hooks, and production routers that move user funds | Blocker/High gaps on any of these cannot be DEFER’d as “not launch set”; only true P2/gas/MEV-style items use DEFER |
| **L-TCA-3** | **Runtime proof required for Blocker CODE** | §3.8; static-only → max High + `RUNTIME_UNPROVEN` if unproven |
| **L-TCA-4** | **This program supersedes struct-audit for test/security gap WPs** | I/J/K CODE+TEST ownership lives in coverage-audit backlog; link struct-audit IDs; do not fork competing fix programs |
| **L-TCA-5** | **Fork coverage gaps have equal priority to hermetic** when the product’s gold TestBase / production path is fork-first | DualLiquidity (and similar) missing fork P0 adversarial is still High/Blocker, not automatically P1 |
| **L-TCA-6** | **Fork RPC: prefer Alchemy aliases from `foundry.toml`** | Use `[rpc_endpoints]` names ending in `_alchemy` (e.g. `base_mainnet_alchemy`, `ethereum_mainnet_alchemy`, `base_sepolia_alchemy`). Requires `ALCHEMY_KEY` in env. Prefer `FOUNDRY_PROFILE=fork` + these endpoints over Infura/public RPCs for Stage 1 proof and Stage 3 fork tests. Document `BUILD_BLOCKED` if key/RPC missing. |
| **L-TCA-7** | **Repro logs allowed under `docs/testing/coverage-audit/repro/`** | Stage 1 may commit commands, forge logs, balance dumps, and short proof notes per finding ID. No secrets. Prefer evidence over permanent PoC contracts. |
| **L-TCA-8** | **Branch / worktree prefix `gap_cover_`** | Stage 2/3 naming: worktrees and branches start with `gap_cover_` (e.g. worktree `gap_cover_i-common`, branch `gap_cover/i-common` or `gap_cover_i-common`). WP “Suggested worktree” field must use this prefix. |

### 19.1 Fork commands (guidance)

```bash
# Example: Base mainnet fork profile + Alchemy endpoint alias from foundry.toml
# Ensure ALCHEMY_KEY is set in the environment (not committed).
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**' \
  --fork-url base_mainnet_alchemy -vv
```

Use the chain-appropriate `*_alchemy` alias from `foundry.toml` `[rpc_endpoints]`. Do not invent hardcoded Alchemy URLs in reports.

**Still open (non-blocking):** Stage 2 plan filename freeze when planner starts (default remains `docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md`).
