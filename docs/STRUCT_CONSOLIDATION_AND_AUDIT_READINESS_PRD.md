# Product Requirements Document (PRD)

## Title

**Struct Consolidation + Stack-Relief Hygiene + External Audit Readiness Review** — agent-orchestrated, parallel codebase review that finds redundant / over-fragmented structs and produces a prioritized optimization + audit-prep report

## Status

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** — process law; **open items LOCKED 2026-08-08** (§14) |
| **Scope** | Full pass: `contracts/**` including `contracts/protocols/**`, plus full `research/**` struct inventory; see §5 |
| **Primary output** | Aggregated report under `docs/reviews/` (not code changes in the review pass) |
| **Hard constraints** | **`via_ir` forbidden** on default/CI profiles; stack-too-deep may only be fixed with structs / helpers / scoping (see Crane `crane-code-style`) |
| **Deploy posture** | **Pre-launch** — storage layout may change with tests; still document migration risk |
| **Gas measurement** | **Hermetic first** (default profile); fork only if hermetic cannot exercise the path |
| **Related** | `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md`, `docs/archive/CODE_REVIEW_PLAN.md`, `docs/reviews/TEMPLATE.md`, `docs/components/REVIEWER_REQUIREMENTS.md`, `Claude.md` / `docs/agent/INDEXEDEX_AGENT_LAW.md` |
| **Execute plan** | [`docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_EXECUTE_PLAN.md`](./STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_EXECUTE_PLAN.md) — orchestrator steps, parallel subagent prompts, report QA |

---

## 0. Intent (why this exists)

### 0.1 Problem

Many agents have refactored IndexedEx contracts to compile **without IR** by introducing **memory/calldata structs** and helper functions. That was correct for stack depth, but has side effects:

1. **Struct proliferation** — multiple near-identical param / scratch / result structs per family, path, or helper chain.
2. **Redundant members** — fields copied between nested structs, never read after write, or duplicated under different names (`amountIn` vs `assetsIn`).
3. **Unclear ownership of “context”** — a single external call often builds 3–6 intermediate structs that could be one **execution context** passed through helpers.
4. **Gas and audit cost** — extra `MSTORE`/`MLOAD`, memory expansion, and ABI noise; auditors must reverse-engineer which fields are live at each step.
5. **Quality debt before external audit** — inconsistent naming, dead paths, missing NatSpec on money paths, access-control ambiguity, and preview/execute asymmetry are harder to spot while the struct graph is noisy.

This program does **not** implement refactors. It produces a **decision-grade report** so a later implementation plan can change code deliberately, measure gas, and keep default-profile compilation green.

### 0.2 Goals

1. **Inventory** every `struct` in scope — production under `contracts/**` (including `protocols/**`) and research under `research/**` (definition site, kind, consumers, size estimate).
2. **Find collapse candidates** where N structs can become fewer (ideally one **context** / **params** / **result** per hot path) **when that is gas-neutral or gas-positive** and still stack-safe without IR.
3. **Find redundant members** (unused, always-default, duplicated, or only used for stack padding that a helper split would replace better).
4. **Score gas impact** of each recommendation with an explicit method (static reasoning + optional `forge snapshot` / `forge test --gas-report` on a shortlist).
5. **Score audit readiness** of the same surfaces (correctness, access control, storage safety, economic invariants, observability).
6. **Parallelize** review via an **orchestrator agent** that spawns **area subagents** with non-overlapping scopes, then aggregates into one report.
7. **Preserve non-negotiables**: no `via_ir`; Crane deploy patterns; production-first tests; DETF role names; `PkgInit`/`PkgArgs` on interfaces.

### 0.3 Non-goals

- Implementing consolidations or “drive-by” cleanups in the review pass.
- Enabling `via_ir` / IR-only “fixes.”
- Mechanical style nits with no gas or audit impact (unless they block auditor navigation).
- Full formal verification or a substitute for a professional external audit.
- Treating pure vendored upstream under `lib/**` as IndexedEx product law (inventory only if an in-scope file defines types there; prefer IndexedEx `contracts/protocols/**` surfaces).
- Frontend (`frontend/**`), generated artifacts, and broadcast outputs.
- Changing product economics, fee schedules, or DETF family law in the review pass.
- Implementing storage packing changes without the implementation-phase test gates (§11).

### 0.4 Success definition

A single aggregated report that an implementer or external auditor can use to:

- Prioritize **high-ROI struct collapses** (gas + clarity).
- Know **what not to touch** (storage packing, public ABI, stack-critical shapes).
- See **audit blockers / high findings** with file:line evidence and repro commands.
- Feed a follow-on **implementation plan** (out of scope for this PRD’s execution phase).

---

## 1. Definitions

| Term | Meaning |
|------|---------|
| **Stack-relief struct** | `memory` / `calldata` struct introduced primarily so locals fit the EVM stack without IR |
| **Execution context struct** | Single in-flight state bag for one external/public entrypoint (params + loaded state + intermediate results) |
| **API struct** | User- or package-facing type on an **interface** (`PkgInit`, `PkgArgs`, swap params, etc.) |
| **Storage layout struct** | `Repo` / diamond storage `struct Storage { ... }` bound to a slot |
| **Result struct** | Return or out-params grouping (preview result, mint split, harvest result) |
| **Collapse** | Merge two or more structs (or member sets) into fewer types **or** one context passed through helpers |
| **Member redundancy** | Field never read, always equal to another field, only written, or duplicated across nested structs |
| **Gas-positive collapse** | Expected fewer memory ops / copies / expansions, or better storage packing, without worse hot-path cold loads |
| **Stack-safe** | Compiles under default profile with `via_ir = false` |
| **Area** | Non-overlapping directory/product slice assigned to one subagent |
| **Orchestrator** | Parent agent that partitions scope, spawns subagents, merges reports, resolves conflicts |
| **Finding** | One actionable item with severity, evidence, recommendation, verification |

---

## 2. Hard constraints (non-negotiable)

1. **`via_ir` remains forbidden** for default / CI / shared profiles. Recommendations must remain stack-safe or call out a **helper split** alternative if collapse reintroduces stack-too-deep.
2. **Do not propose `new` for facets/DFPkgs** or bypass vault registry deploy paths.
3. **Do not mock SUT** when verifying claims with tests; use production deploy paths (`indexedexManager.deploy*DFPkg`, CREATE3, gold TestBases).
4. **Storage layout changes** are allowed under **pre-launch** posture but remain **audit-critical**: any collapse touching `Storage` / slot packing must be labeled **storage migration risk**, require implementation-phase tests (§11), and must not be silent. Prefer packing wins that keep semantic field sets clear for auditors.
5. **Public / interface ABI structs** (`PkgInit`, `PkgArgs`, external params): collapsing changes integrators; treat as **breaking** for external integrators even pre-launch unless unused — still prefer consolidation when no external consumers exist yet; document in changelog notes.
6. **DETF role names** only in recommendations (`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveBpt`, `rebasingClaimToken`).
7. **Review pass is read-only** for product code unless the user explicitly authorizes a separate implementation phase.

---

## 3. Gas model for struct decisions (normative guidance)

Subagents **must** reason with this model. Collapsing structs is **not** automatically a gas win.

### 3.1 When fewer structs often help

| Pattern | Why |
|---------|-----|
| Nested copy chains (`A` → `B` → `C` with overlapping fields) | Fewer `MLOAD`/`MSTORE` and less free-memory growth |
| Multiple small structs rebuilt in a loop | Amortize one context; avoid per-iteration allocations |
| Identical param structs duplicated per family with same layout | One shared type reduces bytecode duplication and maintenance |
| Storage structs with bad packing (e.g. `uint256`, `address`, `uint256`, `address`) | Packing to fewer slots is a real SLOAD/SSTORE win |
| Dead members written on every path | Stop paying stores/copies for unused data |

### 3.2 When more structs / keep-as-is is better

| Pattern | Why |
|---------|-----|
| Stack-too-deep without current split | Stack slots are cheaper than memory thrash **until** the compiler fails |
| Calldata structs on external entrypoints | Calldata reads can beat memory copies; don’t force everything into one fat `memory` bag if only a subset is needed |
| Cold storage fields loaded “just in case” into a mega-context | Loading unused storage into memory can **increase** gas |
| Clear domain boundaries (fees vs routes vs bond) that aid audit | Clarity can outweigh micro-gas if gas delta is noise |
| Result-only structs that avoid stack returns of many values | Keep if collapse forces deep stack on return paths |

### 3.3 Required gas classification per recommendation

Each collapse / member-removal recommendation **must** include:

| Field | Values |
|-------|--------|
| **Expected gas direction** | `positive` / `neutral` / `negative` / `unknown` |
| **Mechanism** | e.g. fewer memory copies, better packing, less bytecode, fewer SLOADs |
| **Hot path?** | Yes/No (mint/burn/swap/bond/claim/compound vs view/admin/deploy) |
| **Confidence** | `low` (static only) / `medium` (pattern match + code path) / `high` (`forge` gas evidence) |
| **Measurement plan** | Exact command(s) for a later implementer (e.g. `forge snapshot --match-test …`) |

**High-severity gas claims** (asserting meaningful savings on hot paths) require **high confidence** or an explicit follow-up measurement task. Do not invent percentage savings without evidence.

**Measurement environment (locked):** prefer **hermetic** evidence — default Foundry profile / hermetic tests via `forge snapshot` or `forge test --gas-report`. Use `FOUNDRY_PROFILE=fork` (or a path-specific fork profile) **only** when hermetic cannot exercise the hot path.

### 3.4 Prefer these refactor shapes (when recommending)

Order of preference for stack relief **and** gas hygiene:

1. **One execution context** per external entrypoint, passed `memory` to private/internal helpers.
2. **Calldata params** at the external boundary; copy into context only fields needed after external calls.
3. **Helper extraction** with tight scopes (`{ ... }` blocks) before adding a new parallel struct.
4. **Shared library types** for cross-family identical layouts (e.g. harvest/redeem params).
5. **Avoid** deep nesting (`Foo` contains `Bar` contains `Baz` with 80% field overlap).

Anti-patterns to flag:

- Struct-of-structs where a flat context would do.
- “Params” + “State” + “Cache” + “Scratch” + “Result” all live at once with duplicate fields.
- Copy-paste structs across DETF families that diverged only in naming.
- Members present solely to “use” a variable to silence warnings.

---

## 4. Program architecture (orchestrator + subagents)

### 4.1 Roles

```text
┌─────────────────────────────────────────────────────────────┐
│ Orchestrator (parent agent)                                 │
│  - lock inventory methodology                               │
│  - partition Areas (non-overlapping)                        │
│  - spawn N subagents in parallel                            │
│  - merge findings, dedupe, resolve conflicts                │
│  - produce aggregate report + priority backlog              │
└─────────────────────────────────────────────────────────────┘
          │ parallel
          ├─ Area Agent A  (inventory + struct + gas + audit slice)
          ├─ Area Agent B
          ├─ Area Agent C
          └─ … (see §5 default partition)
```

Optional specialist agents (orchestrator may spawn after first pass if volume warrants):

| Specialist | Trigger |
|------------|---------|
| **Cross-cutting struct graph** | Same struct name/layout appears in ≥3 areas |
| **Gas measurement** | ≥5 `high` hot-path gas recommendations need numbers |
| **Storage/ABI risk** | Any recommended change to `Storage` or public interface structs |
| **Adversarial / money-path** | Area has mint/burn/swap/bond/claim without recent adversarial suite note |

### 4.2 Orchestrator requirements

The orchestrator **shall**:

1. Read this PRD + `Claude.md` non-negotiables + Crane code-style stack-too-deep rules before spawning.
2. Produce a **scope partition table** (Area → paths → excluded paths) **before** subagents start.
3. Spawn subagents **in parallel** with **identical output schema** (§7).
4. Forbid overlapping write targets for area reports (one file per area).
5. After subagents return:
   - Dedupe findings by (path, struct, member, recommendation class).
   - Escalate conflicts (e.g. one agent says collapse, another says keep for stack) to a **Conflict** section with a single orchestrator decision.
   - Build a **global struct inventory** (union of area inventories).
   - Rank a **Top N backlog** (default N=25) by composite score (§8).
6. **Not** implement code changes in the review program unless the user starts a separate implementation phase.
7. Record exact tool/commands used (rg/find, forge, etc.) for reproducibility.

### 4.3 Subagent requirements (every area agent)

Each area subagent **shall**:

1. Stay within its path allowlist; if a dependency outside the area is essential, cite it as **out-of-area reference** without expanding full review there.
2. Complete all workstreams in §6 for its area (inventory, redundancy, collapse, gas, audit quality).
3. Emit a report file matching §7.
4. Prefer evidence: file paths, line ranges, struct names, call chains (entrypoint → helpers).
5. Mark uncertainty explicitly (`unknown`, `needs gas measurement`, `needs product owner`).
6. Never enable or recommend `via_ir` as a solution.
7. Separate **struct/gas** findings from **audit correctness** findings (different IDs / categories).

### 4.4 Parallelism rules

| Rule | Detail |
|------|--------|
| Min areas | ≥4 for a full monorepo pass; can be 1–2 for a pilot |
| Max concurrent subagents | Prefer 4–8; avoid thrashing the same large files |
| Isolation | Each agent writes only its area report path |
| Time box | Orchestrator may set a wall-clock budget; unfinished areas → `PARTIAL` with remaining inventory |
| Fail soft | One area failure must not drop others; aggregate marks that area `FAILED` with error |

### 4.5 Recommended agent tooling (implementation hint)

Orchestrators implementing this PRD in Grok/Claude/etc. should:

- Use **explore / general-purpose** subagents with **read-only** capability for the review pass.
- Partition with path globs, not “vibes.”
- Use ripgrep for `struct ` definitions and usages; sample largest Targets first (known stack-pressure files).
- Optionally run `forge build` once at the end to confirm baseline still green (not required per subagent).

---

## 5. Default area partition

Orchestrator may refine, but **default full pass** uses these non-overlapping areas:

| Area ID | Paths (primary) | Focus notes |
|---------|-----------------|-------------|
| `A-detf-core` | `contracts/vaults/detf/common/**` | Shared bond NFT, factories, threshold, compound helpers |
| `A-detf-balancer` | `contracts/vaults/detf/protocols/dexes/balancer/**` | Multi-vault, mixed buffer, composed stable, single SE |
| `A-detf-univ4` | `contracts/vaults/detf/protocols/dexes/uniswap/**` | Orbital / Uni V4 DETF families; stack-hot |
| `A-se-vaults` | `contracts/vaults/**` excluding `detf/**` | Standard Exchange + strategy vaults, slipstream, const-prod, basic |
| `A-hooks-v4` | `contracts/hooks/**` | Uni V4 hook packages; known stack-too-deep history |
| `A-routers` | `contracts/routers/**` | Coordinators, Permit2 witness, multi-hop params |
| `A-manager-fee-oracle` | `contracts/manager/**`, `contracts/fee/**`, `contracts/oracles/**` | Manager DFPkg, fee collector, vault fee oracle |
| `A-interfaces-types` | `contracts/interfaces/**` + interface-local structs in packages | Cross-cutting API types, `PkgInit`/`PkgArgs`, fee types |
| `A-protocols` | `contracts/protocols/**` | **Full pass (locked):** protocol ports/wrappers under IndexedEx contracts (staking, lending adapters, etc.) |
| `A-research` | `research/**` | **Full inventory (locked):** scenario/scripts structs that mirror production; prioritize duplicate detection vs `contracts/**` |

**Out of default scope:**

- `lib/**` (Crane / pure vendor) except when an area agent must cite an imported type
- `test/**`, `script/**` (deploy scripts — not research), `frontend/**`
- Generated / broadcast artifacts

**Research-area rules:** inventory + duplication vs production is mandatory; audit Blocker/High findings on research-only code are **optional** (mark `research-only`) unless the script is a normative mainnet rehearsal that should match production invariants.

**Pilot mode (recommended first run):** `A-hooks-v4` + `A-detf-univ4` + `A-detf-core` only — highest stack-relief density.

---

## 6. Workstreams (required analysis)

Every area agent completes these workstreams.

### 6.1 Struct inventory

For each `struct` definition in scope:

| Column | Content |
|--------|---------|
| Name | Fully qualified (file + struct) |
| Kind | `stack-relief` / `execution-context` / `api` / `storage` / `result` / `other` |
| Visibility surface | internal-only / library / interface / public ABI |
| Approx members | count + types summary |
| Write sites | where constructed/filled |
| Read sites | helpers / external that consume it |
| Lifetime | single function / call chain / storage permanent |
| Notes | e.g. “duplicated in ComposedStable and MultiVault” |

Deliverable: inventory table (can be large; keep machine-sortable markdown).

### 6.2 Redundant member analysis

Flag members that are:

1. **Never read** after write on any path.
2. **Always equal** to another member (duplicate).
3. **Always zero/default** on hot paths.
4. **Only used to thread stack** where a helper return or tighter scope would suffice.
5. **Copied identically** into a child struct (collapse parent+child).

Each flag → finding with evidence.

### 6.3 Collapse / consolidation opportunities

Propose consolidations in one of these classes:

| Class | Description |
|-------|-------------|
| `C1` | Merge sibling param structs into one API or context type |
| `C2` | Replace nested struct graph with flat execution context |
| `C3` | Share one library struct across families (delete copies) |
| `C4` | Split mega-struct that loads unused storage (gas **reduction by shrink**, not merge) |
| `C5` | Remove struct entirely; use helper + fewer locals / block scope |
| `C6` | Storage packing-only change (no semantic merge) |

For each proposal:

- Before/after sketch (member list, not full code).
- Affected functions.
- Stack-safety risk (`low`/`med`/`high`) and mitigation.
- Gas classification (§3.3).
- ABI/storage break? Yes/No.
- Suggested implementation order relative to tests.

### 6.4 Code quality / external audit readiness

Review the **same files** for audit prep (not a full adversarial rewrite). Minimum checklist:

| Category | Checks |
|----------|--------|
| **Access control** | Auth on state-changing selectors; init/postDeploy trust; operator vs owner |
| **Reentrancy** | External calls before state settle; CEI; diamond reentrancy locks if used |
| **Storage** | Slot names; layout append-only discipline; no packing footguns without comment |
| **Tokens** | Approvals, Permit2, fee-on-transfer assumptions, pull vs push |
| **Economic** | Fee/seigniorage split, rounding direction, preview ≤/≥ actual rules |
| **Invariants** | Documented vs enforced; missing tests called out |
| **Errors/events** | Custom errors on money paths; events for critical state |
| **NatSpec** | Public/external money paths documented; `@custom:signature` where Crane expects |
| **Dead code** | Unreachable branches, unused internal helpers, commented product paths |
| **Naming** | DETF role names; avoid brand tokens in production APIs |
| **Deploy** | No `new` facets/packages; registry path respected |
| **Test gaps** | Missing negative tests, fork vs hermetic holes for the area |

Severity rubric **must** match `docs/archive/CODE_REVIEW_PLAN.md` (Blocker / High / Medium / Low / Nit).

### 6.5 Explicit “do not collapse” list

Agents **must** list structs that should **remain separate**, with reason (stack safety, ABI stability, storage, audit clarity). This prevents naive “merge everything” implementations.

---

## 7. Deliverable formats

### 7.1 Per-area report path

```text
docs/reviews/YYYY-MM-DD_struct-audit_<area-id>.md
```

Example: `docs/reviews/2026-08-08_struct-audit_A-hooks-v4.md`

### 7.2 Per-area report schema (mandatory sections)

```markdown
# Struct + Audit Readiness Review — <Area ID>

- **Date:**
- **Agent/role:** area subagent
- **Scope paths:**
- **Out of scope notes:**
- **Status:** COMPLETE | PARTIAL | FAILED
- **Commands / tools used:**

## 1. Executive summary
- Top 5 opportunities (bullet list)
- Top 5 audit concerns
- Estimated struct count (defined / recommended remove / recommended merge)

## 2. Struct inventory
(table)

## 3. Redundant members
(findings table)

## 4. Collapse / consolidation proposals
(findings table + sketches)

## 5. Do-not-collapse list
(table)

## 6. Gas notes
(hot paths in this area; measurement gaps)

## 7. Audit readiness findings
(findings table — correctness/security/quality)

## 8. Suggested implementation order (for later plan)
(ordered list; no code changes in this pass)

## 9. Open questions
```

### 7.3 Finding row schema

Use one table shape for struct/gas and one for audit (or one table with `Category`).

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-… | | `struct-redundant` / `struct-collapse` / `struct-split` / `gas` | | | | | | | | | Yes/No |
| A-… | | `access` / `reentrancy` / `economic` / `storage` / `test-gap` / … | | | | | n/a | n/a | | | Yes/No |

IDs: `S-<area>-<nnn>` for struct/gas, `A-<area>-<nnn>` for audit.

### 7.4 Aggregate report path

```text
docs/reviews/YYYY-MM-DD_struct-audit_AGGREGATE.md
```

### 7.5 Aggregate report schema (orchestrator)

Mandatory sections:

1. **Program metadata** — date, areas run, partial/failed areas, PRD version/status.
2. **Global inventory stats** — struct counts by kind; top files by struct density.
3. **Cross-area duplicates** — identical or near-identical structs across families.
4. **Priority backlog (Top 25)** — composite-ranked (§8).
5. **Merged findings** — Blockers/High first; deduped.
6. **Conflicts & resolutions** — where area agents disagreed.
7. **Gas measurement shortlist** — candidates for **hermetic** `forge snapshot` / gas-report in implementation phase; note any path that requires fork.
8. **Audit readiness scorecard** — per area: `READY` / `NEEDS_WORK` / `BLOCKED` with one-paragraph rationale.
9. **Recommended follow-on artifacts** — implementation plan path(s), optional adversarial gaps pointing to `indexedex-adversarial-testing`.
10. **Out of scope debt** — explicitly deferred.

### 7.6 Optional machine-readable appendix

Orchestrator may also emit:

```text
docs/reviews/YYYY-MM-DD_struct-audit_inventory.json
```

Suggested minimal JSON object list: `{ "area", "file", "struct", "kind", "members", "proposal" }`. Not required for v1 acceptance.

---

## 8. Prioritization score (normative)

Orchestrator ranks backlog items with:

```text
score = 3*gas_hot_path_weight
      + 2*audit_severity_weight
      + 2*duplication_weight
      + 1*clarity_weight
      - 3*storage_or_abi_break_penalty
      - 2*stack_risk_penalty
```

| Factor | Weight guide |
|--------|----------------|
| `gas_hot_path_weight` | 0 none, 1 cold, 2 warm, 3 mint/burn/swap/bond/claim hot path + positive gas |
| `audit_severity_weight` | Nit 0, Low 1, Medium 2, High 3, Blocker 4 |
| `duplication_weight` | 0 unique, 1 twice, 2 thrice, 3 ≥4 copies / families |
| `clarity_weight` | 0–2 auditor navigation impact |
| `storage_or_abi_break_penalty` | 0 none; **1** storage change under pre-launch (allowed, still costs clarity/test load); **2** public ABI break with known external integrators (rare pre-launch) |
| `stack_risk_penalty` | 0 low, 1 med, 2 high (likely reintroduce stack-too-deep) |

Under locked pre-launch posture (§14 L4), do **not** auto-kill storage packing items — score them; prefer high-ROI packing on hot paths when tests can cover layout.

Document scores on Top 25 rows. Ties broken by: Blocker/High audit first, then hot-path gas, then shared-library wins (including research↔production duplicates that collapse to one production type).

---

## 9. Orchestrator workflow (step-by-step)

1. **Confirm mode** with user if ambiguous: `pilot` (3 areas) vs `full` (all default areas).
2. **Freeze methodology** — this PRD + severity rubric + gas model.
3. **Partition** — write partition table into the aggregate draft header.
4. **Spawn** area subagents in parallel with:
   - Absolute path allowlist
   - Output file path
   - Copy of §§2–3, 6–7 (or link to this PRD)
   - Instruction: read-only; no `via_ir`; DETF naming
5. **Collect** area reports; mark missing as `FAILED`/`PARTIAL`.
6. **Cross-cut pass** (orchestrator or specialist):
   - Duplicate struct detection across areas
   - Shared `HarvestParams`-style clones
   - Interface vs implementation drift for `PkgInit`/`PkgArgs`
7. **Score & rank** Top 25.
8. **Write aggregate** report.
9. **Stop** — present summary to user; **do not** start refactors unless asked.
10. **Handoff** — if user requests implementation, open a separate implementation PRD/plan that references Top 25 IDs and requires:
    - default `forge build` green
    - relevant `forge test` green
    - before/after gas snapshots for hot-path items

---

## 10. Acceptance criteria (this review program)

The program is **done** when:

| # | Criterion |
|---|-----------|
| AC1 | Every scheduled area has `COMPLETE` or justified `PARTIAL`/`FAILED` report on disk |
| AC2 | Aggregate report exists with Top 25 backlog + scorecard |
| AC3 | Every collapse proposal includes gas dir, stack risk, ABI/storage break, confidence |
| AC4 | Every Blocker/High audit finding has path:line evidence and a verification idea |
| AC5 | Do-not-collapse lists exist for each area (can be empty only if zero structs) |
| AC6 | No recommendation requires `via_ir` |
| AC7 | No product code was changed **or** any drive-by change is explicitly listed and reverted/isolated (prefer zero) |
| AC8 | Cross-area duplicates section lists shared struct opportunities across ≥2 areas (or states none found) |

---

## 11. Implementation phase gates (out of band, but required to reference)

When a future agent implements recommendations from this program:

1. One PR (or stacked PR) per coherent collapse theme — not a monorepo-wide drive-by.
2. **Compile gate:** `forge build` (default profile) green.
3. **Test gate:** production-first tests for touched packages; no new SUT mocks.
4. **Gas gate:** for any claim marked hot-path `positive`, attach **hermetic** `forge snapshot` or gas-report delta; add fork evidence only if hermetic cannot exercise the path.
5. **Storage gate (pre-launch):** storage packing/layout edits are **allowed** but must be explicit in the PR, covered by tests, and labeled with residual migration risk if any external deploy might exist. No silent layout edits.
6. **ABI gate:** interface struct changes require explicit changelog note for integrators (even pre-launch).
7. Prefer landing **shared library types** before family-local deletions to avoid thrash.

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Collapse reintroduces stack-too-deep | Stack risk field + prefer helper split; compile gate |
| False “gas win” | Confidence + measurement shortlist; no fake % |
| Touching storage packing carelessly pre-launch | Explicit PR notes + tests + residual migration label; storage specialist for large layout rewrites |
| Review noise floods audit signal | Separate S-* vs A-* IDs; Top 25 cap; research audit optional |
| Overlapping agents contradict | Conflict section; orchestrator decides |
| Scope explosion into Crane/`lib` | Path allowlists; `contracts/protocols/**` and `research/**` in-scope; `lib/**` cite-only |
| Research volume dilutes product findings | `A-research` focuses on inventory + cross-dupe; score research-only gas lower unless shared with production |
| Stale reports | Date-stamp files; re-run pilot areas after large DETF merges |

---

## 13. Example (non-normative illustration)

**Bad (flag):**

```text
MintParams → MintState → MintCache → MintScratch → MintResult
each copies amountIn, rateAsset, vaultShare
```

**Recommend (C2):**

```text
struct MintContext {
  // calldata-origin fields
  // loaded pool/vault state
  // intermediates
  // outputs
}
// external mint(...) { MintContext memory ctx; _load(ctx); _split(ctx); _settle(ctx); }
```

**Only if** stack-safe under default solc and gas notes show fewer copies on the mint hot path.

---

## 14. Locked decisions (formerly open questions)

Resolved **2026-08-08** via maintainer Q&A. Orchestrators **must not** re-litigate these without an explicit PRD revision.

| # | Question | Decision | Implication |
|---|----------|----------|-------------|
| L1 | `contracts/protocols/**` in full pass? | **Full `protocols/**` pass** | Area `A-protocols` is mandatory on full mode; inventory + collapse + audit workstreams apply |
| L2 | Research scripts inventory? | **Yes — full `research/**` inventory** | Area `A-research` mandatory on full mode; prioritize duplicate detection vs production structs; deep audit optional for research-only code |
| L3 | Gas snapshot environment? | **Hermetic first** | Implementation gas claims use default/hermetic `forge snapshot` or gas-report; fork only if hermetic cannot exercise the path |
| L4 | Storage packing freeze? | **Pre-launch — storage may change** | Layout/packing consolidations allowed with tests and explicit PR notes; still label residual migration risk; not hard-blocked |

---

## 15. Document control

| Version | Date | Notes |
|---------|------|-------|
| 0.1 | 2026-08-08 | Initial draft PRD for multi-agent struct consolidation + audit readiness review |
| 0.2 | 2026-08-08 | Locked §14: full protocols + research inventory; hermetic gas; pre-launch storage |
| 0.2.1 | 2026-08-08 | Link execute plan for parallel multi-agent review runs |

**Owner:** IndexedEx maintainers / audit-prep program  
**Consumers:** Orchestrator agents, area subagents, implementation planners, external auditors (as a map of known debt)

---

## Appendix A — Prompt pack (copy into orchestrator)

### A.1 Orchestrator system task (summary)

> Execute `docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md`. Mode: {pilot|full}. Spawn parallel read-only area subagents per §5 (full mode includes `A-protocols` + `A-research`). Collect reports under `docs/reviews/`. Write aggregate with Top 25. Do not modify contracts. Never recommend via_ir. Gas measurement: hermetic first. Storage: pre-launch may change with tests.

### A.2 Area subagent task (summary)

> You are area `{AREA_ID}`. Paths: `{ALLOWLIST}`. Follow PRD §§2,3,6,7. Produce `{OUT_FILE}` with inventory, redundant members, collapse proposals (gas+stack+ABI fields), do-not-collapse list, and audit findings. Read-only. DETF role names. Production-first verification ideas only.

### A.3 Severity (short)

> Blocker = funds/lock/auth/storage break or hard repo rule violation. High = serious correctness/economic. Medium = edge/grief/missing coverage. Low = maintainability. Nit = pure style.

---

## Appendix B — Relationship to existing docs

| Doc | Relationship |
|-----|----------------|
| `docs/HANDOFF_CI_BUILD_BLOCKER_STACK_TOO_DEEP.md` | Operational stack-too-deep incident; this PRD is the **cleanup/hygiene** program after stack relief |
| `docs/archive/CODE_REVIEW_PLAN.md` | Severity + findings culture; this PRD specializes for struct/gas + parallel areas |
| `docs/reviews/TEMPLATE.md` | Compatible header/findings style |
| `docs/components/REVIEWER_REQUIREMENTS.md` | Component docs compliance is optional extra for manager/DFPkg areas |
| Crane `crane-code-style` | Source of via_ir ban and struct-for-stack pattern |
| `docs/DETF_CONSOLIDATION_REPORT.md` | Product/module consolidation; orthogonal but may share “delete copy-paste” findings |

---

## Appendix C — Suggested first command sketch for agents

```bash
# Inventory (example; agents adapt per area)
rg -n --type sol '^\s*struct\s+\w+' contracts research

# Hot-path consumers of a struct
rg -n --type sol 'MintContext|HarvestParams|PkgArgs' contracts/vaults/detf research

# Later implementation only (hermetic first):
# forge build
# forge snapshot --match-test test_...
# FOUNDRY_PROFILE=fork forge test --gas-report --match-test test_...   # only if hermetic cannot exercise path
```
