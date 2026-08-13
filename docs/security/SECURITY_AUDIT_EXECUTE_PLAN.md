# Execute Plan — IndexedEx Security Audit (Stage 1)

> **For agentic workers:** This is a **Stage 1 review** plan. Orchestrator launches parallel product-area and specialist subagents, collects reports, runs Critical runtime proofs where required, then writes the aggregate audit report + work-package backlog.  
> **Do not** implement production fixes or permanent test suites. **Do not** start Stage 2 PRD authorship or Stage 3 worktrees.  
> **May** write under `docs/security/audit/**` only (reports + optional `repro/` evidence).

**Goal:** Produce a decision-grade security audit report and a ranked work-package backlog so a later agent can write `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` and spawn `sec_fix_*` implementers **in parallel**.

**Normative law:** [`SECURITY_AUDIT_PRD.md`](./SECURITY_AUDIT_PRD.md) (especially §§2–8, **§15 pilot**, **§19 locks L-SEC-1…14**).

**Primary skills / bar:**

| Skill / doc | Role |
|-------------|------|
| `crane-adversarial-testing` | Catalog **A–K + A0/L/M/N/O + E6/F5**, anti-theater, ship gate |
| `…/references/implementation-test-dod.md` | Implementor DoD → WP acceptance language |
| `indexedex-adversarial-testing` | DETF / SE / bond-claim mapping |
| `crane-testing` / `indexedex-testing` | LR-7, production-first, registry deploy |
| `ethskills-audit` | Domain routing + specialist hunt lists |
| `ethskills-security` | Defensive pattern hunt |
| `ethskills-crops` | Trust / admin / exit / unowned DETF |
| `defi-incident-patterns` | Theme → catalog (reference only) |
| `sharp-edges` | PkgArgs / flag footguns |
| `spec-to-code-compliance` | Family PRD / `docs/detf/*` vs code |
| `differential-review` / `adversarial-modeler` | Blast radius + exploit steps on Critical/High |
| `Claude.md` / `INDEXEDEX_AGENT_LAW.md` | Deploy + DETF non-negotiables |

**Repo root:** IndexedEx workspace (`lib/indexedex`).

**Downstream (not this plan):**

| Stage | Deliverable |
|-------|-------------|
| 2 | `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` via [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) |
| 3 | Worktrees/branches `sec_fix_*` + parallel CODE/TEST agents |

---

## 0. Run parameters (orchestrator sets once)

| Parameter | How to set | Default / locked |
|-----------|------------|------------------|
| `MODE` | `pilot` then `full` after pilot exit | **`pilot` first** (L-SEC-1) |
| `RUN_DATE` | ISO date of this run | today `YYYY-MM-DD` |
| `REPORT_ROOT` | Output tree | `docs/security/audit` |
| `PRD` | Law file | `docs/security/SECURITY_AUDIT_PRD.md` |
| `ALCHEMY` | Env for fork proof | `ALCHEMY_KEY`; `foundry.toml` `*_alchemy` (L-SEC-6) |
| `FORK_PROFILE` | Foundry profile | `FOUNDRY_PROFILE=fork` for fork paths |
| `MAX_PARALLEL` | Concurrent children | **5** pilot (3 areas + 2 specialists); **4–8** full |
| `GIT_SHA` | `git rev-parse --short HEAD` | record in every report |

**Output layout (fixed):**

```text
docs/security/audit/
  00_SCOPE_PARTITION.md
  01_METHODOLOGY_NOTES.md
  areas/
  specialists/
  repro/
  PILOT_EXIT.md
  AGGREGATE.md
  WORK_PACKAGE_BACKLOG.md
```

Do **not** overwrite a prior complete full-pass aggregate without user OK; use `docs/security/audit/archive/{RUN_DATE}/`.

---

## 1. Global constraints (paste into every subagent)

```text
HARD RULES (SECURITY AUDIT STAGE 1):
1. No committed edits to production *.sol or permanent test suites under test/**.
   Allowed writes: docs/security/audit/** only (area/specialist report + optional repro/).
2. Never recommend via_ir. Never count MockStandardExchange / vm.mockCall-on-SUT as proof a vuln is absent.
3. DETF role names only: rateAsset, pairToken, underlyingVault, vaultShare, detfToken,
   reservePool/reserveBpt, rebasingClaimToken.
4. Deploy bar: facets CREATE3/FactoryService; vault/DETF DFPkgs via indexedexManager registry path.
5. Catalog SoT: Crane A–K + A0/L/M/N/O + E6/F5 (PRD §2.2). EVM-audit domains are HUNT LISTS, not a second ID space.
6. Pattern hunt mandatory: PAT-I-ABS, PAT-J-OMIT, PAT-J-CTRL, PAT-K-DONATE, PAT-E6-REFUND,
   PAT-F5-RESIZE, PAT-A0-EMPTY, PAT-M-CALL, PAT-N-TOCTOU, PAT-O-SIG, PAT-L-SKIM,
   PAT-CROPS-ADMIN, PAT-SPEC-DRIFT, PAT-SHARP-FLAG, PAT-SLOT, PAT-THEATER-PRE,
   PAT-THEATER-FACET, PAT-MOCK (PRD §2.4).
7. Finding class: CODE | TEST | THEATER | DEFER | NEEDS_OWNER | ACCEPTED_RISK | OWNED_ELSEWHERE.
   Severity: Critical|High|Medium|Low|Info. Do not use coverage-audit "Blocker".
8. Finding IDs: SEC-<AREA_SHORT>-NNN (e.g. SEC-COMMON-001, SEC-DETF-MV-003, SEC-SPEC-012).
9. Critical + CODE requires RUNTIME PROOF (PRD §3.8 / L-SEC-3): command + outcome.
   If impossible: max High + RUNTIME_UNPROVEN (unless static is overwhelming — still label).
10. Repro evidence may go under docs/security/audit/repro/<FINDING_ID>/ (L-SEC-7).
    Never commit ALCHEMY_KEY, secrets, or a working mainnet exploit script.
11. Fork RPC: prefer foundry.toml *_alchemy endpoints (L-SEC-6).
12. J bar: Target API ⊆ facetFuncs ⊆ facetCuts ⊆ loupe ⊆ call on PROXY (not facet impl).
13. I bar: happy-path pretransferred with real transfer is NOT coverage for I1–I3.
    Credit law: claimed ≤ delta → credit claimed; claimed > delta → shared short revert (L-GAPS-9).
14. Ship-blocking products: ALL money vaults/DETFs/SE/hooks/fund routers (L-SEC-2).
15. Fork-first products: missing fork P0 = equal severity to hermetic (L-SEC-5).
16. Do NOT compete with coverage-audit (L-SEC-4). If the same production touch-set is already
    a TCA-* / WP-I-* Blocker/High, classify OWNED_ELSEWHERE and link IDs — do not invent a
    competing sec_fix_* WP.
17. Pass = exploit blocked (or ACCEPTED_RISK with invariants). Never assertGt(attackerProfit, 0) as DoD.
18. Incident corpus (lib/DeFiHackLabs) is REFERENCE ONLY. Do not add remappings.
19. Stay in path allowlist. Out-of-area: reference only.
20. Write report ONLY to OUT_FILE (or return full markdown for orchestrator to write).
21. For each Critical/High: attack scenario, attacker model (EXT/CAP/HOS/INT/ADM/CFG),
    CODE sketch if CODE, test name + setup + pass + anti-theater, suggested WP-ID.
22. Do not implement fixes. Do not write SECURITY_AUDIT_REMEDIATION_PRD.md.
    Do not create sec_fix_* or gap_cover_* worktrees.
23. DETF instances are unowned/immutable after deploy (L-SEC-11). Leftover diamondCut/owner
    on a live DETF is at least High unless product law says otherwise.
24. Forge patience: 20–40+ min compile with no output is normal. Do not kill forge/solc.
```

---

## 2. Mode definitions

### 2.1 Pilot (`MODE=pilot`) — **mandatory first** (L-SEC-1)

| ID | Production allowlist | Test allowlist (primary) | OUT_FILE | Focus |
|----|----------------------|--------------------------|----------|--------|
| `A-commons-pull` | `contracts/vaults/basic/**`; shared pull/credit helpers; `ISecurePullErrors`; DETF `_pullToken` clones as **reference blast** only | `test/**` touching pretransfer / secure pull; coverage-audit `areas/T-basic-protocol-commons.md` as seed | `{REPORT_ROOT}/areas/A-commons-pull.md` | PAT-I-ABS; I1–I3; K; L-GAPS-9 credit law; Wave-0 CODE WP |
| `A-detf-multi-vault` | Multi-vault-weighted DETF under `contracts/vaults/detf/**` | `test/**/multi-vault-weighted/**` incl. `adversarial/` | `{REPORT_ROOT}/areas/A-detf-multi-vault.md` | Gold DETF; A0/D/G/I/J; claim; leftover admin |
| `A-se-amm-v2` | Aerodrome + Camelot + Uni V2 SE packages under `contracts/` | Matching SE TestBases + tests | `{REPORT_ROOT}/areas/A-se-amm-v2.md` | Routes, pretransfer, L/B, E6 refunds |
| `S-sharp-edges` | PkgArgs / `pretransferred` / Permit2 / minOut defaults across pilot products | n/a (reads production + area drafts) | `{REPORT_ROOT}/specialists/S-sharp-edges.md` | Insecure-by-default flags |
| `S-crops-trust` | Manager/fee/registry if reachable from pilot; DETF unowned posture | n/a | `{REPORT_ROOT}/specialists/S-crops-trust.md` | Walkaway; leftover owner; fee authority |

**Parallelism:** spawn **3** area subagents at once; spawn **2** specialists in the same wave (they may start from allowlists and refine after areas return).

**Pilot-only runtime (orchestrator or commons agent):** at least one PAT-I-ABS / Critical runtime attempt (L-SEC-3). May re-check `docs/testing/coverage-audit/repro/TCA-COMMON-001/` at **current SHA**.

### 2.2 Full (`MODE=full`) — only after §6 pilot exit

| ID | Production allowlist | OUT_FILE |
|----|----------------------|----------|
| `A-detf-single-se` | Single SE DETF (Balancer V3 + Uni V4 CP) | `…/areas/A-detf-single-se.md` |
| `A-detf-composed-stable` | Composed stable + mixed buffer | `…/areas/A-detf-composed-stable.md` |
| `A-detf-dual-liquidity` | DualLiquidity cross-version (fork-first) | `…/areas/A-detf-dual-liquidity.md` |
| `A-se-v3-v4-lending` | Uni V3/V4 SE, Aave, Morpho SE, LST SE | `…/areas/A-se-v3-v4-lending.md` |
| `A-hooks-v4` | `contracts/hooks/**` | `…/areas/A-hooks-v4.md` |
| `A-manager-fee-registry` | manager, fee, oracles, vault registry | `…/areas/A-manager-fee-registry.md` |
| `A-routers-permit2` | routers + Permit2 | `…/areas/A-routers-permit2.md` |

**Specialists (full):** `S-spec-detf`, `S-token-weird`, `S-amm-oracle-flash`, `S-diamond-proxy`, `S-signatures`, `S-incidents`, `S-evm-general`, then `S-adv-modeler` per Critical/High CODE.

**Re-run pilot areas in full?** Prefer **reuse** pilot reports; re-open only if full-pass inventory finds missing products. Aggregate must still **include** pilot products.

**Parallelism:** waves of **4–8**:

| Wave | Agents |
|------|--------|
| F1 | `A-detf-single-se`, `A-detf-composed-stable`, `A-detf-dual-liquidity` |
| F2 | `A-se-v3-v4-lending`, `A-hooks-v4`, `A-manager-fee-registry`, `A-routers-permit2` |
| F3 | remaining specialists |
| F4 | adversarial-modeler per Critical/High CODE |

---

## 3. Orchestrator checklist

### Task O0 — Bootstrap

- [ ] **Step 1:** Set `MODE=pilot`, `RUN_DATE`, `GIT_SHA`.
- [ ] **Step 2:** Read PRD fully, especially §§2, 3.8, 7–8, 13, 15, **19**.
- [ ] **Step 3:** Skim skills in the header table (catalog A0/L/M/N/O + DoD + evm-audit routing + CROPS).
- [ ] **Step 4:** Skim `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` enough to recognize OWNED_ELSEWHERE touch-sets.
- [ ] **Step 5:** Confirm `ALCHEMY_KEY` if any fork proof is likely; note absence in methodology.
- [ ] **Step 6:** Create dirs:

```bash
mkdir -p docs/security/audit/areas docs/security/audit/specialists docs/security/audit/repro
```

- [ ] **Step 7:** Write `docs/security/audit/00_SCOPE_PARTITION.md` from §2.1 (pilot) + excluded paths (`frontend/**`, `broadcast/**`, `out/**`, `lib/**` except Crane patterns).

### Task O1 — Cheap pre-inventory (non-blocking)

```bash
# Trust-flag / surface / refund / admin / signature signals
rg -n --type sol 'pretransferred' contracts --glob '!lib/**' | head -80
rg -n --type sol 'function facetFuncs' contracts --glob '!lib/**' | head -40
rg -n --type sol 'diamondCut|onlyOwner|onlyOperator' contracts --glob '!lib/**' | head -40
rg -n --type sol 'balanceOf\(address\(this\)\)|address\(this\)\.balance' contracts --glob '!lib/**' | head -40
rg -n --type sol 'ecrecover|permitWitness|permit\(' contracts --glob '!lib/**' | head -40
rg -n --type sol 'delegatecall|\.call\{|\.call\(' contracts --glob '!lib/**' | head -40
rg -n --type sol 'function test_I[0-9]_|function test_A0_|function test_E6_|function test_L[0-9]_' test | head -40
```

Record a short command summary in `01_METHODOLOGY_NOTES.md`.

**Do not** run a full monorepo `forge test` during inventory. Targeted `--list` is OK if compile is already warm.

### Task O2 — Spawn pilot agents (parallel)

- [ ] **Step 1:** Spawn **3** area agents + **2** specialists with:
  - Prefer `explore` (read-only) **or** `general-purpose` with writes only under `docs/security/audit/**`
  - Specialists: `sharp-edges-analyzer` / `general-purpose` for `S-sharp-edges`; `general-purpose` for `S-crops-trust` (load `ethskills-crops`)
  - `description`: `sec-audit {ID}`
  - `prompt`: **§4** templates with substitutions
- [ ] **Step 2:** Launch in **parallel**, not serial.
- [ ] **Step 3:** On completion, validate each `OUT_FILE` against §5 QA. If body only in chat, orchestrator writes the file.

### Task O3 — Pilot runtime proof (Critical candidates)

- [ ] **Step 1:** From commons + SE pilot findings, pick top PAT-I-ABS / free-mint / E6 candidate.
- [ ] **Step 2:** Obtain runtime proof per PRD §3.8 (hermetic preferred; fork uses `*_alchemy`).
- [ ] **Step 3:** Update finding status: `confirmed` | `not reproducible` | `BUILD_BLOCKED` | `RUNTIME_UNPROVEN`.
- [ ] **Step 4:** If confirmed Critical CODE, ensure WP stub + not OWNED_ELSEWHERE (or link TCA and skip new tree).

### Task O4 — Pilot aggregate + exit gate

- [ ] **Step 1:** Write **thin** `AGGREGATE.md` (pilot products) + `WORK_PACKAGE_BACKLOG.md` (≥5 real WPs if gaps exist; include any Critical; include OWNED_ELSEWHERE table even if empty).
- [ ] **Step 2:** Write `PILOT_EXIT.md` (copy §6).
- [ ] **Step 3:** If exit fails, fix schema/report issues and re-run failed agents only.
- [ ] **Step 4:** Present user: residual-risk scores, top WPs, OWNED_ELSEWHERE, path to files. **Ask to proceed to full** unless user pre-authorized full after pilot.

### Task O5 — Full pass spawn (after pilot exit)

- [ ] **Step 1:** Update `00_SCOPE_PARTITION.md` with full tables.
- [ ] **Step 2:** Spawn F1 then F2 (fail-soft).
- [ ] **Step 3:** Spawn F3 specialists.
- [ ] **Step 4:** Collect COMPLETE / PARTIAL / FAILED.

### Task O6 — Adversarial modeler (F4)

- [ ] For each remaining **Critical/High CODE** that is **not** OWNED_ELSEWHERE:
  - Spawn `differential-review:adversarial-modeler` (or general-purpose with that skill).
  - Prompt: §4.3. Output may append to the finding or write `specialists/S-adv-modeler-<FINDING_ID>.md`.
  - Require: numbered attack steps, blast radius, exploitability.

### Task O7 — Full aggregate + backlog

- [ ] **Step 1:** Dedupe findings; resolve conflicts; global catalog + domain + PAT matrices; CROPS record.
- [ ] **Step 2:** Diff vs `docs/testing/coverage-audit/AGGREGATE.md` (Still vuln / Test-only / Closed / New / Stale).
- [ ] **Step 3:** Rank WPs (PRD §9); full §8 fields for all Critical/High; finding→WP index; parallelism graph.
- [ ] **Step 4:** Wave sketch for Stage 2 (Wave 0 serial; product parallel; OWNED_ELSEWHERE skipped).
- [ ] **Step 5:** Write final `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md`.
- [ ] **Step 6:** Verify Stage 1 DoD (PRD §12).
- [ ] **Step 7:** **Stop.** Hand off to Stage 2 via `PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`. Do **not** open `sec_fix_*` worktrees. Do **not** write the remediation PRD in this run unless the user explicitly asks.

---

## 4. Prompt templates

### 4.1 Product-area agent

Substitute: `{AREA_ID}`, `{PROD_ALLOWLIST}`, `{TEST_ALLOWLIST}`, `{OUT_FILE}`, `{RUN_DATE}`, `{GIT_SHA}`, `{PRD_PATH}`, `{MODE}`, `{FOCUS}`, `{REPORT_ROOT}`.

```text
You are a Stage 1 product-area subagent for the IndexedEx Security Audit.

## Identity
- Area ID: {AREA_ID}
- Mode: {MODE}
- Run date: {RUN_DATE}
- Git SHA: {GIT_SHA}
- Production path allowlist (deep review ONLY):
  {PROD_ALLOWLIST}
- Test path allowlist (primary):
  {TEST_ALLOWLIST}
- Output file: {OUT_FILE}
- Focus: {FOCUS}
- Normative PRD: {PRD_PATH}
  Read: §2 security bar, §2.4 patterns, §3.8 runtime Criticals, §5 inventory,
  §6 workstreams, §7.2–7.3 report/finding schema, §8 WP stubs, §19 locks.
- Skills (read in order):
  1. lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md
     (+ references/implementation-test-dod.md headings)
  2. .claude/skills/indexedex-adversarial-testing/SKILL.md (or .grok mirror)
  3. .claude/skills/indexedex-testing/SKILL.md
  4. ethskills-security SKILL.md
  5. defi-incident-patterns SKILL.md (theme→catalog only)
- Coverage-audit seed (re-verify, do not blindly copy):
  docs/testing/coverage-audit/areas/* matching this product
  docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md (OWNED_ELSEWHERE)

## Hard rules
{PASTE §1 GLOBAL CONSTRAINTS}

## Workstreams (all required)
WS1 Product inventory
WS2 Threat model (PRD §5.2 table per product)
WS3 Catalog matrix A–O + E6/F5 as F/P/G/N/A/VULN
WS4 Pattern hunt PAT-*
WS5 Domain notes (which evm-audit domains you actually walked)
WS6 Theater / false confidence
WS7 Coverage-audit linkage (TCA/WP or none)
WS8 Findings with FULL PRD §7.3 fields for every Critical/High
WS9 WP stubs with FULL PRD §8 fields for every Critical/High
WS10 Open questions (NEEDS_OWNER, BUILD_BLOCKED, RUNTIME_UNPROVEN, ACCEPTED_RISK)

## Method hints
1. rg allowlists for pretransferred, facetFuncs, diamondCut, onlyOwner, balanceOf(this),
   ecrecover, permit, delegatecall, .call(, initialize(, lastTotal, minOut.
2. For each Facet: Target external/public product API vs facetFuncs (J1).
3. I1–I3: tests that claim pretransferred without transfer while vault holds inventory.
4. Hunt refund/reclaim paths for PAT-E6-REFUND (balance − floor).
5. Hunt empty/pre-live inventory for PAT-A0-EMPTY.
6. If you believe Critical CODE: attempt runtime proof if feasible in-area; else
   label needs orchestrator runtime and severity High max + RUNTIME_UNPROVEN.
7. Repro logs: {REPORT_ROOT}/repro/<FINDING_ID>/ — preferred for Criticals.
8. If the same files are already WP-I-* in coverage-audit backlog, mark OWNED_ELSEWHERE.

## Output
Write complete markdown to {OUT_FILE} matching PRD §7.2 sections 1–11.
Finding IDs: SEC-… unique within area.
Do not edit production or test/** suites.
When done, return: status COMPLETE|PARTIAL|FAILED, path to OUT_FILE,
Critical/High counts, OWNED_ELSEWHERE count, top 5 WP-IDs.
```

### 4.2 Pilot `{FOCUS}` strings

| ID | `{FOCUS}` |
|----|-----------|
| `A-commons-pull` | PAT-I-ABS in BasicVaultCommon and shared pull/credit; absolute balance vs delta (L-GAPS-9); recommend a single Wave-0 CODE WP unless OWNED_ELSEWHERE; list all clone call sites as blast radius |
| `A-detf-multi-vault` | Gold adversarial completeness for A–O; theater; leftover owner/diamondCut after deploy; claim/D2; A0 residual; do not rewrite the suite — score and hunt vulns |
| `A-se-amm-v2` | SE exchangeIn/Out pretransfer; donation; route negatives; E6 refunds; L/B spot; declaration+proxy |
| `S-sharp-edges` | Defaults for pretransferred, max approve, zero minOut, PkgArgs hostile share, silent address(0) |
| `S-crops-trust` | Can a live DETF be upgraded or paused? Who can change fees? Walkaway if team disappears? |

### 4.3 Specialist prompt

```text
You are a Stage 1 domain specialist for the IndexedEx Security Audit: {SPEC_ID}.

Skill to load first: {SKILL_PATH}
Normative PRD: docs/security/SECURITY_AUDIT_PRD.md §2, §3.5, §7.3–7.4, §19.

Inputs:
- Scope partition: docs/security/audit/00_SCOPE_PARTITION.md
- Area reports (read all that exist under docs/security/audit/areas/)
- Coverage-audit backlog (OWNED_ELSEWHERE): docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md

Hard rules: {PASTE §1 GLOBAL CONSTRAINTS}

Do NOT re-inventory every product. Hunt CROSS-CUT defects in your domain.
Write {OUT_FILE} matching PRD §7.4.
Finding IDs: SEC-SPEC-NNN or SEC-CROPS-NNN or SEC-SHARP-NNN as appropriate.
Produce epic Wave-0 WPs when many packages share one root cause.
When done, return: status, Critical/High counts, epic WP-IDs.
```

| SPEC_ID | `{SKILL_PATH}` | `{OUT_FILE}` |
|---------|----------------|--------------|
| `S-sharp-edges` | Trail of Bits sharp-edges SKILL.md | `docs/security/audit/specialists/S-sharp-edges.md` |
| `S-crops-trust` | ethskills-crops SKILL.md + crane-access | `…/S-crops-trust.md` |
| `S-spec-detf` | spec-to-code-compliance SKILL.md; corpus = family PRDs + docs/detf/* + INDEXEDEX_AGENT_LAW.md DETF sections | `…/S-spec-detf.md` |
| `S-token-weird` | ethskills-audit erc20/erc4626 | `…/S-token-weird.md` |
| `S-amm-oracle-flash` | ethskills-audit defi-amm, oracles, flashloans | `…/S-amm-oracle-flash.md` |
| `S-diamond-proxy` | ethskills-audit proxies + crane-architecture + catalog J | `…/S-diamond-proxy.md` |
| `S-signatures` | ethskills-audit signatures + catalog O/I5 | `…/S-signatures.md` |
| `S-incidents` | defi-incident-patterns (map only) | `…/S-incidents.md` |
| `S-evm-general` | ethskills-audit general + precision-math + dos | `…/S-evm-general.md` |

### 4.4 Adversarial-modeler prompt

```text
You are the adversarial-modeler for Stage 1 security audit finding {FINDING_ID}.

Read: the finding write-up in {AREA_OR_SPEC_FILE}, the cited production files,
and docs/security/SECURITY_AUDIT_PRD.md §1.3 and §7.3.

Produce concrete exploit steps (attacker model, preconditions, numbered calls,
expected balance deltas) and blast radius (who else inherits this code).
Do not write production fixes. Do not write a working mainnet script.
If the finding is not actually exploitable, say so and recommend severity drop
with evidence.

Write to {OUT_FILE} or return markdown for the orchestrator to append to the finding.
```

---

## 5. Report QA (orchestrator)

### 5.1 Area report — reject / send back if missing

| Check | Required |
|-------|----------|
| Header table (date, SHA, status, paths) | yes |
| Executive summary + residual-risk scores | yes |
| Product inventory | yes |
| Threat model table | yes |
| Catalog A–O + E6/F5 matrix | yes |
| Findings with **full §7.3** fields for Critical/High | if any |
| Theater list (even if empty) | yes |
| Coverage-audit linkage | yes |
| WP stubs for Critical/High | yes |
| Commands run | yes |
| No production code patches | yes |

### 5.2 Specialist report

Header + thesis + findings (§7.3) + epic WPs + explicit non-findings + checklists walked.

---

## 6. Pilot exit criteria (`PILOT_EXIT.md`)

All must be true before `MODE=full`:

- [ ] Three pilot area reports `COMPLETE` (or `PARTIAL` with inventory + findings still usable)
- [ ] Two specialist reports present
- [ ] Each report passes §5 QA
- [ ] Thin `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` exist (≥5 WPs **or** explicit clean bill)
- [ ] At least one **runtime** attempt on top Critical/PAT-I-ABS candidate (`repro/` or valid re-check of TCA-COMMON-001 at current SHA)
- [ ] Schema issues fixed (finding IDs, WP fields, OWNED_ELSEWHERE used correctly)
- [ ] User notified of pilot results (or pre-authorized auto-continue)

---

## 7. Aggregate + backlog QA (full pass)

### 7.1 `AGGREGATE.md` must include (PRD §7.5)

1. Metadata (date, SHA, area/specialist status, L-SEC locks cited)
2. Executive summary + residual-risk heatmap
3. Global catalog matrix
4. Global domain matrix
5. CROPS record
6. PAT incidence
7. Deduped Critical/High (link sources)
8. Conflicts & decisions
9. Diff vs coverage-audit
10. Remediation wave sketch
11. Link to backlog
12. Stage 2 readiness (PRD §12 boxes)

### 7.2 `WORK_PACKAGE_BACKLOG.md` must include (PRD §8)

For **every Critical/High** WP owned by this program:

- All §8 fields, including **Conflicts with coverage-audit WP** and **`sec_fix_` worktree**
- Finding → WP index for every Critical/High `SEC-*`
- OWNED_ELSEWHERE table
- Parallelism graph (shared files = serial)

Sorted by PRD §9. Medium may be clustered.

---

## 8. Runtime proof playbook

### 8.1 Hermetic

```bash
forge test --list --match-path 'test/foundry/spec/**/*pretransfer*' 2>/dev/null | head -40
forge test --match-path 'test/foundry/spec/<path>' --match-test '<test>' -vv
```

Use hour-scale timeouts. Do not kill compile.

### 8.2 Fork (Alchemy — L-SEC-6)

```bash
# ALCHEMY_KEY in environment only
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/**' \
  --fork-url base_mainnet_alchemy \
  -vv
```

### 8.3 Repro directory

```text
docs/security/audit/repro/<FINDING_ID>/
  COMMANDS.md
  forge.log
  notes.md          # balances, selectors, confirmed|not-reproducible|BUILD_BLOCKED
```

No secrets. No mainnet exploit scripts.

---

## 9. Stage 1 stop condition

When PRD §12 is checked:

1. Tell the user where `AGGREGATE.md` and `WORK_PACKAGE_BACKLOG.md` live.
2. Summarize Critical/High counts, OWNED_ELSEWHERE, and proposed Wave 0.
3. Point them at [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) for Stage 2.
4. **Do not** start remediations.
