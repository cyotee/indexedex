# Agent prompt — Author the Security Audit Remediation PRD from Stage 1 reports

> **How to use:** Open this file as the sole task prompt for a **planning** agent **after** Stage 1 `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` are accepted.  
> **Repo root:** IndexedEx (`lib/indexedex`).  
> **Kind:** Planning / product-law document only. **Do not implement production or test code in this run.**

---

## Mission

Read the **Stage 1 Security Audit** outputs (decision-grade findings + ranked work-package backlog). Then write a **PRD** that authorizes and constrains the **remediation program**: production CODE where class is CODE/BOTH, and production-first Foundry tests where class is TEST/THEATER.

The PRD must be executable by a **later orchestrator** that runs remediations **in parallel** using subagents and `sec_fix_*` worktrees — the same shape as `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md`, but owned by this security program.

**Primary output path (create):**

```text
docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md
```

**Optional companion (only after the PRD is complete and self-consistent):**

```text
docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md
```

Prefer finishing the **PRD** first. Do not skip PRD quality for a shallow plan.

---

## Hard rules (non-negotiable)

1. **No committed production `*.sol` edits** and **no permanent `test/**` suite implementation** in this agent run. PRD (and optional plan) under `docs/security/**` only.
2. **Never recommend `via_ir`.** Never count MockStandardExchange / `vm.mockCall` on SUT as closed.
3. **DETF role names only:** `rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / `reserveBpt`, `rebasingClaimToken`.
4. **Deploy bar:** facets via CREATE3 / FactoryService; vault/DETF DFPkgs via **IndexedEx manager vault registry**. Never recommend `new` production facets/DFPkgs on user paths.
5. **Wave 0 serial:** shared commons CODE (pull/delta, shared errors, leftover admin strip) lands **before** parallel product suites that depend on fixed semantics.
6. **Worktree / branch prefix:** `sec_fix_` (L-SEC-8). Every WP worktree/branch in the PRD must use this prefix.
7. **Do not collide with `gap_cover_*`.** Any WP marked **OWNED_ELSEWHERE** (linked `TCA-*` / `WP-I-*`) is **out of this program’s Stage 3**. Say so in the PRD. Do not open a second tree on the same primary files.
8. **Critical CODE:** require runtime proof before calling free-mint / unbounded extract “closed.” Stage 1 findings labeled `RUNTIME_UNPROVEN` must include a **proof-first** task.
9. **Anti-theater:** happy-path `pretransferred=true` with real transfer is **not** I1–I3. J acceptance must call the **proxy**. Pass = **exploit blocked** (L-SEC-10).
10. **Ship-blocking:** all money products remain in scope (L-SEC-2).
11. **Fork P0 = hermetic severity** (L-SEC-5). Prefer `*_alchemy` + `ALCHEMY_KEY` (L-SEC-6).
12. **Concurrency ≤ 3** live `sec_fix_*` worktrees (L-SEC-12) unless you explicitly raise it with a reason.
13. **One worktree per package** for that package’s CODE+TEST WPs after Wave 0 (L-SEC-13).
14. Do **not** open `sec_fix_*` or `gap_cover_*` worktrees or implement Stage 3 in this run.
15. Do **not** re-audit the monorepo. If Stage 1 is incomplete, list missing inputs and stop — do not invent findings.

---

## Required reading order (do not skip)

### A. Stage 1 law

| Order | Path | Why |
|------:|------|-----|
| 1 | `docs/security/SECURITY_AUDIT_PRD.md` | Normative bar, finding/WP schemas, locks **L-SEC-1…14**, Stage 2/3 handoff §§13–14 |
| 2 | `docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md` | What Stage 1 produced |
| 3 | `Claude.md` + `docs/agent/INDEXEDEX_AGENT_LAW.md` (DETF/deploy if needed) | Non-negotiables |

### B. Stage 1 outputs (source of truth for remediations)

| Order | Path | Why |
|------:|------|-----|
| 4 | `docs/security/audit/AGGREGATE.md` | Heatmap, matrices, Critical list, wave sketch, §12 DoD |
| 5 | `docs/security/audit/WORK_PACKAGE_BACKLOG.md` | **Primary WP inventory** + finding→WP index + OWNED_ELSEWHERE + parallelism graph |
| 6 | `docs/security/audit/PILOT_EXIT.md` | Pilot gate + runtime proof summary |
| 7 | `docs/security/audit/00_SCOPE_PARTITION.md` | Product ownership by area |
| 8 | `docs/security/audit/repro/**` | Runtime evidence for Criticals |

### C. Area / specialist reports (deep dive as needed)

Read fully for every product with Critical or High **CODE** that is **not** OWNED_ELSEWHERE. Skim the rest.

### D. Coverage-audit (collision map)

| Order | Path | Why |
|------:|------|-----|
| last | `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` | Confirm OWNED_ELSEWHERE; do not schedule `sec_fix_*` on those touch-sets |
| last | `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md` | Wave-0 commons may already be in flight (`gap_cover_*`) — serialize or skip |

### E. Skills (for acceptance language, not new hunting)

`crane-adversarial-testing` + `implementation-test-dod.md`, `indexedex-adversarial-testing`, `crane-testing`, `indexedex-testing`.

---

## What the Remediation PRD must contain

Mirror the quality of `docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md`. Minimum sections:

1. **Header table** — status READY-FOR-IMPLEMENTATION; depends on Stage 1 paths; locks L-SEC-* reaffirmed; worktree prefix `sec_fix_`; concurrency ≤ 3.
2. **Intent & success** — success is **not** “tests green on a still-exploitable path.”
3. **Imported security bar** — do not weaken Stage 1 §2. Restate I / J / A0 / E6 / F5 / L/M/N/O close criteria that WPs actually touch.
4. **Locked product law** — inherit L-CLAIM-3 / L-GAPS-9 delta credit; L-SEC-11 unowned DETF; seigniorage ACCEPTED_RISK bounds. Do not re-decide.
5. **Normative WP inventory** — every Critical/High `WP-SEC-*` from the backlog. You may refine acceptance language; you **must not** drop a Critical/High without explicit DEFER + severity-preserving reason.
6. **OWNED_ELSEWHERE appendix** — table `SEC-*` → `WP-I-*` / `TCA-*` → “handled by gap-closure, not this program.”
7. **Waves + DAG**
   - Wave 0 serial commons
   - Then **conflict-free package slices** (one worktree per package)
   - Explicit `Depends on` / `Parallelizable with`
8. **Parallel execution law for the Stage 3 orchestrator**
   - How to spawn subagents (prompt skeleton per WP)
   - Merge order (rebase + fast-forward linear `main` if that is repo practice)
   - What to do on BUILD_BLOCKED / red forge
   - Seed `cache_forge/` + `out/` before first forge in a new worktree
9. **Per-WP acceptance** — exact `forge test --match-path` / `--match-test`, required `test_<ID>_` names, anti-theater checks, proof-first flag.
10. **Program DoD** — all this-program Critical/High WPs merged; touched paths green; no unbounded extract greenwashed; deferred IDs in suite NatSpec.
11. **Non-goals** — no re-audit; no competing I/J WPs already in gap-closure; no frontend; no `via_ir`.

---

## Parallelism design rules (must appear in the PRD)

| Rule | Detail |
|------|--------|
| Same Common / Facet / error file | **Serial** or one WP |
| Different package dirs + different test dirs | **Parallel** after Wave 0 API freeze |
| OWNED_ELSEWHERE | **Skip** in Stage 3 of this program |
| Proof-first Critical | Red test or throwaway repro **before** claiming CODE closed |
| Live children | **≤ 3** `sec_fix_*` worktrees |
| Naming | worktree `sec_fix_<slice>`, branch `sec_fix/<slice>` or `sec_fix_<slice>` |

Produce a **slice table** the Stage 3 orchestrator can spawn from:

| Slice / worktree | WPs included | Production touch-set | Test touch-set | Depends on | Wave |
|------------------|--------------|----------------------|----------------|------------|------|

If two WPs share a file, they **must** sit in the same slice or be ordered.

---

## Suggested PRD filename locks (unless Stage 1 leftover says otherwise)

| File | Role |
|------|------|
| `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` | This document |
| `docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md` | Stage 3 execute plan (optional in this run) |

---

## Self-check before finishing

- [ ] Every Stage 1 Critical/High `SEC-*` is either a `WP-SEC-*` in the PRD, OWNED_ELSEWHERE, or explicitly DEFER’d with reason
- [ ] No `sec_fix_*` slice overlaps a primary file of an open `gap_cover_*` WP
- [ ] Wave 0 is serial; later slices are conflict-free
- [ ] Each slice has acceptance forge commands and anti-theater checks
- [ ] DETF role names only; no `via_ir`; registry/CREATE3 deploy bar
- [ ] No production or test code was edited in this run
- [ ] A Stage 3 orchestrator can spawn slices from the slice table without re-reading the whole monorepo

When done, tell the user the PRD path, Critical/High WP counts, how many were OWNED_ELSEWHERE, and the proposed Wave 0 → Wave 1 parallel sets. **Do not start Stage 3.**
