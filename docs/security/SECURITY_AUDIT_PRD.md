# Product Requirements Document (PRD)

## Title

**IndexedEx Security Audit** — agent-orchestrated, skill-driven parallel review of production money paths that produces a decision-grade audit report and a ranked work-package backlog a later agent can turn into a **parallel remediation PRD**

## Status

| Field | Value |
|-------|--------|
| **Status** | **DRAFT** — process law for Stage 1 (review only); **open items LOCKED 2026-08-13** (§19) |
| **Kind** | **Review PRD** (reports + optional runtime-proof artifacts). Does **not** authorize Stage 3 implementation. |
| **Primary output** | Area reports, specialist reports, aggregate audit report, and work-package backlog under `docs/security/audit/` (see §7) |
| **Downstream consumers** | (1) Agent that writes **`docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md`** from the reports (§13); (2) Agent that writes the execute plan and runs **parallel `sec_fix_*` worktrees** (§14) |
| **Hard constraints** | No **committed** product/test edits in Stage 1; **`via_ir` forbidden**; production-first testing law; DETF role names only; vault/DETF DFPkgs via manager registry; facets via CREATE3 / FactoryService; no profitable fork PoCs as definition of done |
| **Ship-blocking scope** | **All** money-moving vaults / DETFs / SE packages / hooks / production routers under `contracts/` — see §19 **L-SEC-2** |
| **Execution shape** | **Pilot first**, then full partition + domain specialists — see §15 / §19 |
| **Blocker proof bar** | **Runtime proof required** for Critical CODE claims — see §3.8 / §19 **L-SEC-3** |
| **Relation to coverage-audit** | **Complement, do not compete.** Coverage-audit owns TEST/THEATER completeness and already-indexed I/J/K CODE WPs. This program hunts **exploitable production defects** and new classes (CROPS, sharp-edges, spec-divergence, incident L/M/N/O as CODE, token weirdness, diamond storage). Link `TCA-*` IDs; do not fork a second fix list for the same touch-set — see §10 / **L-SEC-4** |
| **Fork RPC** | Prefer `foundry.toml` `*_alchemy` endpoints + `ALCHEMY_KEY` (**L-SEC-6**) |
| **Repro artifacts** | Allowed under `docs/security/audit/repro/` (**L-SEC-7**) |
| **Worktree / branch prefix** | `sec_fix_` (**L-SEC-8**) — distinct from coverage-audit `gap_cover_` |
| **Related skills (normative hunt + bar)** | See §2.1 |
| **Related law** | `Claude.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md` (§ DETF families + Test Patterns) |
| **Prior artifacts (inputs, not truth)** | `docs/testing/coverage-audit/**`, `docs/testing/ADVERSARIAL_VAULT_COVERAGE_*`, `docs/reviews/2026-08-08_struct-audit_*`, `docs/STRUCT_AUDIT_FIXES_PRD.md`, family `*_PRD.md` under `contracts/vaults/detf/**` and `docs/detf/` |
| **Execute plan** | [`docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md`](./SECURITY_AUDIT_EXECUTE_PLAN.md) — Stage 1 orchestrator steps, pilot/full, prompts, QA |
| **Stage 2 planner prompt** | [`docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) — used **after** aggregate is accepted |
| **Remediation PRD (later)** | *Out of scope until aggregate accepted;* expected path: `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` + `docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md` |

---

## 0. Intent (why this exists)

### 0.1 Problem

IndexedEx now has a **richer security skill stack** than the last coverage-oriented review:

| Installed since last security review | What it adds |
|--------------------------------------|--------------|
| `ethskills-audit` | 19-domain EVM checklist hunt via parallel specialists |
| `ethskills-security` | Defensive Solidity patterns (reentrancy, decimals, inflation, MEV, proxies, EIP-712) |
| `ethskills-crops` | Trust / admin / upgrade / exit / walkaway — DETF **unowned after deploy** is product law |
| `crane-adversarial-testing` | Catalog **A–K + A0 / L / M / N / O**, anti-theater, ship gate |
| `indexedex-adversarial-testing` | DETF / SE / bond / claim / nested mapping onto that catalog |
| `defi-incident-patterns` | DeFiHackLabs themes → catalog IDs (reference only) |
| Trail of Bits `differential-review` + `adversarial-modeler` | Blast radius, concrete exploit scenarios, evidence-first findings |
| Trail of Bits `sharp-edges` | Footgun APIs (`pretransferred`, PkgArgs, silent defaults) |
| Trail of Bits `spec-to-code-compliance` | Family PRD / agent law vs actual code |

The **test coverage audit** (`docs/testing/TEST_COVERAGE_AUDIT_PRD.md`) already answered “which catalog IDs and layers lack tests?” It did **not** systematically ask “which production paths are exploitable under the new checklists?” Implementors who only close TEST gaps will miss:

1. **New catalog extensions** — empty-vault **A0**, surplus-refund **E6**, permissionless structural settle **F5**, AMM desync **L1–L3**, middleware **M1–M3**, quote–settle **N1–N2**, signature **O1–O3**.
2. **Trust / CROPS defects** — leftover owner/operator on “unowned” DETF instances, pause/kill that bricks user exit, fee-oracle authority that can steal, registry disable that strands funds.
3. **Spec ↔ code divergence** — compound / expansion / threshold / claim-unwind law in `docs/detf/*` and family PRDs that the code does not enforce (or enforces extra undocumented money paths).
4. **API footguns** — `pretransferred`, Permit2 witness, `msg.value`, user-supplied router/`target+calldata`, PkgArgs that accept hostile shares without lock.
5. **Token integration** — FoT, rebase, missing return, 6/8-decimal, blacklist/pause underlyings on SE/DETF legs.
6. **Diamond-specific** — storage slot collision, initializer reuse, selector clash, missing `facetFuncs`, upgrade surface on products that must be immutable.

Without a **fresh, skill-routed, product-partitioned security audit**, a remediation agent will either re-implement coverage-audit WPs, or ship theater tests around live extract bugs.

### 0.2 Goals

1. **Threat-model** every in-scope money product (actors × surfaces × assets × trust flags × admin powers).
2. **Hunt** using the **union** of Crane/IndexedEx adversarial catalogs, ethskills-audit domains, CROPS, sharp-edges, spec-compliance, and incident themes.
3. **Separate** findings into CODE / TEST / THEATER / DEFER / NEEDS_OWNER / ACCEPTED_RISK.
4. **Prove** Critical CODE with runtime evidence where the environment allows (§3.8).
5. **Emit work-package-ready reports** so a Stage 2 agent can write a remediation PRD that assigns **non-overlapping worktrees** and parallel subagents **without re-exploring the monorepo**.
6. **Link, do not duplicate**, coverage-audit `TCA-*` / `WP-I-*` items that already own a touch-set.
7. **Parallelize** via orchestrator + product-area agents + domain specialists with one schema (§7).

### 0.3 Non-goals (this PRD’s execution phase)

- Writing or editing production Solidity, permanent tests, or `foundry.toml`.
- Enabling `via_ir` or package-specific IR profiles.
- Authoring the Stage 2 remediation PRD or opening `sec_fix_*` / `gap_cover_*` worktrees.
- Full formal verification, Echidna/Medusa campaigns, or a paid external audit engagement.
- Frontend, indexer, or non-Foundry e2e (CROPS frontend notes are **Info** only unless they gate onchain exit).
- Re-authoring product economics / fee schedules / DETF family law (flag as `NEEDS_OWNER`).
- Replacing MultiVault gold adversarial suite; use it as baseline.
- Deep review of pure vendored `lib/**` upstream (except Crane patterns and when IndexedEx SUT calls into ports).
- Compiling or running `lib/DeFiHackLabs` PoCs as IndexedEx tests; incident corpus is **reference only**.
- Treating `assertGt(attackerProfit, 0)` on a fork as security coverage.

### 0.4 Success definition

A decision-grade **aggregate audit report** such that a Stage 2 planning agent can, without re-auditing:

1. List every in-scope product with a threat model and residual-risk statement.
2. Enumerate **Critical/High** findings with IDs, attack scenarios, evidence, blast radius, and recommended CODE + TEST.
3. Produce a **work-package DAG** (dependencies, parallelizable sets, suggested `sec_fix_*` worktrees, non-overlapping touch-sets).
4. Define **acceptance tests** (exact `forge test --match-path` / `--match-test` plus anti-theater checks) per WP.
5. Know which items are **already owned** by coverage-audit / gap-closure (`TCA-*` / `WP-I-*`) and must be linked, not re-queued.
6. Hand off cleanly to `SECURITY_AUDIT_REMEDIATION_PRD.md` authorship via [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md).

**This PRD is done when the aggregate report and backlog are accepted — not when remediations are green.**

---

## 1. Definitions

| Term | Meaning |
|------|---------|
| **Product / surface** | Deployable user-facing vault, DETF, SE package, hook vault, router, manager/fee/registry component |
| **SUT** | Subject under test — real production diamond/instance via factories + registry; never a mock of the product |
| **Catalog ID** | Crane adversarial ID: **A–H** classic, **A0** empty-vault, **I** trust-flag, **J** surface, **K** accounting-sync, **L** AMM desync, **M** middleware, **N** TOCTOU, **O** signatures, plus **E6** surplus-refund and **F5** permissionless structural settle |
| **EVM-audit domain** | One of the `ethskills-audit` / evm-audit specialist checklists (general, precision-math, erc20, erc4626, defi-amm, proxies, signatures, access-control, oracles, flashloans, dos, assembly, …) |
| **CROPS finding** | Trust / censorship / exit / custody / upgrade / admin-power issue (not always a steal-funds bug) |
| **Sharp edge** | API or PkgArgs default that makes the insecure path the easy path |
| **Spec divergence** | Family PRD / agent law / `docs/detf/*` says X; code does Y (or is silent / extra) |
| **Theater** | Test or control list that cannot fail if the production bug class is present |
| **Work package (WP)** | Self-contained fix+test unit for one implementer/worktree (schema §8) |
| **Area** | Non-overlapping **production path** slice for one product-area subagent |
| **Specialist** | Cross-cut domain agent (evm-audit domain, CROPS, sharp-edges, spec-compliance, incident map, adversarial-modeler) |
| **Orchestrator** | Parent agent: partition, spawn, merge, aggregate, rank backlog |
| **Finding** | One actionable defect or accepted risk with severity, class, evidence, attack scenario, close plan |
| **Remediation PRD** | Stage 2 document that authorizes parallel `sec_fix_*` implementers from this backlog |

### 1.1 Severity (audit findings)

Use **audit severity**, not coverage-audit “Blocker/High” labels. Map to remediation urgency in the right column.

| Severity | Meaning | Closure expectation |
|----------|---------|---------------------|
| **Critical** | Unbounded extract, free mint of inventory, insolvency, silent missing money API on a live proxy, or equivalent single-tx drain by an unprivileged attacker | Wave 0/1; CODE before any greenwash; runtime proof required |
| **High** | Significant loss with realistic preconditions (capital, hostile share as configured vaultShare, flash loan + open gates, Permit2 spender); P0 catalog hole on a live money path | First or second wave |
| **Medium** | Grief, bounded extract, missing guard on non-primary route, preview/execute drift, P1 catalog, CROPS admin that cannot steal but can freeze | Before major release / external audit |
| **Low** | Hygiene, NatSpec, redundant auth, naming, Info-adjacent sharp edges | Opportunistic |
| **Info** | Already covered; documented intentional economic risk (seigniorage under open thresholds); CROPS record with no CODE WP | No WP unless `NEEDS_OWNER` |

Coverage-audit **Blocker** ≈ this program’s **Critical**. Do not invent a second “Blocker” label.

### 1.2 Finding class

| Class | Meaning |
|-------|---------|
| **CODE** | Production behavior wrong or incomplete; implementer must change contracts (then tests) |
| **TEST** | Production appears correct; missing/weak proof in Foundry |
| **THEATER** | Existing test misleads (fix or replace test; may also need CODE if SUT wrong) |
| **DEFER** | Explicitly out of wave with reason (gas grief N-max, peer port, fork MEV reconstruction) |
| **NEEDS_OWNER** | Product-law ambiguity (e.g. should donations revert or benefit next depositor?) |
| **ACCEPTED_RISK** | Intentional economic or trust posture with **documented invariants** (e.g. DETF unowned after deploy; seigniorage when both gates open) |
| **OWNED_ELSEWHERE** | Same touch-set already in coverage-audit / gap-closure backlog — **link** `TCA-*` / `WP-*`, do not create a competing `SEC-*` WP |

### 1.3 Attacker models (required on Critical/High)

| ID | Attacker |
|----|----------|
| **EXT** | Unprivileged EOA, single transaction |
| **CAP** | Capitalized attacker (flash loan or minted underlyings in hermetic) |
| **HOS** | Hostile ERC20 / vaultShare configured via production PkgArgs |
| **INT** | Integrator / router / Permit2 spender confusion |
| **ADM** | Compromised owner/operator **before** DETF is unowned, or leftover admin after “immutable” |
| **CFG** | Honest-but-confused deployer (sharp-edges / PkgArgs) |

---

## 2. Normative security bar (what “audited” means)

Reviewers **must** score products against this bar. Skills are source of truth; this section is the audit checklist form. **Do not weaken** Crane/IndexedEx production-first DoD to match a generic evm-audit writeup.

### 2.1 Skills to load (by role)

| Role | Skills / agents | When |
|------|-----------------|------|
| Orchestrator (always) | This PRD + execute plan; `Claude.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` (DETF / deploy); `crane-adversarial-testing` + `references/implementation-test-dod.md`; `indexedex-adversarial-testing`; `ethskills-audit` (routing table only) | Before any spawn |
| Every product-area agent | `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-testing`, `indexedex-testing`, `ethskills-security`, `defi-incident-patterns` (theme map) | Always |
| Diamond / proxy specialist | `ethskills-audit` proxies domain, `crane-architecture`, catalog **J**, `crane-access` | Always on full pass |
| Token specialist | `ethskills-audit` erc20 + erc4626, token-integration-analyzer if available, catalog **L2 / I4** | Always on full pass |
| AMM / oracle / flash specialist | `ethskills-audit` defi-amm + oracles + flashloans, catalog **B / L / N** | SE, DETF, hooks |
| Access / CROPS specialist | `ethskills-crops`, `ethskills-audit` access-control, `crane-access` | Manager, registry, fee, DETF immutability |
| Signature / Permit2 specialist | `ethskills-audit` signatures, catalog **O / I5**, Permit2 skills | Routers, vaults with permit |
| Sharp-edges specialist | Trail of Bits `sharp-edges` / `sharp-edges-analyzer` | PkgArgs, `pretransferred`, helpers |
| Spec-compliance specialist | Trail of Bits `spec-to-code-compliance` / `spec-compliance-checker` | DETF families with a PRD |
| Adversarial modeler | `differential-review:adversarial-modeler` | Every Critical/High CODE after first pass |
| Incident mapper | `defi-incident-patterns` | After areas return; map themes → IDs |
| DETF adversarial (optional) | user-defined `detf-adversarial` | Multi-vault / bond-claim / nested |

**Load order for a new area:** Crane/IndexedEx adversarial + testing → `ethskills-security` → routed evm-audit domains → CROPS / sharp-edges / spec as triggered.

**Do not** treat `ethskills-audit` as a replacement for `crane-adversarial-testing` ship-gate. EVM-audit checklists are **hunt lists**. Pass criteria remain: exploit **blocked** on production SUT, or intentional risk with hard invariants.

### 2.2 Catalog layers (must score)

| Layer / ID family | Minimum for money products |
|-------------------|----------------------------|
| **A / A0** | Donation / inflation / empty-vault residual inventory |
| **B** | Spot / rate manipulation (or documented seigniorage bounds) |
| **C** | Reentrancy / `IsLocked` on hostile share |
| **D** | Authority / claim / NFT / double redeem |
| **E / E6** | Accounting, residual, surplus-refund (`balance − floor`) |
| **F / F5** | Access / immutability / permissionless structural settle |
| **G** | Nested composition |
| **H** | Grief / atomicity (failed redeem does not keep burn) |
| **I1–I5** | Trust-flag / claimed amount / Permit2 delivered ≠ signed |
| **J1–J4** | Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ **proxy** callable |
| **K** | Reserve / lastTotalAssets sync; donation mis-credit |
| **L1–L3** | AMM books ≠ balances; FoT; spot-as-oracle |
| **M1–M3** | Arbitrary call / user swap target / allowance sweep |
| **N1–N2** | Quote–settle TOCTOU; preview ≡ execute |
| **O1–O3** | Invalid/zero/replay signatures; EIP-712 domain |

Mark each ID **F** (found/covered), **P** (partial), **G** (gap), **N/A** (deferred with one-line reason), or **VULN** (production appears exploitable — open a CODE finding).

### 2.3 EVM-audit domain routing (product class → specialists)

Orchestrator **shall** assign domains; area agents still hunt locally.

| Product class | Required evm-audit domains | Extra specialists |
|---------------|----------------------------|-------------------|
| **DETF (bond/claim)** | general, precision-math, erc20, erc4626, defi-amm, proxies, access-control, oracles, flashloans, dos, erc721 (bond NFT) | spec-compliance vs family PRD + `docs/detf/*`; CROPS (unowned); sharp-edges (PkgArgs, thresholds) |
| **Standard Exchange vault** | general, precision-math, erc20, erc4626, defi-amm, proxies, flashloans, dos | token-integration; incident A0/L |
| **Hook diamond package** | general, defi-amm, proxies, dos, assembly (CREATE2/CREATE3 flags) | hook skill; J full; residual / reentrancy if hook calls out |
| **Router / Permit2 coordinator** | general, erc20, signatures, access-control, dos | M1–M3, O, I5; sharp-edges on witness |
| **Manager / fee oracle / registry** | general, access-control, proxies | CROPS; fee non-dilution; disable/exit |
| **LST / lending SE (Lido, EtherFi, Rocket, Aave, Morpho)** | + defi-staking or defi-lending as applicable | port skill; rebase / Stata share math |

Always-on domains for **every** money product: **general**, **precision-math**, **erc20**, **proxies**, **access-control**, **dos**.

### 2.4 Explicit known bug patterns (must hunt)

Every area agent **shall** actively search for these (not wait for catalog coincidence). Include coverage-audit PAT-* plus new security patterns.

| Pattern ID | Symptom | Typical CODE direction | Catalog |
|------------|---------|------------------------|---------|
| **PAT-I-ABS** | `pretransferred` returns claimed amount after `balanceOf >= amount` | Credit observed **delta** only; short → shared typed revert | I1–I3 |
| **PAT-J-OMIT** | Target money/view missing from `facetFuncs` | Add selectors + package cuts | J1–J3 |
| **PAT-J-CTRL** | `controlFacetFuncs` mirrors incomplete Facet | Controls from Target/interface | J1 |
| **PAT-K-DONATE** | Next deposit credits prior donation via raw balance | Delta / snapshot; no victim loss | K1 |
| **PAT-E6-REFUND** | Refund / reclaim pays `balance − floor` to caller | Cap to this-call overpay / tracked credit | E6, L1 |
| **PAT-F5-RESIZE** | Permissionless migrate/resize/reclaim settles surplus | Auth-gate or cannot touch untracked inventory | F5 |
| **PAT-A0-EMPTY** | `totalSupply()==0` (or pre-live) while contract holds assets; first minter drains | Dead shares / init / go-live gate | A0 |
| **PAT-M-CALL** | User `target+calldata` or open allowance on helper | Allowlist; measure amountOut; no arbitrary call | M1–M3 |
| **PAT-N-TOCTOU** | Hook/callback between quote and settle changes units | Lock valuation; hostile hook cannot inflate credit | N1 |
| **PAT-O-SIG** | ecrecover address(0), replay, wrong domain | Revert; never authorize 0 | O1–O3 |
| **PAT-L-SKIM** | Untracked pair surplus + public skim / FoT desync | Books = balances; credit actualIn | L1–L2 |
| **PAT-CROPS-ADMIN** | “Unowned” DETF still has owner/operator/diamondCut | Strip; document walkaway | F, CROPS-S |
| **PAT-SPEC-DRIFT** | Law says claim-only after maturity / threshold exclusive; code allows both | Align code or `NEEDS_OWNER` | D, B3 |
| **PAT-SHARP-FLAG** | Default `pretransferred=true` / max approval / zero minOut is the easy path | Secure default; type-safe params | I, sharp-edges |
| **PAT-SLOT** | Diamond storage slot / layout collision across facets | Unique slot; no overlapping structs | proxies |
| **PAT-THEATER-PRE** | Only happy `pretransferred=true` with real transfer | Add false-claim cases | I1 |
| **PAT-THEATER-FACET** | Declaration tests never deploy package/proxy | Loupe + proxy smoke | J2–J3 |
| **PAT-MOCK** | Spec uses Mock SE / `mockCall` on SUT | Does not count as proof | — |

### 2.5 Product law anchors (do not contradict)

When scoring claim / pretransfer / fees / thresholds / unowned posture, align with locked law:

| Lock / source | Statement |
|---------------|-----------|
| **L-CLAIM-3** / **L-GAPS-9** | `pretransferred=true` credits only against **observed inbound delta**; `claimed ≤ delta` → credit `claimed`; `claimed > delta` → shared short-delivery revert; do **not** require exact-delta equality (donation grief) |
| DETF agent law | Instances **immutable / unowned after deploy**; inert until first bond / family bootstrap; sell→claim only after bond maturity (DETF-wide); mint/burn thresholds from `PkgArgs` → `DETFThresholdPolicy`; fees via fee oracle |
| Intentional seigniorage | Open thresholds may allow bounded skew extract — **ACCEPTED_RISK** only with victim-balance + no-free-principal + residual-inventory invariants |
| Coverage-audit **L-TCA-4** | I/J/K CODE+TEST WPs already in `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` stay owned there unless that program is abandoned |

If code and law disagree → **CODE** (or **NEEDS_OWNER** only if law is unclear).

---

## 3. Program architecture (orchestrator → reports → later remediate)

### 3.1 End-to-end pipeline (this PRD is Stage 1 only)

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 1 — THIS PRD (review only)                                         │
│  Orchestrator partitions Areas + Specialists → parallel subagents →      │
│  area/specialist reports → adversarial-modeler on Critical/High →        │
│  aggregate AUDIT-REPORT + WP backlog                                     │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 2 — Planning agent (separate; prompt file already exists)          │
│  Reads aggregate + backlog → writes SECURITY_AUDIT_REMEDIATION_PRD.md    │
│  + execute plan (waves, worktrees, subagent prompts, deps)               │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STAGE 3 — Implementation orchestrator (separate)                         │
│  Worktrees `sec_fix_*` + parallel CODE/TEST agents; production-first;    │
│  forge green; no via_ir                                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

**Stage 1 agents must not start Stage 2 authorship or Stage 3 worktrees.** They **shall** sketch WP IDs and acceptance commands so Stage 2 is cheap.

### 3.2 Stage 1 roles

```text
Orchestrator
  ├─ freeze inventory methodology + area map + specialist map
  ├─ spawn product-area agents (parallel, report-only)
  ├─ spawn domain specialists (pilot subset, then full)
  ├─ spawn adversarial-modeler on each Critical/High CODE
  ├─ merge, dedupe, conflict-resolve, link TCA-*
  └─ write AGGREGATE (AUDIT-REPORT) + global WP backlog
```

### 3.3 Orchestrator requirements

The Stage 1 orchestrator **shall**:

1. Read this PRD + execute plan + `Claude.md` non-negotiables + `crane-adversarial-testing` (A–K + A0/L/M/N/O + DoD) + `ethskills-audit` routing table **before** spawning.
2. Produce a **scope partition table** (Area → production paths → test paths → specialists assigned → excluded) **before** subagents start; write it to `docs/security/audit/00_SCOPE_PARTITION.md`.
3. Spawn subagents **in parallel** with **identical output schema** (§7).
4. Assign **non-overlapping** report paths (`docs/security/audit/areas/<AREA_ID>.md`, `docs/security/audit/specialists/<SPEC_ID>.md`).
5. After returns:
   - Dedupe findings by `(product, pattern or catalog ID, path)`.
   - Mark **OWNED_ELSEWHERE** when the same production touch-set is already a coverage-audit Blocker/High WP; copy the `TCA-*` / `WP-*` IDs.
   - Resolve conflicts (CODE vs TEST, Critical vs High) in a **Conflicts** section with one decision.
   - Build **global matrices**: catalog×product, evm-domain×product, PAT×product, CROPS×component.
   - Rank **Top N** work packages (default N=40) by §9.
   - Diff vs coverage-audit aggregate: **Still vuln / Test-only / Closed / New / Stale claim**.
6. **Not** edit production or test code.
7. Record commands used (`rg`, optional `forge test --list`, runtime proof cmds) for reproducibility.
8. After Critical/High CODE exist, spawn **adversarial-modeler** (or equivalent) to add concrete exploit steps + blast radius before the finding is “shippable” to Stage 2.

### 3.4 Product-area subagent requirements

Each area agent **shall**:

1. Stay in path allowlist; out-of-area deps as **reference only**.
2. Complete workstreams in §6.
3. Emit report matching §7.2.
4. Prefer evidence: file paths, line ranges, function names, whether a test hits **proxy**.
5. Mark uncertainty (`unknown`, `needs runtime`, `needs product owner`).
6. Never recommend `via_ir`.
7. Classify every finding (§1.2). Assign attacker model (§1.3) on Critical/High.
8. For each Critical/High: propose **at least one** concrete test name + setup sketch + pass criteria **and** a CODE sketch if class is CODE.
9. Prefer production-first law when judging “safe”: mock-SUT tests do not refute a vuln.
10. Use DETF role names only.

### 3.5 Domain specialist agents

| Specialist ID | Skill / agent | Writes | Trigger |
|---------------|---------------|--------|---------|
| `S-crops-trust` | `ethskills-crops`, `crane-access` | `specialists/S-crops-trust.md` | Always on full pass; pilot if manager/registry in scope |
| `S-sharp-edges` | `sharp-edges` / `sharp-edges-analyzer` | `specialists/S-sharp-edges.md` | Always on full pass; pilot on commons + DETF PkgArgs |
| `S-spec-detf` | `spec-to-code-compliance` / `spec-compliance-checker` | `specialists/S-spec-detf.md` | Full pass: families with a PRD; pilot: MultiVault + `docs/detf/*` shared compound/expansion |
| `S-token-weird` | evm-audit erc20/erc4626 + token-integration | `specialists/S-token-weird.md` | Full pass |
| `S-amm-oracle-flash` | evm-audit defi-amm / oracles / flashloans | `specialists/S-amm-oracle-flash.md` | Full pass; SE + DETF + hooks |
| `S-diamond-proxy` | evm-audit proxies + catalog J + storage slots | `specialists/S-diamond-proxy.md` | Always on full pass |
| `S-signatures` | evm-audit signatures + catalog O/I5 | `specialists/S-signatures.md` | Routers / Permit2 area present |
| `S-incidents` | `defi-incident-patterns` | `specialists/S-incidents.md` | After areas return (map only; no new hunt unless a theme has no finding) |
| `S-adv-modeler` | `differential-review:adversarial-modeler` | `specialists/S-adv-modeler-<FINDING>.md` or append to finding | Every Critical/High CODE |
| `S-evm-general` | evm-audit general + precision-math + dos | `specialists/S-evm-general.md` | Full pass (may be split if too large) |

Specialists **do not** re-inventory products. They consume area inventories and hunt **cross-cut** defects. They may open findings with IDs `SEC-SPEC-<NNN>`.

### 3.6 Parallelism rules

| Rule | Detail |
|------|--------|
| Min product areas (full pass) | ≥8 |
| Pilot | 3 product areas + 2 specialists (see §15) |
| Max concurrent | Prefer **4–8** live children; queue the rest |
| Isolation | One report file per agent; no shared mutable docs except orchestrator aggregate |
| Fail soft | Area `FAILED`/`PARTIAL` must not drop others |
| Time box | Orchestrator may mark `PARTIAL` with remaining inventory list |
| Worktree isolation | Stage 1 does **not** use `sec_fix_*` worktrees |

### 3.7 Tooling hints

- Prefer `explore` (read-only) or `general-purpose` with writes **only** under `docs/security/audit/**`.
- Named agents when they fit: `sharp-edges-analyzer`, `spec-compliance-checker`, `differential-review:adversarial-modeler`, `detf-adversarial` (read-only / report-only).
- `rg` for: `pretransferred`, `facetFuncs`, `diamondCut`, `onlyOwner`, `onlyOperator`, `delegatecall`, `call{value`, `balanceOf(address(this))`, `msg.value`, `ecrecover`, `permit`, `transferFrom`, `safeTransfer`, `initialize(`, `lastTotal`, `minOut`, `target` + `calldata`.
- List tests: `forge test --list --match-path '...'` when environment allows (do not block inventory on compile failures — note `BUILD_BLOCKED`).
- Prefer static mapping + targeted forge; full-suite runs only for Critical proof or to falsify “already safe” claims.
- **Forge patience:** monorepo compile 20–40+ minutes is normal. Do **not** kill `forge` / `solc`. Timeouts for first compile: **hours**, not 10–20 minutes.

### 3.8 Runtime proof for Critical CODE claims (locked)

For findings classified **Critical** + **CODE** (free mint, unbounded extract, insolvency, money API missing on proxy):

1. **Static evidence alone is insufficient** to ship the finding as Critical CODE.
2. Reviewer **shall** obtain **runtime proof** where the environment allows:
   - Prefer: existing test that fails to catch the bug, or a **throwaway** local repro (not committed) that shows the bad state transition.
   - Or: `forge test` / scripted call path against a production-deployed instance in hermetic (or fork if that is the only path).
3. Record: exact command, observed balances/reverts, status **confirmed** / **not reproducible** / **BUILD_BLOCKED**.
4. If runtime is impossible, keep severity **High** max unless static evidence is overwhelming **and** label `RUNTIME_UNPROVEN`; Stage 2 must include a proof-first task.
5. **Still no committed** production or permanent test-suite diffs in Stage 1.
6. **Repro evidence** may be stored under `docs/security/audit/repro/<FINDING_ID>/`. Prefer logs + commands over long-lived PoC contracts. Never commit secrets/`ALCHEMY_KEY`. Never leave a working mainnet exploit script.

High/Medium CODE may remain static-only with lower confidence.

---

## 4. Default partition

Orchestrator may refine names/paths but must keep **non-overlapping production ownership**. Tests may be cited across areas; the **owning** area is where the SUT package lives.

### 4.1 Product areas

| Area ID | Production (primary) | Tests (primary) | Focus |
|---------|----------------------|-----------------|-------|
| `A-commons-pull` | `contracts/vaults/basic/**`, shared pull/credit (`BasicVaultCommon`, DETF `_pullToken` clones as **reference**), `ISecurePullErrors` | `test/**` touching pretransfer / secure pull | **PAT-I-ABS**, I1–I3, K, sharp default flags |
| `A-detf-multi-vault` | `contracts/vaults/detf/**/multi-vault-weighted/**` | `test/**/multi-vault-weighted/**` | Gold DETF; bond/claim D; A0; nested G; I/J/K/L |
| `A-detf-single-se` | Single SE DETF packages (Balancer V3 + Uni V4 CP) | matching `test/**/standardExchange/**` | Port vs MultiVault; residual; I/J |
| `A-detf-composed-stable` | Composed stable / mixed buffer DETF | matching `stable/**`, `mixedBuffer/**` | Multi-leg residual, claim, G |
| `A-detf-dual-liquidity` | DualLiquidity cross-version | fork + hermetic dual-liquidity | Fork-first P0 = hermetic severity (**L-SEC-5**) |
| `A-se-amm-v2` | Aerodrome / Camelot / Uni V2 SE | matching SE TestBases | Routes, pretransfer, L/B |
| `A-se-v3-v4-lending` | Uni V3/V4 SE, Aave Stata / loop, Morpho SE, LST SE (Lido/EtherFi/Rocket) | matching | Rebase, Stata math, I/J, lending domains |
| `A-hooks-v4` | `contracts/hooks/**` | hook package tests | Flags, `deployHookVault`, J, residual, hook reentrancy |
| `A-manager-fee-registry` | manager, fee collector, fee oracle, vault registry | matching | Access, disable/exit, fee non-dilution, CROPS |
| `A-routers-permit2` | `contracts/routers/**`, Permit2 witness paths | matching | M, O, I5, allowance theater |

**Optional full-pass add-ons:** `A-slipstream-buffer`, `A-research-contracts` (only if `research/**` still contains deployable product-like contracts).

**Out of scope (default):** `frontend/**`, `broadcast/**`, `out/**`, `cache_forge/**`, marketing docs, Godot/game skills, Bankr catalogs, `lib/DeFiHackLabs` as compile deps.

### 4.2 Specialist assignment (full pass)

See §3.5. Pilot specialist set is locked in §15.

---

## 5. Inventory methodology (per product area)

For each product in the area:

### 5.1 Locate

1. DFPkg / Facets / Targets / Repos / common libs.
2. Gold `TestBase_*` inheritance chain and deploy path (registry vs `new` vs mock).
3. Spec, fork, `adversarial/`, fuzz, invariant handlers.
4. Family PRD / `docs/detf/*` / coverage-audit area report for the same product.

### 5.2 Threat model (mandatory table)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT / CAP / HOS / INT / ADM / CFG | e.g. `exchangeIn`, `bond`, `redeemClaim` | `rateAsset` / `vaultShare` / BPT / claim | `pretransferred`, Permit2, `msg.value` | fee oracle, thresholds, owner | free mint / drain / freeze |

### 5.3 Hunt

1. Walk §2.2 catalog; mark F/P/G/N/A/**VULN**.
2. Walk §2.4 patterns.
3. Walk routed evm-audit domains (use checklist headings; do not paste entire upstream checklists into the report).
4. Note CROPS powers and walkaway (can user exit if team disappears?).
5. Note sharp edges on public args.
6. If a family PRD exists, spot-check **must/never** statements vs code (full IR is the spec specialist’s job).

### 5.4 Score residual risk

| Score | Meaning |
|-------|---------|
| **0** | Unreviewed / BUILD_BLOCKED with no static pass |
| **1** | Obvious Critical/High CODE still open |
| **2** | Money path reviewed; P0 catalog holes or unproven Criticals |
| **3** | No confirmed Critical; High leftovers or missing I/J/L/M/O as applicable |
| **4** | P0 catalog + I/J/K (as applicable) look sound; residual Medium |
| **5** | Gold-comparable (MultiVault-class) with documented ACCEPTED_RISK only |

This is **security residual risk**, not coverage-audit maturity. A product can score 5 on coverage and 2 here (tests exist but SUT is wrong) or the reverse.

---

## 6. Workstreams (every product-area agent)

| WS | Name | Output in area report |
|----|------|------------------------|
| **WS1** | Product inventory | Packages + TestBases + deploy path quality |
| **WS2** | Threat model | Actor × surface table (§5.2) |
| **WS3** | Catalog matrix | A–O + E6/F5: F/P/G/N/A/VULN + evidence |
| **WS4** | Pattern hunt | PAT-* findings |
| **WS5** | Domain notes | Which evm-audit domains were walked; notable hits |
| **WS6** | Theater + false confidence | Misleading tests that hide vulns |
| **WS7** | Coverage-audit link | `TCA-*` / `WP-*` already owning this touch-set |
| **WS8** | Finding write-ups | Full §7.3 schema for every Critical/High; cluster Mediums |
| **WS9** | WP stubs | §8 fields for every Critical/High (and clustered Mediums) |
| **WS10** | Open questions | NEEDS_OWNER, BUILD_BLOCKED, RUNTIME_UNPROVEN, ACCEPTED_RISK |

---

## 7. Report schemas (normative)

### 7.1 Directory layout

```text
docs/security/audit/
  00_SCOPE_PARTITION.md
  01_METHODOLOGY_NOTES.md          # optional: commands, skill versions, git SHA
  areas/
    A-commons-pull.md
    A-detf-multi-vault.md
    ...
  specialists/
    S-crops-trust.md
    S-sharp-edges.md
    ...
  repro/                           # L-SEC-7
    <FINDING_ID>/
      COMMANDS.md
      forge.log
      notes.md
  PILOT_EXIT.md
  AGGREGATE.md                     # AUDIT-REPORT (pilot: thin; full: complete)
  WORK_PACKAGE_BACKLOG.md          # primary Stage 2 handoff
```

Do **not** overwrite a prior complete full-pass aggregate without user OK; archive under `docs/security/audit/archive/{RUN_DATE}/`.

### 7.2 Area report template

Each `areas/<AREA_ID>.md` **must** include:

```markdown
# Security Audit — <AREA_ID>

| Field | Value |
|-------|--------|
| Date | YYYY-MM-DD |
| Git SHA | |
| Agent / run | |
| Status | COMPLETE \| PARTIAL \| FAILED |
| Production paths | |
| Test paths | |
| Skills cited | SECURITY_AUDIT_PRD + … |
| Residual-risk scores | product → 0–5 |

## 1. Executive summary
- Residual-risk scores
- Critical/High counts
- Top recommended WPs
- OWNED_ELSEWHERE count (linked TCA)

## 2. Product inventory
| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |

## 3. Threat models
(one table per product)

## 4. Catalog matrix (A–O, E6, F5)
| ID | Product | F/P/G/N/A/VULN | Evidence |

## 5. Domain notes
Which evm-audit / CROPS / sharp-edges items were walked.

## 6. Findings
### 6.x [FINDING_ID] — see §7.3

## 7. Theater / false confidence
| Test / control | Why it cannot catch the bug | Fix |

## 8. Coverage-audit linkage
| TCA / WP | Same touch-set? | Action (OWNED_ELSEWHERE / still new) |

## 9. Work package stubs
(§8 — at least for Critical/High)

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

## 11. Commands run
```

### 7.3 Finding schema (normative — Stage 2 reads this)

Every Critical/High (and every VULN) **must** fill all required fields.

| Field | Required | Description |
|-------|----------|-------------|
| **FINDING_ID** | yes | `SEC-<AREA_SHORT>-<NNN>` (e.g. `SEC-COMMON-001`, `SEC-DETF-MV-004`, `SEC-SPEC-012`) |
| **Title** | yes | Short imperative / noun phrase |
| **Severity** | yes | Critical / High / Medium / Low / Info |
| **Class** | yes | CODE / TEST / THEATER / DEFER / NEEDS_OWNER / ACCEPTED_RISK / OWNED_ELSEWHERE |
| **Confidence** | yes | confirmed / static-high / static-medium / RUNTIME_UNPROVEN / not-reproducible |
| **Catalog IDs** | yes | A0, I1, E6, … or `none` |
| **Pattern IDs** | yes | PAT-* or `none` |
| **EVM-audit domain** | yes | e.g. erc4626, proxies |
| **CROPS pillar** | if trust | C / O / P / S or `n/a` |
| **Incident theme** | if mapped | from `defi-incident-patterns` or `none` |
| **Products** | yes | Package names |
| **Blast radius** | yes | shared commons / family / single package + caller sketch |
| **Attacker** | Critical/High | EXT / CAP / HOS / INT / ADM / CFG |
| **Attack scenario** | Critical/High | Numbered steps; concrete functions and tokens (role names) |
| **Preconditions** | Critical/High | Live? inventory already held? hostile share in PkgArgs? |
| **Impact** | yes | What is stolen / frozen / griefed |
| **Evidence** | yes | `path:line` + quote or paraphrase; test names |
| **Runtime** | Critical CODE | command, outcome, `repro/` path |
| **Recommended CODE** | if CODE | Files + sketch (not a full patch) |
| **Recommended TEST** | yes | `test_<ID>_…` name, setup, pass criteria, `forge` match |
| **Anti-theater** | yes | What the test must not do |
| **Suggested WP-ID** | yes | `WP-SEC-…` |
| **Link TCA / prior** | yes | IDs or `none` |
| **Depends / parallel** | yes | For DAG |

Aggregate may remap to stable global IDs `SEC-G-###` when deduping.

### 7.4 Specialist report template

```markdown
# Security Audit specialist — <SPEC_ID>

| Field | Value |
|-------|--------|
| Date / SHA / status | |
| Inputs (area reports read) | |
| Skill | |

## 1. Cross-cut thesis (≤10 lines)
## 2. Findings (same §7.3 schema; IDs SEC-SPEC-NNN or SEC-CROPS-NNN)
## 3. Products implicated (blast)
## 4. Recommended epic WPs (Wave 0 style)
## 5. Explicit non-findings (checked, clean)
## 6. Commands / checklists walked
```

### 7.5 Aggregate report (`AGGREGATE.md`) — the AUDIT-REPORT

Must include:

1. **Program metadata** — date, git SHA, areas/specialists COMPLETE/PARTIAL/FAILED, PRD locks cited.
2. **Executive summary** — residual-risk heatmap, Critical list, shared-commons epics, OWNED_ELSEWHERE vs new.
3. **Global catalog matrix** (products × A–O/E6/F5).
4. **Global domain matrix** (products × evm-audit domains walked).
5. **CROPS record** for the protocol (unowned DETF, fee oracle, registry disable, frontend = Info).
6. **Pattern incidence** (PAT-* counts and epicenters).
7. **Deduped findings** (all Critical/High; Medium if space; link area/specialist files).
8. **Conflicts & decisions**.
9. **Diff vs coverage-audit** (`docs/testing/coverage-audit/AGGREGATE.md`): Still vuln / Test-only / Closed / New / Stale.
10. **Recommended remediation waves** (input to Stage 2 — not a full plan):
    - Wave 0: shared CODE (pull/delta, shared errors, leftover admin strip) — **serial**
    - Wave 1: Critical/High CODE+TEST per **non-overlapping** package
    - Wave 2: L/M/N/O + router/Permit2 + hook residuals
    - Wave 3: spec-alignment + CROPS documentation + Medium
    - Wave 4: Low / sharp-edges defaults
11. **Link** to `WORK_PACKAGE_BACKLOG.md`.
12. **Stage 2 readiness checklist** (§12 + §13 inputs present).

### 7.6 Work package backlog file

`WORK_PACKAGE_BACKLOG.md` is the **primary handoff** to the Stage 2 planning agent. Schema in §8.

Must also include:

- Finding → WP index for **every** Critical/High `SEC-*` ID.
- OWNED_ELSEWHERE table: `SEC-*` → `TCA-*` / `WP-I-*` (no new `sec_fix_*` tree).
- Parallelism graph: which WPs share files (serial) vs disjoint (parallel).

---

## 8. Work package schema (for Stage 2 / Stage 3)

Each WP must be implementable in **one worktree** by **one agent** (or a tightly coupled CODE+TEST pair) without editing another WP’s **primary** files.

| Field | Required | Description |
|-------|----------|-------------|
| **WP-ID** | yes | e.g. `WP-SEC-I-COMMON-001`, `WP-SEC-E6-SE-003` |
| **Title** | yes | Short imperative |
| **Severity** | yes | Critical/High/Medium/Low |
| **Class** | yes | CODE / TEST / BOTH / DOCS |
| **Products** | yes | Affected packages |
| **Finding IDs** | yes | `SEC-*` links |
| **Problem** | yes | 2–5 sentences + attack one-liner |
| **Production files (touch set)** | if CODE | Explicit paths; minimize blast radius |
| **Test files (touch set)** | yes | New or existing paths |
| **Out of scope files** | yes | Prevent thrash |
| **Depends on** | yes | Other WP-IDs, `WP-I-*` (coverage-audit), or `none` |
| **Parallelizable with** | yes | WP-IDs safe concurrent |
| **Conflicts with coverage-audit WP** | yes | `none` or `OWNED_ELSEWHERE → WP-I-…` (then **do not** schedule `sec_fix_*`) |
| **Suggested worktree** | yes | Prefix **`sec_fix_`** — e.g. `sec_fix_i-common`, branch `sec_fix/i-common` |
| **Implementation notes** | yes | Skills, gold tests to copy, product-law locks to obey |
| **Acceptance** | yes | Exact forge commands + required `test_*` / catalog IDs |
| **Anti-theater checks** | yes | e.g. “I1 must not transfer tokens”; “J3 calls proxy”; “pass = exploit blocked” |
| **Proof-first?** | yes | `yes` if Critical was RUNTIME_UNPROVEN |
| **Estimate** | optional | S/M/L |

### 8.1 Wave guidance (normative for Stage 2 planners)

| Wave | Contents |
|------|----------|
| **0** | Shared CODE for PAT-I-ABS / E6 refund math / leftover admin on “unowned” instances; shared error types. **Serial.** Do not fork all products until commons land if they share the bug. |
| **1** | Per-product Critical/High CODE + I1–I3 + J1–J3 + A0 on **disjoint** packages |
| **2** | L/M/N/O, router/Permit2, hook residual, K leftovers |
| **3** | Spec-alignment CODE, CROPS docs, Medium clustered WPs |
| **4** | Low / sharp-edges defaults / NatSpec |

### 8.2 Parallelism constraints for Stage 3 (document in backlog)

- WPs that edit the **same** common lib (`BasicVaultCommon`, shared DETF transfer, shared error) are **serial** or a single WP.
- Product-local suites under different `contracts/...` **and** `test/...` trees are **parallel**.
- Facet selector fixes may be parallel **per package** if DFPkgs do not share facet contracts.
- Never parallel two agents on the same Facet / Common file without a merge plan.
- If a WP is **OWNED_ELSEWHERE**, Stage 3 of **this** program skips it; Stage 2 must say so explicitly so `gap_cover_*` and `sec_fix_*` do not collide.
- Orchestrator concurrency for Stage 3: **≤ 3** live `sec_fix_*` worktrees unless the remediation PRD raises it.

---

## 9. Scoring and ranking

### 9.1 Composite priority (for Top N WP backlog)

```text
score = severity_weight × exploitability × blast_radius × class_weight
```

| Factor | Weights |
|--------|---------|
| severity_weight | Critical=6, High=4, Medium=2, Low=1 |
| exploitability | 3 = EXT single tx; 2 = CAP/HOS/INT; 1 = ADM/CFG only |
| blast_radius | 3 = shared commons / all vaults; 2 = whole DETF family; 1 = single package |
| class_weight | CODE=1.0, BOTH=1.0, TEST=0.7, DOCS=0.4, OWNED_ELSEWHERE=0 (do not rank into `sec_fix_*`) |

Orchestrator sorts descending; ties break by CODE first, then shared commons, then confirmed runtime.

### 9.2 Residual-risk heatmap (aggregate)

Table: Product × residual risk 0–5 + worst open severity + OWNED_ELSEWHERE flag.

---

## 10. Relationship to prior documents

| Document | How Stage 1 uses it |
|----------|---------------------|
| `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` + `coverage-audit/**` | Seed I/J/K and PAT-I-ABS; **re-verify as vulns**; mark OWNED_ELSEWHERE when WP already exists |
| `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` | Do not schedule `sec_fix_*` on the same primary files as open `gap_cover_*` WPs |
| `ADVERSARIAL_VAULT_COVERAGE_*` | Historical A–H; add A0/L/M/N/O columns |
| `docs/reviews/2026-08-08_struct-audit_*` | Link; do not re-litigate structs unless they hide a money bug |
| `STRUCT_AUDIT_FIXES_PRD.md` | Product-law anchors remain; this program owns **new** security CODE not already in gap-closure |
| Family `*_PRD.md` + `docs/detf/*` | Spec corpus for `S-spec-detf` |
| Skills / `implementation-test-dod.md` | Normative bar for “closed” in Stage 3 |

**Supersession:**

- For **catalog completeness as tests**, coverage-audit + gap-closure remain SoT.
- For **newly identified exploitable CODE** (A0, E6, F5, L/M/N/O, CROPS leftover admin, spec-divergence, token/diamond defects) **not** already in the coverage backlog: **this program owns** the WP.
- If both programs flag the same file: **one owner**. Prefer the earlier `WP-I-*` if it already describes the CODE fix; this audit adds attack-scenario evidence and links.
- For **product economics / claim unwind / fee beneficiary / threshold exclusivity**, locked product PRDs win (`NEEDS_OWNER` if conflict).

---

## 11. Hard constraints (non-negotiable)

1. **No committed** product or permanent test-tree edits in Stage 1 (reports only under `docs/security/audit/`). Runtime proof and throwaway local repros are allowed per §3.8; do not leave PoC contracts or mainnet exploit scripts in the repo.
2. **`via_ir` forbidden** in any recommendation.
3. **No mock SUT** counted as proof that a vuln is absent.
4. **DETF role names** only in reports.
5. **Exact selectors** in recommended negatives — no bare `expectRevert()` as acceptance.
6. **Proxy vs facet**: J acceptance must specify **proxy** calls after registry/factory deploy.
7. **Delta vs absolute balance**: I acceptance must prove free-mint impossible when the vault already holds inventory.
8. **Real exploit → CODE first** in WP notes; do not plan green tests that assert buggy free mint as “expected” without `NEEDS_OWNER` + product decision.
9. Facets/DFPkgs: recommendations must use CREATE3 + registry paths, never `new` production facets.
10. **Incident corpus is reference only** — do not add HackLabs to `foundry.toml`.
11. **Pass = exploit blocked** (or bounded ACCEPTED_RISK). Never greenwash with attacker-profit asserts.
12. **Do not** start Stage 2 PRD authorship or Stage 3 worktrees under this PRD.

---

## 12. Definition of Done (Stage 1)

Stage 1 is complete when:

- [ ] `00_SCOPE_PARTITION.md` exists and was used for spawning.
- [ ] Every planned product area is `COMPLETE` or `PARTIAL`/`FAILED` with reason.
- [ ] Every planned specialist is `COMPLETE` or explicitly skipped with reason.
- [ ] Every area report validates against §7.2 sections 1–11.
- [ ] Every Critical/High finding validates against §7.3 (including attack scenario + attacker model).
- [ ] `AGGREGATE.md` includes §7.5 items 1–12.
- [ ] `WORK_PACKAGE_BACKLOG.md` has ranked WPs with full §8 fields for all Critical/High (Medium clustered OK) **plus** finding→WP index **plus** OWNED_ELSEWHERE table **plus** parallelism graph.
- [ ] At least one explicit finding or clean bill for **PAT-I-ABS** on shared pull commons, with **runtime** attempt per §3.8 / L-SEC-3 (may link coverage-audit `repro/TCA-COMMON-001/` if still valid at this SHA).
- [ ] At least one monorepo-level statement on **A0**, **E6/F5**, **J**, and **CROPS leftover admin**.
- [ ] Ship-blocking products (§19 L-SEC-2) all appear in area inventory (pilot + full).
- [ ] Adversarial-modeler notes exist for every remaining Critical CODE (or documented skip if none).
- [ ] No Stage 2/3 implementation or committed product/test fixes under this PRD.

---

## 13. Stage 2 planner requirements (handoff contract)

The agent writing `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` **shall**:

1. Treat `WORK_PACKAGE_BACKLOG.md` + `AGGREGATE.md` as **primary inputs**. Area/specialist reports are evidence, not a reason to re-hunt.
2. Follow [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](./PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md).
3. Expand WPs into an executable program: waves, worktree names (`sec_fix_*`), branch names, subagent prompts, merge order, verification commands.
4. Respect Wave 0 commons serialization and **OWNED_ELSEWHERE** (no second tree on `gap_cover_*` files).
5. Embed skills: `crane-testing`, `crane-adversarial-testing`, `indexedex-testing`, `indexedex-adversarial-testing`, DoD reference; plus the specialist skill that found each WP.
6. Require per-WP: production-first deploy, anti-theater checks, catalog test naming `test_<ID>_…`, pass = exploit blocked.
7. Not re-open product law settled in other PRDs without `NEEDS_OWNER` escalation.
8. Define final program acceptance: all Critical/High WPs owned by this program merged; `forge test` green on touched paths; deferred IDs in suite NatSpec; no known unbounded extract left greenwashed.
9. **Author a PRD that another orchestrator can execute with parallel subagents** — conflict-free slices, ≤3 concurrent worktrees unless explicitly raised, one worktree per package for CODE+tests on that package.
10. Not implement Stage 3 in the planning run.

*(Stage 2 plan is not authored in this PRD.)*

---

## 14. Stage 3 implementer requirements (handoff contract)

Implementers / implementation subagents **shall**:

1. Read the WP + linked `SEC-*` findings + DoD + applicable skills before coding.
2. Use worktree/branch names prefixed with **`sec_fix_`** (L-SEC-8).
3. Prefer **fix production CODE** when class is CODE/BOTH, then tests that would have failed before the fix.
4. Never greenwash free mint / unbounded extract.
5. Use gold TestBases and registry deploy paths; fork tests via Alchemy `rpc_endpoints` aliases (L-SEC-6).
6. Add I1–I3 / J1–J3 / A0 / E6 / applicable L/M/N/O when the WP touches those surfaces.
7. Leave unrelated products untouched.
8. Run WP acceptance forge commands and paste evidence in PR/worklog.
9. Seed `cache_forge/` + `out/` from a warm checkout before the first forge in a new worktree (`Claude.md` worktree compile seed).

*(Stage 3 execution is not authorized by this PRD alone.)*

---

## 15. Pilot first (locked), then full pass

Stage 1 **shall not** start the full area partition until pilot exit criteria pass (unless the user explicitly overrides).

### 15.1 Pilot set (mandatory)

| ID | Why |
|----|-----|
| `A-commons-pull` | PAT-I-ABS / I / K epicenter; unblocks all vaults |
| `A-detf-multi-vault` | Gold DETF money path; A0/D/G/I/J; spec + claim |
| `A-se-amm-v2` | High-traffic SE + AMM L/B + pretransfer |
| `S-sharp-edges` | PkgArgs / `pretransferred` defaults |
| `S-crops-trust` | Unowned DETF + manager/fee powers (may be thin if registry out of pilot paths) |

**Parallelism:** spawn the **3** area agents together; spawn the **2** specialists as soon as inventories exist (or in the same wave if they can work from path allowlists alone).

### 15.2 Pilot exit criteria

- [ ] Three area reports match §7.2
- [ ] Two specialist reports match §7.4
- [ ] Thin `AGGREGATE.md` + sample `WORK_PACKAGE_BACKLOG.md` (≥5 real WPs **or** explicit clean bill, including any Critical)
- [ ] Schema issues fixed before full spawn
- [ ] At least one **runtime** attempt on the top Critical/PAT-I-ABS candidate (success, BUILD_BLOCKED, or valid link to existing `repro/TCA-COMMON-001/` **re-checked at current SHA**)
- [ ] User notified (or pre-authorized auto-continue)

### 15.3 Full pass

After pilot exit: remaining §4.1 areas + remaining §3.5 specialists, then adversarial-modeler on Critical/High CODE, then full aggregate.

Recommended waves:

| Wave | Agents |
|------|--------|
| F1 | `A-detf-single-se`, `A-detf-composed-stable`, `A-detf-dual-liquidity` |
| F2 | `A-se-v3-v4-lending`, `A-hooks-v4`, `A-manager-fee-registry`, `A-routers-permit2` |
| F3 | Remaining specialists (`S-spec-detf`, `S-token-weird`, `S-amm-oracle-flash`, `S-diamond-proxy`, `S-signatures`, `S-incidents`, `S-evm-general`) |
| F4 | `S-adv-modeler` per Critical/High CODE |

---

## 16. Risks

| Risk | Mitigation |
|------|------------|
| Re-doing coverage-audit | Mandatory OWNED_ELSEWHERE + TCA link; different finding prefix `SEC-*` |
| `gap_cover_*` and `sec_fix_*` collide | L-SEC-4; Stage 2 must skip owned touch-sets |
| Generic evm-audit noise | Skills are hunt lists; ship-gate stays Crane DoD |
| Incident PoCs treated as tests | Hard boundary in `defi-incident-patterns`; no HackLabs remappings |
| Area overlap on shared commons | Commons owned by `A-commons-pull`; others reference |
| Reviewers mark “safe” from facet-only tests | J bar requires proxy |
| Scope explosion into full formal audit | Severity cap; P2 DEFER; time box PARTIAL |
| Compile broken → no forge | Static mapping still required; mark BUILD_BLOCKED |
| Stage 1 starts implementing fixes | Explicit non-goal; orchestrator rejects committed code diffs |
| Forge killed mid-compile | Claude.md forge patience; hour-scale timeouts |
| Fork RPC unavailable | L-SEC-6; else BUILD_BLOCKED / RUNTIME_UNPROVEN |
| Spec specialist invents law | Quote PRD/agent law or mark AMBIGUOUS / NEEDS_OWNER |

---

## 17. Revision history

| Date | Change |
|------|--------|
| 2026-08-13 | Initial PRD: Stage 1 security audit program using newly installed audit / adversarial / CROPS / sharp-edges / spec-compliance / incident skills; multi-stage handoff to a parallel remediation PRD |

---

## 18. Quick links for agents

| Need | Open |
|------|------|
| This process law | `docs/security/SECURITY_AUDIT_PRD.md` |
| Orchestrator steps | `docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md` |
| Stage 2 planner prompt | `docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md` |
| Adversarial method | `lib/crane/.claude/skills/crane-adversarial-testing/` |
| Ship-gate checklist | `…/references/implementation-test-dod.md` |
| DETF adversarial | `.claude/skills/indexedex-adversarial-testing/` |
| Incident map | `.claude/skills/defi-incident-patterns/` |
| EVM-audit router | `.grok/skills/ethskills-audit/SKILL.md` (or `.claude` mirror) |
| Agent law | `docs/agent/INDEXEDEX_AGENT_LAW.md` |
| Coverage-audit (do not compete) | `docs/testing/coverage-audit/AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` |
| Gold adversarial suite | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/` |

---

## 19. Locked decisions (2026-08-13)

Product-owner defaults for Stages 1–3. Change only with an explicit user override.

| ID | Decision | Implication |
|----|----------|-------------|
| **L-SEC-1** | **Pilot first**, then full monorepo partition | §15 is mandatory; full spawn only after pilot exit (unless user overrides) |
| **L-SEC-2** | **Ship-blocking set = all money products** under `contracts/` vaults, DETFs, SE packages, hooks, and production routers that move user funds | Critical/High on any of these cannot be DEFER’d as “not launch set” |
| **L-SEC-3** | **Runtime proof required for Critical CODE** | §3.8; static-only → max High + `RUNTIME_UNPROVEN` if unproven |
| **L-SEC-4** | **Do not compete with coverage-audit / gap-closure on the same primary files** | Link `TCA-*` / `WP-I-*`; class OWNED_ELSEWHERE; `sec_fix_*` skips those touch-sets |
| **L-SEC-5** | **Fork coverage/security gaps have equal priority to hermetic** when the product’s gold path is fork-first | DualLiquidity (and similar) missing fork P0 is still High/Critical, not automatically Medium |
| **L-SEC-6** | **Fork RPC: prefer Alchemy aliases from `foundry.toml`** | `[rpc_endpoints]` names ending in `_alchemy`; `ALCHEMY_KEY` in env; `FOUNDRY_PROFILE=fork` |
| **L-SEC-7** | **Repro logs allowed under `docs/security/audit/repro/`** | Commands, forge logs, balance dumps, short notes. No secrets. No mainnet exploit scripts |
| **L-SEC-8** | **Branch / worktree prefix `sec_fix_`** | Distinct from `gap_cover_`. WP “Suggested worktree” must use this prefix |
| **L-SEC-9** | **Catalog SoT is Crane A–K + A0/L/M/N/O + E6/F5** | Do not renumber A–K. EVM-audit domains are hunt lists, not a second ID space |
| **L-SEC-10** | **Pass criteria = exploit blocked** (or ACCEPTED_RISK with invariants) | Never treat fork attacker-profit asserts as coverage |
| **L-SEC-11** | **DETF instances are unowned/immutable after deploy** | Leftover `diamondCut` / owner / operator on a live DETF is at least High (CROPS + F) unless product law says otherwise |
| **L-SEC-12** | **Stage 3 concurrency ≤ 3** `sec_fix_*` worktrees unless the remediation PRD raises it | Same spirit as L-GAPS-4 |
| **L-SEC-13** | **One worktree per package** for that package’s CODE+TEST WPs | Collapse I+J+A0+… for one package into one tree after Wave 0 |
| **L-SEC-14** | **No `via_ir`** | No package-specific IR profiles |

### 19.1 Fork commands (guidance)

```bash
# Ensure ALCHEMY_KEY is set in the environment (not committed).
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**' \
  --fork-url base_mainnet_alchemy -vv
```

Use the chain-appropriate `*_alchemy` alias from `foundry.toml`. Do not invent hardcoded Alchemy URLs in reports.

**Still open (non-blocking):** exact Stage 2 remediation PRD filename freeze when planner starts (default remains `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md`).
