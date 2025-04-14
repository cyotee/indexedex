# Submodule Consolidation Plan (indexedex)

## Duplication & Fork Candidates (review first)

This section enumerates known duplicate submodule inclusions and suggests when a repo should be forked to remove duplication while keeping a *consistent* dependency version across our project.

### What we mean by “consistent version”
For each shared dependency repo (e.g., `forge-std`, `permit2`, `balancer-v3-monorepo`), we want **one canonical checkout** used by both `indexedex` and `crane` (via remappings), pinned to a SHA that passes our gates.

Important nuance: “consistent version” should mean **latest known-good** (newest SHA that passes `indexedex` + `crane` `forge build/test`), not necessarily upstream HEAD at all times.

### Policy: forge-std reuse vs vendored forge-std

We will keep the existing practice:
- `indexedex` and `daosys` should **reuse crane’s `forge-std`** via `indexedex/remappings.txt` (and `daosys/remappings.txt`), so `forge-std/` resolves to `lib/daosys/lib/crane/lib/forge-std/src/`.
- Other third-party submodules may keep their own pinned `forge-std` (or other test deps) inside their own trees.

Developer note:
- If you want to minimize checkout size locally, you can avoid initializing nested third-party submodules that you don’t intend to build/test. The repo will still be able to build/test at the `indexedex` + `crane` surface as long as our canonical remappings are intact.

Future option:
- If a third-party repo’s pinned `forge-std` becomes incompatible with newer toolchains, prefer an upstream PR to bump it; fork only if upstream won’t merge in a reasonable timeframe.

### Concrete duplication cases found (actionable)

1) **Duplicate `forge-std` at indexedex root vs crane**
- `indexedex/lib/forge-std` (top-level submodule)
- `indexedex/lib/daosys/lib/crane/lib/forge-std` (crane submodule)

Suggested canonical: **crane’s** `lib/forge-std` (since `indexedex/remappings.txt` already points there).

Fork recommendation: **No**. This is our own layout choice; no upstream fork needed.

2) **`v4-periphery` duplicates `permit2` and `v4-core` inside crane**
- `indexedex/lib/daosys/lib/crane/lib/permit2` exists
- `indexedex/lib/daosys/lib/crane/lib/v4-core` exists
- `indexedex/lib/daosys/lib/crane/lib/v4-periphery/.gitmodules` also declares its own `lib/permit2` and `lib/v4-core`

Suggested canonical: crane’s top-level `lib/permit2` and `lib/v4-core`.

Fork recommendation: **Maybe**.
- If `Uniswap/v4-periphery` relies on those submodules being present (and/or pins specific SHAs), removing them cleanly likely requires changing `v4-periphery`’s `.gitmodules` and possibly its test/build config.
- If Uniswap won’t accept/merge such changes quickly, fork to enforce our dedupe + SHA policy.

3) **`reclamm` duplicates `balancer-v3-monorepo` inside crane**
- `indexedex/lib/daosys/lib/crane/lib/balancer-v3-monorepo` exists
- `indexedex/lib/daosys/lib/crane/lib/reclamm/.gitmodules` also declares its own `lib/balancer-v3-monorepo`

Suggested canonical: crane’s top-level `lib/balancer-v3-monorepo`.

Fork recommendation: **Maybe**.
- If `balancer/reclamm` is expected (by its own build/tests) to pin a specific Balancer V3 SHA, removing the nested submodule cleanly likely requires editing `reclamm` and validating its own suite.

4) **Deep, transitive duplicates (many repos vendor their own submodules)**
Examples include additional copies of `forge-std`, `openzeppelin-contracts`, and `ds-test` nested inside third-party trees.

Suggested canonical: **leave alone unless required**.

Fork recommendation: **Rarely**.
- Only consider forking a deep upstream repo if (a) it is in the `indexedex`/`crane` build surface, and (b) its vendored submodules materially block consolidation or consistent-version policy.

### Decision checklist: when to fork vs when to rely on remappings

Fork a third-party repo when most of these are true:
- We must change its `.gitmodules` (remove duplicates, repoint URLs) to achieve consolidation.
- We must bump its pinned submodule SHAs to match our canonical versions.
- We need to run *that repo’s* own tests against the updated dependency SHAs to keep confidence.
- Upstream is unlikely to accept/merge the changes quickly, or we need different pinning than upstream.

Avoid forking (prefer leaving upstream pinned + using our remappings) when most of these are true:
- The repo is only a source dependency and we do not run its own test suite.
- It doesn’t require its nested submodules at build time once our remappings are applied.
- Version skew is acceptable because the code is not in our build surface or uses distinct import prefixes.

### Recommended “fork targets” to evaluate first
If your goal is strict consolidation + consistent versions across our surface, these are the first repos to evaluate for forks:
- `Uniswap/v4-periphery` (to drop its nested `permit2` + `v4-core` and/or align pins)
- `balancer/reclamm` (to drop its nested `balancer-v3-monorepo` and/or align pins)

Everything else should be treated case-by-case after we confirm what actually compiles/tests as part of the gates.

### Repo playbooks (start here): v4-periphery and reclamm

These two repos are the highest-leverage places to fork if you want to *actually remove* duplicate checkouts.

#### v4-periphery (Uniswap) — fork options

**Duplication to resolve (when vendored inside crane):**
- `crane/lib/v4-periphery/.gitmodules` declares `lib/permit2` and `lib/v4-core`, but crane already has `crane/lib/permit2` and `crane/lib/v4-core`.

**Option A — Consistency-only (lowest risk; does not reduce disk usage):**
- Keep `v4-periphery`’s submodules, but update their pinned SHAs to match the versions you want (ideally the same SHAs as crane’s canonical `permit2` and `v4-core`).
- Pros: `v4-periphery` still works standalone as upstream expects.
- Cons: still duplicated checkouts.

**Option B — True dedupe (recommended if you want fewer submodules):**
- In your fork of `v4-periphery`, remove the submodules `lib/permit2` and `lib/v4-core`.
- Update the fork so it can still compile/tests when vendored under crane:
  - Either (1) rely on crane’s root remappings when `v4-periphery` is only a source dependency, or
  - (2) add a documented “vendor mode” that supplies remappings via `FOUNDRY_REMAPPINGS` / `--remappings` when running `forge` inside `v4-periphery`.

**Important constraint:** foundry remappings are project-root scoped. Removing `v4-periphery`’s submodules is safe only if we *don’t* require running `forge test` inside `v4-periphery` without additional setup.

**Validation gates (after switching crane to your fork / after removing duplicates):**
- `crane`: `forge build` + `forge test`
- `indexedex`: `forge build` + `forge test`

#### reclamm (Balancer) — fork options

**Duplication to resolve (when vendored inside crane):**
- `crane/lib/reclamm/.gitmodules` declares `lib/balancer-v3-monorepo`, but crane already has `crane/lib/balancer-v3-monorepo`.

**Option A — Consistency-only (lowest risk; does not reduce disk usage):**
- Keep `reclamm`’s nested `balancer-v3-monorepo` submodule, but update it to the SHA you want (ideally the same SHA as crane’s canonical `balancer-v3-monorepo`).
- Pros: `reclamm` remains close to upstream structure.
- Cons: still duplicated checkouts.

**Option B — True dedupe (recommended if you want fewer submodules):**
- In your fork of `reclamm`, remove the nested `lib/balancer-v3-monorepo` submodule.
- Ensure imports that reference `@balancer-labs/v3-*` are resolvable from crane’s canonical `balancer-v3-monorepo` via crane-level remappings.

**Validation gates (after switching crane to your fork / after removing duplicates):**
- `crane`: `forge build` + `forge test`
- `indexedex`: `forge build` + `forge test`

**Optional extra validation (recommended if you plan to actively use these repos):**
- Run the forked repo’s own tests (inside the fork) after you adjust its dependency graph. This is where forking adds value: you can make the repo green against your chosen dependency SHAs.

## Goal
Reduce duplicated submodule checkouts across `indexedex` and its nested submodules (especially `daosys` → `crane`) while keeping the project building + testing reliably.

Key constraint: **do not remove “unused but intentionally kept” submodules**. This plan focuses on *deduplicating shared dependencies* (e.g., `forge-std`, `permit2`, Balancer V3 monorepo) and consolidating them behind stable Foundry remappings.

## Current state (observations)

### Top-level submodules in indexedex
From `indexedex/.gitmodules`:
- `lib/daosys` (cyotee/daosys)
- `lib/forge-std` (foundry-rs/forge-std)
- `lib/v2-core` (Uniswap/v2-core)
- `lib/v2-periphery` (Uniswap/v2-periphery)
- `lib/core` (CamelotLabs/core)
- `lib/periphery` (CamelotLabs/periphery)
- `lib/frontend-monorepo` (balancer/frontend-monorepo)

### indexedex remappings already “prefer crane”
`indexedex/remappings.txt` already routes core shared deps through `daosys → crane`:
- `forge-std/=lib/daosys/lib/crane/lib/forge-std/src/`
- `@openzeppelin/=lib/daosys/lib/crane/lib/openzeppelin-contracts/`
- `permit2/=lib/daosys/lib/crane/lib/permit2/`
- Balancer V3 packages via `lib/daosys/lib/crane/lib/balancer-v3-monorepo/pkg/...`

This is good: it means **the canonical dependency copies for Foundry builds are already the ones inside the `crane` submodule**, not the top-level `indexedex/lib/*` copies.

### Key duplication patterns already present
These are the most actionable “same repo appears multiple times” cases visible from `.gitmodules` and recursive submodule layout:

1) **`forge-std` duplicated**
- Present at `indexedex/lib/forge-std` (top-level)
- Also present at `indexedex/lib/daosys/lib/crane/lib/forge-std`
- Many additional copies appear nested under other third-party repos (typical upstream pattern)

2) **Within crane: `v4-periphery` duplicates `permit2` + `v4-core`**
- `crane/lib/permit2` and `crane/lib/v4-core` exist
- `crane/lib/v4-periphery/.gitmodules` also declares `lib/permit2` and `lib/v4-core`

3) **Within crane: `reclamm` duplicates `balancer-v3-monorepo`**
- `crane/lib/balancer-v3-monorepo` exists
- `crane/lib/reclamm/.gitmodules` also declares `lib/balancer-v3-monorepo`

4) **“Upstream dependency trees” contain their own duplicates**
Many third-party repos inside `crane/lib/*` come with their own nested submodules (e.g., additional `forge-std`, `openzeppelin-contracts`, `ds-test`, etc.). Consolidating those is possible but **riskier** (version pinning and import-prefix collisions).

## Consolidation principles

1) **Single-source-of-truth per import prefix**
If contracts import `forge-std/...`, then exactly one `forge-std/=` remapping should be authoritative for the build. Same idea for `permit2/=`, `@balancer-labs/*`, etc.

2) **Prefer “lowest common provider” submodule for shared deps**
For `indexedex`, that provider is currently **`daosys/lib/crane`**. If both `indexedex` and `crane` include a dependency, prefer `crane` and remap to it (your example).

3) **Don’t unify incompatible versions**
Some repos pin dependencies to specific major versions (notably OpenZeppelin). If two copies are required because:
- they use the same import prefix but require different majors, or
- the dependency’s API changed and breaks compilation/tests,
then **keep duplicates** (or plan a refactor/fork explicitly).

4) **Keep “unused but intentionally kept” repos**
We will not remove whole submodules just because they’re unused today. Deduplication should target *dependency submodules* that are duplicates of already-present canonical copies.

5) **Every removal must have a fallback**
Before removing a duplicate, ensure there is:
- a remapping covering the import prefix, and
- no remaining code relies on the removed path directly.

## Work plan (systematic)

### Phase 0 — Define the build/test surface (no changes)

**Must-pass gates (per request):**
- `indexedex`: `forge build` and `forge test`
- `crane`: `forge build` and `forge test`

Notes:
- Treat `daosys` as an integration dependency of `indexedex` unless CI explicitly runs `daosys`’ own Foundry project.
- If either suite is not green *before* consolidation work begins, consolidate only after establishing a green baseline (otherwise we can’t attribute failures to submodule/remapping changes).

### Phase 1 — Inventory + classify duplicates (no changes)
Create a simple inventory table (in this doc or a follow-up doc) listing for each duplicated repo URL:
- all locations (paths)
- commit pins (submodule SHA)
- which remapping(s) or imports reference it
- risk level

Classification rubric:
- **Safe to consolidate (S1)**: dev/test infra libs (`forge-std`, `ds-test`) where import prefix is uniform and version mismatch is unlikely to matter.
- **Needs verification (S2)**: libraries with common but evolving APIs (`solmate`, `permit2`, `openzeppelin-contracts`)
- **Avoid consolidating (S3)**: repos that vendor their own dependency graph and are not part of `indexedex` build/test (leave untouched unless needed).

### Phase 2 — Easy win: remove top-level indexedex duplicates
Target: remove duplicates that `indexedex` already remaps to `crane`.

Candidate 2.1: Remove `indexedex/lib/forge-std`
- Rationale: `indexedex/remappings.txt` already points `forge-std/=` to `lib/daosys/lib/crane/lib/forge-std/src/`.
- Checklist:
  - Confirm no scripts/README instructions assume `indexedex/lib/forge-std` exists.
  - Confirm no Foundry config relies on auto-detect remappings that pick the top-level path.
  - Remove submodule entry, deinit, and delete directory.

Non-goal in this phase:
- Do not remove indexedex-only deps (Uniswap v2, Camelot core/periphery, balancer frontend-monorepo) unless they are also duplicated elsewhere.

### Phase 3 — Consolidate duplicates *inside crane* (recommended)
These are the biggest “same repo twice” offenders and are strongly aligned with your example.

Candidate 3.1: In `crane`, remove `v4-periphery/lib/permit2` and rely on `crane/lib/permit2`
- Update `crane`’s remappings (if needed) so `permit2/=` resolves to `crane/lib/permit2/...`.
- Validate that `v4-periphery` sources import `permit2` through a remappable prefix (not hard-coded relative paths).

Candidate 3.2: In `crane`, remove `v4-periphery/lib/v4-core` and rely on `crane/lib/v4-core`
- Same pattern as 3.1.

Candidate 3.3: In `crane`, remove `reclamm/lib/balancer-v3-monorepo` and rely on `crane/lib/balancer-v3-monorepo`
- Ensure any imports from `reclamm` use `@balancer-labs/...` prefixes that are already remapped at the crane level.

### Phase 4 — Optional: consolidate “deep” upstream duplicates (high risk)
This is where most bloat lives (many nested `forge-std`, `openzeppelin-contracts`, etc.). Only do this if you want aggressive consolidation and are prepared for version conflicts.

Rules of engagement for Phase 4:
- Only touch nested submodules **if the parent repo is compiled/tested as part of the required surface**.
- Prefer consolidating `forge-std` first; leave OpenZeppelin and other core libs alone unless you verify version compatibility.
- If an upstream repo expects a pinned submodule version for correctness, keep it.

## Execution checklist (for each duplicate removal)
When we actually implement (later), each candidate should follow the same steps:

1) **Prove resolution path**
- Identify the exact import prefixes used (`forge-std/…`, `permit2/…`, `@balancer-labs/...`).
- Ensure the canonical copy is reachable via `remappings.txt` / `foundry.toml remappings`.

2) **Remove the duplicate submodule cleanly**
- Edit the appropriate `.gitmodules` in the repo that declares the duplicate.
- Run (later, during implementation):
  - `git submodule deinit -f <path>`
  - remove the submodule directory
  - remove the submodule entry from `.git/config` if needed
  - `git add .gitmodules <path>`

3) **Update remappings only if necessary**
- Prefer updating only the repo whose Foundry build actually runs.
- Keep remappings centralized (ideally at the root Foundry project) to avoid drift.

4) **Validate**
- `forge build` + `forge test` in **indexedex**
- `forge build` + `forge test` in **crane**

5) **Rollback plan**
- If version mismatch breaks compilation/tests, revert the submodule removal and record it as an exception (keep duplicate).

## Proposed “canonical ownership” map (initial)
This can be refined in Phase 1, but as a starting point:

- **Canonical shared Solidity deps (preferred location):** `lib/daosys/lib/crane/lib/*`
  - `forge-std`
  - `openzeppelin-contracts`
  - `permit2`
  - `balancer-v3-monorepo`

- **Indexedex-specific deps (keep at indexedex root):** `indexedex/lib/*`
  - Uniswap v2 (`v2-core`, `v2-periphery`)
  - Camelot (`core`, `periphery`)
  - Balancer frontend (`frontend-monorepo`)

- **Crane feature repos (keep, but dedupe their nested deps):** `lib/daosys/lib/crane/lib/*`
  - `v4-periphery` should reuse `crane/lib/permit2` and `crane/lib/v4-core`
  - `reclamm` should reuse `crane/lib/balancer-v3-monorepo`

## Next step
If you want, I can extend this doc with a concrete inventory table and a prioritized “PR-sized” sequence (smallest-risk removals first), including exactly which `.gitmodules` entries will be removed and which remappings (if any) need to change.
