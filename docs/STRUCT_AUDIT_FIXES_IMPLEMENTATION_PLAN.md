# Struct-Audit Fixes — Implementation Plan

> **For agentic workers:** This plan implements [`docs/STRUCT_AUDIT_FIXES_PRD.md`](./STRUCT_AUDIT_FIXES_PRD.md) using **git worktrees + parallel subagents**, then **orchestrator-driven rebases onto `main`** so the final history is **linear** (one commit series on `main`, no long-lived merge bubbles).

| Field | Value |
|-------|--------|
| **Status** | DRAFT — ready to execute |
| **PRD** | [`docs/STRUCT_AUDIT_FIXES_PRD.md`](./STRUCT_AUDIT_FIXES_PRD.md) (normative product law) |
| **Review inputs** | `docs/reviews/2026-08-08_struct-audit_*.md` (IDs; superseded where PRD §2/§3 conflicts) |
| **Repo root** | IndexedEx workspace (`lib/indexedex`) |
| **Base branch** | `main` (always rebase onto latest `origin/main` before land) |
| **Hard gates** | Default `forge build` green; package tests green; **no `via_ir`**; production-first tests; DETF role names |

---

## 0. Intent

Deliver Wave A (correctness + diamond surface + compile) and Wave B (shared structs, dead members, branding) as a **linear commit stack on `main`**, built in parallel where file ownership does not conflict.

**Success:** PRD AC1–AC12 satisfied; `main` history is a straight line of rebased commits (or a single rebased PR stack), not a fan-in of unbased merge commits.

---

## 1. Orchestration model

### 1.1 Roles

| Role | Who | Responsibilities |
|------|-----|------------------|
| **Orchestrator** | Parent agent (human-supervised) | Partition waves; create worktrees; spawn subagents; collect results; **rebase** each branch onto current `main`; run integration gates; land commits in order; resolve conflicts |
| **Worker subagent** | One per worktree / branch | Implement **only** its task allowlist; commit on its branch; run **its** scoped tests; never push force to `main`; never edit out-of-allowlist paths |
| **Verifier (optional)** | Separate subagent or orchestrator | After each land (or each wave), re-run compile + cross-cutting tests |

### 1.2 Parallelism rules

1. **Parallel only inside a declared parallel set** (§3.2). Each set has **pairwise-disjoint exclusive write sets** (§3.1).
2. **Exclusive write** means: no other concurrent task may modify that path. Read-only of others’ files is allowed.
3. **Tests:** workers may **only** create/edit `test/foundry/spec/saf/TXX_*.t.sol` (and matching TestBase under `test/foundry/spec/saf/` if needed). **Do not** edit shared gold TestBases in parallel waves (avoids test-file merge wars). Orchestrator may later move tests if desired.
4. Max concurrent workers: **3** for Wave A1 / A3 / B.
5. If a worker needs an out-of-set file → **BLOCKED**; orchestrator re-partitions or serializes.
6. Workers **must not** merge to `main`. Only the orchestrator lands history.
7. Rebase-before-land means even sequential tasks that touch related areas rarely “merge conflict” if exclusive sets held during parallel work; conflicts are limited to intentional sequential edits of the same file across waves (e.g. T01 then T05 on Facet) — git applies cleanly when changes are non-overlapping hunks; if not, orchestrator resolves once at rebase.

### 1.3 Worktree layout

Create worktrees under a sibling directory (do not nest inside dirty monorepo clones of Crane submodules unnecessarily):

```text
# From repo root (indexedex)
REPO=$(pwd)
WT_ROOT="${REPO}/../indexedex-worktrees/struct-audit-fixes"
mkdir -p "$WT_ROOT"

# Naming: wt-<task-id>
# Branch: fix/saf-<task-id>-<slug>
```

Example:

| Task | Branch | Worktree path |
|------|--------|----------------|
| T01 | `fix/saf-t01-facets` | `../indexedex-worktrees/struct-audit-fixes/wt-t01-facets` |
| T02 | `fix/saf-t02-claim-rewards` | `.../wt-t02-claim-rewards` |
| … | … | … |

**Create pattern:**

```bash
git fetch origin main
git worktree add -b fix/saf-t01-facets "$WT_ROOT/wt-t01-facets" origin/main
```

**Remove after land:**

```bash
git worktree remove "$WT_ROOT/wt-t01-facets"
git branch -d fix/saf-t01-facets   # after squash/rebase land
```

### 1.4 Linear history protocol (orchestrator mandatory)

After a worker marks a task **DONE** (commit(s) on its branch + scoped tests green):

```text
1. git fetch origin main
2. cd <worktree>
3. git rebase origin/main
   - On conflict: orchestrator resolves (or respawns worker with conflict files only)
4. Re-run scoped tests + default forge build (or package compile gate) in worktree
5. Land onto main with ONE of:
   A) Preferred for multi-agent: cherry-pick / rebase-onto main as a single commit series:
        git checkout main && git pull --ff-only
        git rebase --onto main <base> fix/saf-tXX   # or merge --ff-only after rebase
   B) FF-only merge after branch is rebased:
        git checkout main
        git merge --ff-only fix/saf-tXX
6. git push origin main   # only if remote land authorized; else leave local main linear
7. Delete worktree + branch
8. All later workers that still run: orchestrator may leave them; before their land they
   MUST rebase onto the NEW main (step 1–4 again)
```

**Forbidden land methods:**

- `git merge` of an **unrebased** feature branch into `main` (creates merge commits / non-linear history)
- Landing two parallel branches without rebasing the second onto the first’s landed tip
- Force-push to `main`

**Commit message convention:**

```text
fix(saf-tXX): <short title>

PRD: docs/STRUCT_AUDIT_FIXES_PRD.md (WP-A# / WP-B#)
Law: L-...
Tests: <forge test filters run>
```

### 1.5 Subagent prompt skeleton

Every worker prompt includes:

```text
HARD RULES:
1. Work ONLY in this worktree: {WT_PATH}
2. Branch: {BRANCH} (already created from origin/main at task start)
3. Path allowlist: {ALLOWLIST}. Do not edit other paths.
4. Read docs/STRUCT_AUDIT_FIXES_PRD.md §2 product law for your task.
5. No via_ir. Stack fixes = structs/helpers/scopes only.
6. Production-first tests; no SUT mocks.
7. DETF role names only; no product brands in new code.
8. Commit on your branch only. Do NOT merge to main. Do NOT push main.
9. When done: report (a) commit SHAs (b) files changed (c) test commands + results
   (d) residual risks. Status DONE | BLOCKED | PARTIAL.
10. If you need an out-of-allowlist change, STOP and report BLOCKED (orchestrator re-partitions).
```

Use `spawn_subagent` with:

- `subagent_type`: `general-purpose` (needs write + forge)
- `isolation`: prefer **`worktree`** if the host creates an isolated worktree; **or** set `cwd` to the pre-created `$WT_PATH`
- `capability_mode`: `all` or `execute` (needs forge test)
- `description`: `saf {TASK_ID} {slug}`

If the host’s `isolation=worktree` already creates a worktree, **do not double-create**; use the returned worktree path and still apply the **rebase-onto-main** land protocol on that branch.

---

## 2. Dependency graph (DAG)

```text
                    ┌─────────────┐
                    │ T00 baseline│
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
      ┌────────┐     ┌──────────┐    ┌──────────┐
      │ T01    │     │ T02      │    │ T03      │   WAVE A1  ∥  DISJOINT
      │ facets │     │ claimRw  │    │ pretrans │
      └────────┘     └──────────┘    └──────────┘
                          │
                          ▼ land T01→T02→T03
                    ┌──────────┐
                    │ T04      │   WAVE A2  serial (claimToken + unwind)
                    │ unwind   │
                    └────┬─────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
     ┌────────┐    ┌──────────┐   ┌──────────┐
     │ T05    │    │ T06a CP  │   │ T08 hook │  WAVE A3  ∥  DISJOINT
     │ bond   │    │ fee only │   │ stack    │
     │ sold+  │    │          │   │ (or early)│
     │ realloc│    └──────────┘   └──────────┘
     └────┬───┘
          ▼ land T05 → T06a → T08
     ┌──────────┐
     │ T06b     │   WAVE A3b serial — orbital/weighted preview+fee
     │ preview  │   (Bonding already done in T02; Exchange* only)
     └────┬─────┘
          ▼
     ┌──────────┐
     │ T07      │   WAVE A3c — tests only (minOut); no product file overlap
     │ minOut   │
     └────┬─────┘
          ▼
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     ┌────────┐   ┌──────────┐  ┌──────────┐
     │ T09    │   │ T10      │  │ T11      │  WAVE B  ∥  DISJOINT
     │ MintSp │   │ harvest  │  │ brand    │
     │ Commons│   │ + hook   │  │ factory  │
     │        │   │ flex dead│  │          │
     └────────┘   └──────────┘  └──────────┘
          ▼
     ┌──────────┐
     │ T12 gate │
     └──────────┘
```

**Land order on `main` (linear):**

```text
T01 → T02 → T03 → T04 → T05 → T06a → T08 → T06b → T07 → T09 → T10 → T11 → T12
```

(If T08 was started in Wave 0/A1 because build was red, land it as soon as green and rebased — insert into the line without breaking FF order of remaining tasks.)

---

## 3. Conflict-free ownership (normative)

### 3.1 Design guarantee

| Parallel set | Tasks | Guarantee |
|--------------|-------|-----------|
| **Wave A1** | T01 ∥ T02 ∥ T03 | **No shared write files** (see exclusive lists below) |
| **Wave A3** | T05 ∥ T06a ∥ T08 | **No shared write files** |
| **Wave B** | T09 ∥ T10 ∥ T11 | **No shared write files** |
| **Serial** | T04, T06b, T07 | May touch files prior tasks own; **start worktree from post-prior `main` only** — not parallel with their dependents |

**Why this avoids end-of-program merge hell:** parallel branches never edit the same path, so when the second branch rebases onto `main` after the first lands, git has **nothing to conflict** on (empty rebase for disjoint files). Sequential tasks may touch related areas but land one-at-a-time with a single rebase each.

### 3.2 Exclusive write sets (authoritative)

**Convention:** `+` = may write; all other contract paths = **forbidden** for that task. Tests only under `test/foundry/spec/saf/TXX_*.t.sol`.

#### Wave A1 — parallel (disjoint)

| Path | T01 | T02 | T03 |
|------|:---:|:---:|:---:|
| `contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol` | + | | |
| `contracts/vaults/detf/common/claimToken/RebasingClaimTokenFacet.sol` | + | | |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVaultFacet.sol` | + | | |
| Other `*BondNFT*Facet.sol` / `*Claim*Facet.sol` under detf if discovered as clones | + | | |
| `contracts/interfaces/IDETFNFTVault.sol` | **read-only in A1** | | |
| Uni V4 `*BondingTarget.sol` (orbital, weighted, CP-single, listing single) | | + | |
| Uni V4 DETF interfaces only if claimRewards signature docs require | | + | |
| `contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol` | | | + |
| `contracts/vaults/detf/common/claimToken/RebasingClaimTokenRepo.sol` | | | + |
| `test/foundry/spec/saf/T01_*.t.sol` | + | | |
| `test/foundry/spec/saf/T02_*.t.sol` | | + | |
| `test/foundry/spec/saf/T03_*.t.sol` | | | + |

**T01 must not** edit Target/Repo (only Facet selector lists).  
**T02 must not** edit claim token or bond NFT common Target (only DETF BondingTargets).  
**T03 must not** edit Facets or BondingTargets.

#### Wave A2 — serial

| Path | T04 only |
|------|----------|
| `RebasingClaimTokenTarget.sol` / `Repo.sol` (redeem, exchangeOut, rate paths) | + |
| `IRebasingClaimToken.sol` NatSpec/API if unwind needs it | + |
| DETF helpers **strictly required** for protocol-NFT LP unwind (document each file in commit) | + |
| `test/foundry/spec/saf/T04_*.t.sol` | + |
| **Forbidden:** Facet files (T01), BondingTarget claimRewards (T02 already landed), sold-flag deletion (T05) |

T04 **starts from `main` after T03 landed** (includes pretransfer). Fresh worktree — no parallel with A1 leftovers.

#### Wave A3 — parallel (disjoint)

| Path | T05 | T06a | T08 |
|------|:---:|:---:|:---:|
| Entire common bond NFT package: `DETFNFTVault{Target,Repo,Common,Service,Facet,DFPkg}.sol` | + | | |
| `contracts/interfaces/IDETFNFTVault.sol` | + | | |
| ComposedStable bond NFT Target/Repo/Common/Facet clones | + | | |
| Call sites of `markDETFNFTSold` only (delete calls) | + | | |
| **T05 also:** `nonReentrant` on `reallocateDetfNftRewards` (was WP-A8) | + | | |
| CP-single only: `.../constantProduct/single/*ExchangeOut*`, `*Common*` fee/burn helpers as needed | | + | |
| CP-single interfaces if fee API docs | | + | |
| `contracts/hooks/.../orbital/*` Target/Math stack fixes only | | | + |
| `test/foundry/spec/saf/T05_*.t.sol` | + | | |
| `test/foundry/spec/saf/T06a_*.t.sol` | | + | |
| `test/foundry/spec/saf/T08_*.t.sol` | | | + |

**Not parallel with T05:** anything else that writes bond NFT Target (T07 realloc removed from parallel).

#### Wave A3b — serial after T05 + T06a

| Path | T06b |
|------|------|
| Orbital + weighted `*ExchangeInTarget.sol`, `*ExchangeOutTarget.sol`, Common fee/preview helpers | + |
| **Not** `*BondingTarget.sol` (T02 owns claimRewards already on main) unless fee helper is only there — prefer Exchange paths |
| Hook orbital feeWad single-source **only if** not done in T08; prefer T06b for fee wiring, T08 for stack-only | document split |
| `test/foundry/spec/saf/T06b_*.t.sol` | + |

#### Wave A3c — serial (tests only)

| Path | T07 |
|------|------|
| `test/foundry/spec/saf/T07_*.t.sol` only — final minOut behavior | + |
| **No** production Solidity writes | |

#### Wave B — parallel (disjoint)

| Path | T09 | T10 | T11 |
|------|:---:|:---:|:---:|
| New shared type under `contracts/vaults/detf/common/core/` (e.g. `DETFMintSplit.sol` or existing lib) | + | | |
| Files that **define** `struct MintSplit` (replace with import) — Uni V4 + Balancer `*Common.sol` / libs listed by `rg` | + | | |
| `DETFNFTVaultService.sol` harvest/redeem struct shrink | | + | |
| Harvest **call-site** field init in `DETFNFTVaultTarget.sol` **only** struct field removals (not sold/realloc) | | + | |
| Hook `WithdrawFlexibleVars` dead fields under orbital Target | | + | |
| `DetfComponentFactoryService.sol` renames, SVG/comments brand strip in bond/claim | | | + |
| `test/foundry/spec/saf/T09_*.t.sol` / `T10_*.t.sol` / `T11_*.t.sol` | + | + | + |

**T09 vs T10:** T09 does **not** edit `DETFNFTVaultService.sol` or orbital hook Target. T10 does **not** edit MintSplit-bearing Commons.  
**T10 vs T05:** T10 runs only after T05 landed — sequential waves, not parallel.

### 3.3 Orchestrator pre-spawn check (mandatory)

Before starting a parallel wave:

```bash
# Example Wave A1: assert allowlist files are unique across tasks
comm -12 <(sort t01_files.txt) <(sort t02_files.txt)   # must be empty
# repeat for each pair
```

If non-empty → **do not spawn**; fix partition.

### 3.4 Residual conflict risk (honest)

| Risk | Residual? | Mitigation |
|------|-----------|------------|
| Wave A1 three-way | **None** if exclusive table followed | Facet vs Bonding vs ClaimToken |
| Wave A3 T05/T06a/T08 | **None** | bond vs CP-single vs hooks |
| Wave B T09/T10/T11 | **None** if T09 skips Service/hook Target | table above |
| T01 then T05 both touch Facet | Sequential rebase only | T05 deletes sold selectors; T01 may have added views — same file, **different lines** usually auto-merge; orchestrator fixes if not |
| T03 then T04 both touch claim Target | Sequential | T04 worktree from post-T03 main |
| T02 then T06b Bonding vs Exchange | Disjoint if T06b stays on Exchange* | enforce allowlist |
| Shared TestBase edits | Eliminated | task-local `test/foundry/spec/saf/TXX_*` only |

**Bottom line:** Parallel work is partitioned so **simultaneous** branches do not share write paths. End-of-line “merge conflicts” should not appear for parallel sets; only **sequential** same-file edits (T01→T05 Facet, T03→T04 claim Target) can conflict, and those are single-file rebases the orchestrator handles once.

---

## 4. Task catalog

### T00 — Baseline (orchestrator only)

| | |
|--|--|
| **Branch / WT** | none (main checkout or temp wt) |
| **Steps** | `git fetch origin main && git checkout main && git pull --ff-only` |
| | Record: `forge build` result (pass/fail + first stack error if any) → note for T08 priority |
| | List dirty tree; refuse to start if unrelated WIP risks land confusion (stash or separate branch) |
| **Done** | Baseline note written to scratch or `docs/reviews/` optional `2026-08-09_saf_baseline.md` |

If baseline `forge build` is **red**, **start T08 in parallel with Wave A1** on a dedicated worktree; land T08 as soon as green **before or immediately after T01** if other PRs cannot compile.

---

### T01 — Facet selector parity (WP-A1) · CRITICAL

| | |
|--|--|
| **Branch** | `fix/saf-t01-facets` |
| **Allowlist** | `contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol`, `.../claimToken/*Facet*`, `contracts/interfaces/IDETFNFTVault.sol` / claim interfaces **only if** needed for selectors, ComposedStable `*BondNFTVaultFacet.sol`, `test/foundry/**` new diamond surface tests |
| **Do** | Diff Target externals vs `facetFuncs`; add missing selectors; diamond tests for `lockInfoOf`, `rewardPerShares`, claim `updateRedemptionRate`, etc. **Do not** re-add sold APIs if already removed on main — if still present, register only APIs that remain product-valid (sold APIs removed in T05) |
| **Tests** | Hermetic tests calling **diamond** address; production DFPkg deploy path |
| **Land order** | 1st (or 2nd if T08 must land first for compile) |

**Subagent focus:** Crane facet cut completeness; no product logic changes.

---

### T02 — claimRewards auth + no try/catch (WP-A5)

| | |
|--|--|
| **Branch** | `fix/saf-t02-claim-rewards` |
| **Allowlist** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/**/*Bonding*.sol`, peer DETF claimRewards sites under uniswap v4, matching tests |
| **Do** | Owner-only revert; remove try/catch soft success; return 0 only if allowed and zero rewards |
| **Tests** | non-owner reverts; owner zero rewards; owner with rewards amount == transferred |
| **Parallel with** | T01, T03 **if** T03 not editing same Bonding files (T03 is claim token — OK parallel) |
| **Land order** | after T01 |

---

### T03 — Pretransfer balance proof (WP-A2)

| | |
|--|--|
| **Branch** | `fix/saf-t03-pretransfer` |
| **Allowlist** | `contracts/vaults/detf/common/claimToken/**`, related interface NatSpec, tests |
| **Do** | last-balance / delta check on `pretransferred=true`; update last balance; negative abuse tests |
| **Parallel with** | T01, T02 |
| **Land order** | after T02 (or after T01 if T02 delayed — must be before T04) |
| **Note** | If T04 will rewrite redeem path heavily, keep T03 commits small and well-tested so T04 rebases cleanly |

---

### T04 — Claim redeem unwind (WP-A3) · LARGEST

| | |
|--|--|
| **Branch** | `fix/saf-t04-claim-unwind` |
| **Allowlist** | claim token redeem/exchange, DETF-side helpers needed for protocol NFT LP unwind, `IRebasingClaimToken` NatSpec, inventory/bond call path under common + uniswap v4 as required, tests |
| **Do** | Unwind LP under protocol NFT bond; no idle rateAsset inventory model; solvency tests |
| **Parallel with** | **None** (serial). Orchestrator may pre-read design while Wave A1 runs |
| **Land order** | after T03 |
| **Design gate** | Before coding, worker writes a short design note in the PR/commit body: call sequence `redeem → bond NFT / DETF → LP out → rateAsset to user`. Orchestrator reviews once if multi-family |

---

### T05 — Retire protocol-sold + realloc lock (WP-A4, WP-A8)

| | |
|--|--|
| **Branch** | `fix/saf-t05-retire-sold` |
| **Allowlist** | **Exclusive:** entire common bond NFT package + interface + ComposedStable bond clones + `markDETFNFTSold` call sites; `test/foundry/spec/saf/T05_*.t.sol` |
| **Do** | Delete sold flag/API/error/event/storage (pre-launch); keep user `sellPositionToDetfNft`; **`nonReentrant` on `reallocateDetfNftRewards`**; update NatSpec |
| **Parallel with** | T06a, T08 only (Wave A3) |
| **Land order** | after T04 |

---

### T06a — CP-single burn fee only (WP-A6 partial)

| | |
|--|--|
| **Branch** | `fix/saf-t06a-cp-burn-fee` |
| **Allowlist** | **Exclusive:** `.../constantProduct/single/**` only (ExchangeOut, Common, tests T06a) |
| **Do** | Usage fee on withdraw/burn → mint shares to `feeTo()`; CP previews include fee |
| **Parallel with** | T05, T08 |
| **Land order** | after T05 |

### T06b — Orbital/weighted fee + preview parity (WP-A6 rest)

| | |
|--|--|
| **Branch** | `fix/saf-t06b-preview-parity` |
| **Allowlist** | **Exclusive:** orbital + weighted `*ExchangeIn*`, `*ExchangeOut*`, Common fee/preview helpers; **not** `*BondingTarget.sol` |
| **Do** | Fee single-source; preview ≡ execute (incl. SE passthrough or drop route) |
| **Parallel with** | **None** (serial after T06a) |
| **Land order** | after T06a (and T08 if T08 already landed) |

---

### T07 — Final minOut tests only (WP-A7)

| | |
|--|--|
| **Branch** | `fix/saf-t07-minout-tests` |
| **Allowlist** | **`test/foundry/spec/saf/T07_*.t.sol` only** — no production Solidity |
| **Do** | Encode L-PREV-2: final minOut before recipient transfer; intermediate legs free |
| **Parallel with** | none required |
| **Land order** | after T06b |

---

### T08 — Default forge build / stack (WP-A9)

| | |
|--|--|
| **Branch** | `fix/saf-t08-stack-build` |
| **Allowlist** | SE Orbital buffer hook Target/Math and minimal call-chain helpers under `contracts/hooks/uniswap/v4/standardExchange/orbital/**` |
| **Do** | Green default `forge build` without `via_ir`; keep stack-critical structs |
| **Parallel with** | Wave A1 from the start if baseline red; else after Wave A3 |
| **Land order** | as soon as green and rebased — **must be on main before declaring program done**; prefer early if blocking CI |

---

### T09 — Shared MintSplit (WP-B1)

| | |
|--|--|
| **Branch** | `fix/saf-t09-mintsplit` |
| **Allowlist** | `contracts/vaults/detf/common/**` new shared type file, Uni V4 `*Common.sol` MintSplit sites, Balancer `MintSplit` clones **if** time-boxed same PR, mint/bond tests |
| **Do** | One shared struct; drop dead `grossDetf` if unused; families import |
| **Parallel with** | T10 only if different files; else serial T09→T10 |
| **Land order** | after all Wave A tasks |

---

### T10 — Dead members / harvest hygiene (WP-B2)

| | |
|--|--|
| **Branch** | `fix/saf-t10-dead-members` |
| **Allowlist** | `DETFNFTVaultService` harvest/redeem params, Target harvest fill sites, orbital hook `WithdrawFlexibleVars`, tests |
| **Do** | Remove unread fields; compile gate |
| **Land order** | after T09 if both touch harvest; else parallel with T09/T11 |

---

### T11 — Branding strip (WP-B3)

| | |
|--|--|
| **Branch** | `fix/saf-t11-brand-strip` |
| **Allowlist** | factory helpers (`buildRICHIR*` → role-safe), SVG/comments under bond/claim, no brand tokens |
| **Do** | Rename helpers/strings; slot renames only with tests |
| **Parallel with** | T09/T10 |
| **Land order** | late Wave B |

---

### T12 — Integration gate (orchestrator)

| | |
|--|--|
| **Branch** | none (on `main`) |
| **Do** | Full default `forge build`; targeted + broader hermetic suites for all touched packages; `rg` for `via_ir` enablement and brand tokens in contracts; verify PRD AC1–AC12 checklist in a short completion note |
| **Done** | Program complete |

---

## 5. Wave schedule (execution)

### Wave 0 — Orchestrator bootstrap

1. Read PRD §2 fully; skim this plan §1–4.
2. T00 baseline.
3. Create `$WT_ROOT`.
4. Decide T08 early vs late from baseline compile.

### Wave A1 — Parallel spawn (max 3)

| Worker | Task | Worktree |
|--------|------|----------|
| W1 | T01 facets | `wt-t01-facets` |
| W2 | T02 claimRewards | `wt-t02-claim-rewards` |
| W3 | T03 pretransfer | `wt-t03-pretransfer` |

Optional W4: T08 if build red.

**Land sequence after A1 completes:** rebase+FF T01 → T02 → T03 (each onto updated main).

### Wave A2 — Serial

| Worker | Task |
|--------|------|
| W1 | T04 claim unwind (fresh worktree from post-A1 main) |

Land T04.

### Wave A3 — Parallel (disjoint: T05 ∥ T06a ∥ T08)

| Worker | Task |
|--------|------|
| W1 | T05 bond sold-retire + realloc lock |
| W2 | T06a CP-single fee only |
| W3 | T08 stack build (if not already done) |

Land: T05 → T06a → T08.

### Wave A3b / A3c — Serial

| Worker | Task |
|--------|------|
| W1 | T06b orbital/weighted Exchange fee+preview |
| W1 | T07 minOut tests only |

Land: T06b → T07.

### Wave B — Parallel (disjoint: T09 ∥ T10 ∥ T11)

| Worker | Task |
|--------|------|
| W1 | T09 MintSplit (Commons + new shared type only) |
| W2 | T10 harvest Service + hook dead fields (not MintSplit Commons) |
| W3 | T11 brand (factory/SVG) |

Land: T09 → T10 → T11.

### Wave Z — T12 integration

Orchestrator only on `main`.

---

## 6. Rebase / land runbook (copy-paste)

```bash
# === Land task TXX onto main (linear) ===
set -euo pipefail
REPO=/path/to/indexedex
WT=$REPO/../indexedex-worktrees/struct-audit-fixes/wt-tXX-slug
BRANCH=fix/saf-tXX-slug

cd "$REPO"
git fetch origin main
git checkout main
git pull --ff-only origin main

cd "$WT"
git rebase origin/main
# resolve conflicts if any, then:
#   git add -A && git rebase --continue

# scoped tests in WT
forge build
# forge test --match-path '...'  # task-specific

# FF-only onto main
cd "$REPO"
git merge --ff-only "$BRANCH"

# optional push
# git push origin main

git worktree remove "$WT"
git branch -d "$BRANCH"
```

If `merge --ff-only` fails, the branch was not fully rebased — fix with `git rebase origin/main` again; **do not** create a merge commit.

### Multi-commit worker branches

Prefer **one logical commit per task** before land:

```bash
cd "$WT"
git reset --soft origin/main   # ONLY if all work is task-local and already rebased intent
git commit -m "fix(saf-tXX): ..."
```

Or `git rebase -i origin/main` to squash, then FF-merge.

---

## 7. Per-task verification commands

| Task | Minimum commands |
|------|------------------|
| T01 | `forge test --match-path 'test/foundry/**/*DETFNFT*' --match-test 'test_.*[Ll]ockInfo\|detfNFT\|[Ff]acet\|[Dd]iamond' -vv` (adjust to actual names); plus new diamond tests |
| T02 | `forge test --match-path '**/uniswap/v4/**' --match-test 'test_.*[Cc]laimReward' -vv` |
| T03 | `forge test --match-path '**/*[Cc]laim*' --match-test 'test_.*[Pp]retransfer\|[Rr]edeem\|[Ee]xchange' -vv` |
| T04 | broader claim + bond + DETF redeem suite; no mock SUT |
| T05 | `rg -n 'markDETFNFTSold|DETFNFTSold|detfNFTSold' contracts/` → only historical comments if any; tests sell user NFT still |
| T06 | burn/withdraw fee + preview match tests on CP + orbital |
| T07 | realloc reentrancy + minOut end tests |
| T08 | `forge build` (default) must exit 0 |
| T09–T11 | mint/bond/harvest + `rg` brand clean |
| T12 | `forge build` + union of above |

Exact test names: discover with `forge test --list` after fixtures exist; prefer extending gold TestBases.

---

## 8. Conflict resolution playbook

| Situation | Action |
|-----------|--------|
| Two workers edited same file | Stop second; rebase second onto first landed; or orchestrator merges allowlists and respawns one worker |
| Rebase conflict in T04 after T03 | Prefer T03’s pretransfer helpers; re-apply unwind on top |
| T05 deletes symbols T01 registered | Land T05 after T01; T05 commit removes selectors; OK |
| Stack-too-deep after T10 | Revert dead-member collapse in that PR; keep helpers |
| Worker went out of allowlist | Reject commit; reset files; re-partition |

---

## 9. Orchestrator checklist

### Bootstrap

- [ ] PRD + this plan read
- [ ] T00 baseline compile recorded
- [ ] `$WT_ROOT` created
- [ ] `main` clean enough to land linear history

### Each parallel wave

- [ ] Spawn N subagents with **disjoint** allowlists + worktree cwd/isolation
- [ ] Collect DONE reports (SHA, tests, risks)
- [ ] For each task in **land order**: rebase → retest → `merge --ff-only` → drop worktree
- [ ] Never land unrebased branches

### Final

- [ ] T12 gates green
- [ ] PRD AC1–AC12 checklist marked in completion note
- [ ] No `via_ir` in default/CI profiles
- [ ] All `fix/saf-*` worktrees removed

---

## 10. Definition of done

| # | Done when |
|---|-----------|
| D1 | All T01–T11 landed **linearly** on `main` (or equivalent rebased PR stack) |
| D2 | PRD AC1–AC12 true with tests |
| D3 | Default `forge build` green |
| D4 | No open worktrees for this program |
| D5 | History contains no merge commits from unrebased feature branches for this program |

---

## 11. Mapping to PRD work packages

| PRD WP | Task(s) |
|--------|---------|
| WP-A1 facets | T01 |
| WP-A2 pretransfer | T03 |
| WP-A3 unwind | T04 |
| WP-A4 sold retire | T05 |
| WP-A5 claimRewards | T02 |
| WP-A6 fees+preview | T06a + T06b |
| WP-A7 minOut | T07 (tests only) |
| WP-A8 reentrancy | T05 (with sold-retire; keeps bond Target exclusive) |
| WP-A9 build | T08 |
| WP-B1 MintSplit | T09 |
| WP-B2 dead members | T10 |
| WP-B3 brand | T11 |
| Integration | T00, T12 |

---

## 12. Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-08-09 | Initial plan: worktrees + parallel subagents + orchestrator rebase for linear `main` |
| 1.1 | 2026-08-09 | Hard exclusive write sets; task-local saf tests; fix A3 overlap (realloc→T05, T07 tests-only, T06a∥T05) |

**PRD:** [`docs/STRUCT_AUDIT_FIXES_PRD.md`](./STRUCT_AUDIT_FIXES_PRD.md)
