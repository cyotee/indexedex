# Implementation Plan — Test Coverage Gap Closure (Stage 3)

| Field | Value |
|-------|--------|
| **Status** | **IN PROGRESS — RESUME AS NEW GOAL** (prior goal session ended mid-program; do not treat as complete) |
| **Date** | 2026-08-09 (progress update same day) |
| **Kind** | Execute plan for orchestrator + parallel worktree subagents |
| **Authorizes** | Stage 3 implementation only (production + Foundry tests) |
| **Normative law** | [`TEST_COVERAGE_GAP_CLOSURE_PRD.md`](./TEST_COVERAGE_GAP_CLOSURE_PRD.md) (§4.3 L-GAPS-9…13) |
| **WP inventory** | [`coverage-audit/WORK_PACKAGE_BACKLOG.md`](./coverage-audit/WORK_PACKAGE_BACKLOG.md) — **44** WPs |
| **Findings** | [`coverage-audit/AGGREGATE.md`](./coverage-audit/AGGREGATE.md) + `areas/**` |
| **Progress log** | [`coverage-audit/STAGE3_PROGRESS.md`](./coverage-audit/STAGE3_PROGRESS.md) |
| **Max concurrent subagents** | **3** |
| **Worktree / branch prefix** | `gap_cover_` |
| **Merge model** | **Rebase onto `main` → fast-forward `main`** (linear history) |
| **Sibling work** | Another agent may edit **scripts/** in a different workspace; do not touch `scripts/**` in gap-closure slices |
| **Resume tip (`main`)** | **`e2e6482`** — Wave 0 + W1-A closed on `main` (see §0.0) |

---

## 0.0 NEXT AGENT HANDOFF — start a **new goal** here

Prior automated goal marked itself done after partial progress. **This program is not finished.** Start a **new** goal (do not rely on `/goal resume` of the old session).

### Goal objective (paste into new goal)

> Execute remaining Stage 3 gap-closure work packages from this plan until all **44** WP-IDs are closed or only `BUILD_BLOCKED` (fork RPC missing per L-GAPS-13). Seed every worktree with warm `cache_forge/` + `out/` before `forge`. Never kill long solc/forge runs; wait until they exit with success or a real error. Continue from `main` @ `e2e6482` (or later FF tip).

### Already on `main` (do not redo unless regression)

| Commit | Slice | WPs closed |
|--------|-------|------------|
| `bbe501e` | `i-common` | `WP-I-COMMON-001`, `WP-I-COMMON-002`, `WP-I-CLONE-001` (checklist) + `ISecurePullErrors.sol` |
| `68c7775` | `i-detf-cs` | `WP-I-DETF-CS-001`, `WP-I-DETF-CS-002` (+ nested SE `forceApprove` + `pretransferred=false`) |
| `a2eaba7` | `i-detf-mv` | `WP-I-DETF-MV-001`, `WP-I-DETF-MV-002`, `WP-K-DETF-MV-001`, `WP-J-DETF-MV-001` |
| `e2e6482` | `i-detf-sse` | `WP-I-DETF-SSE-001`, `WP-I-DETF-SSE-002`, `WP-J-DETF-SSE-001` |

**Closed count:** **12 / 44**. **Remaining:** **32** (queue in §0.0.1).

### Product law already fixed (inherit, do not re-litigate)

- Shared error: `contracts/interfaces/ISecurePullErrors.sol` → `TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta)`.
- L-GAPS-9: credit **exactly `claimed`** when `claimed ≤ observedDelta`; else shared error. No exact-delta lock. Absolute `balanceOf` free credit forbidden.
- Nested SE/router from DETF: **do not** `transfer` then call with `pretransferred=true` (outer transfer is outside nested pull window → delta 0). Use **`forceApprove` + `pretransferred=false`** so nested vault measures inbound delta. CS already fixed; apply same pattern anywhere nested transfer+true remains.
- Honest user path for package pulls: prefer `pretransferred=false` + `transferFrom`; transfer-before-call is **not** in-window delta under L-GAPS-9.

### 0.0.1 Remaining slice queue (work next — §3 order)

Wave 0 and W1-A (**done**). Continue from **W1-B**:

```text
DONE:  [i-common]
DONE:  [i-detf-mv | i-detf-sse | i-detf-cs]

NEXT:  [i-detf-mb | i-detf-dl | i-detf-sse-cp]     ← W1-B (≤3)
THEN:  [i-detf-sse-uv4 | i-se-uab | i-hook-cp]
THEN:  [i-hook-dual | i-hook-sebuf | i-claim]
THEN:  [i-se-ac | e5-aero | j-mgr-seigniorage]
THEN:  [j-detf-cs-mb | j-hooks | j-rtr]             ← if not packed into CODE slices
THEN:  Wave 2 packs (adv-*, rtr, n-fee, h-cam, j-mgr, j-router-uab, g-e-detf-cs)
```

Pre-created worktrees may already exist at:

- `.worktrees/gap_cover_i-detf-mb` (`gap_cover/i-detf-mb`)
- `.worktrees/gap_cover_i-detf-sse-cp` (`gap_cover/i-detf-sse-cp`)
- `.worktrees/gap_cover_i-se-ac` (`gap_cover/i-se-ac`)

Reuse if still on current `main` tip; else recreate from `main` and re-seed cache (§1.6).

### 0.0.2 Forbidden: session-budget DEFER

Do **not** mark Blocker/High WPs `DEFER` because compile is slow. Only `BUILD_BLOCKED` (L-GAPS-13, missing Alchemy/RPC) or true product `NEEDS_OWNER` stop a WP. Finish the program.

---

## 0. Orchestrator charter (read first)

You are the **Stage 3 orchestrator**. You do **not** implement CODE/tests yourself except trivial docs merges **and** worktree/cache setup. You:

1. Create **at most three** git worktrees at a time (**after** seeding `cache_forge/` + `out/` — §1.6).
2. Spawn **at most three** implementer subagents (one per worktree).
3. Wait for completion → verify forge acceptance → **rebase worktree onto `main`** → **fast-forward `main`** → remove worktree → start next queued slice(s).
4. Never open a fourth concurrent implementer.
5. Never let two subagents share a slice key or the same primary touch-set files.
6. Apply product law from PRD §4.3 without re-asking the owner.
7. **Never kill** long-running `forge` / `solc` processes out of impatience (see §0.3).

### 0.1 Hard rules (copy into every subagent prompt)

- **No `via_ir`.** No mock SUT as coverage. DETF role names only.
- Facets: CREATE3 / FactoryService. Vault/DETF DFPkgs: **manager vault registry**. Hooks: `deployHookVault` path.
- **L-GAPS-9:** credit `claimed` only if `claimed ≤ observedDelta`; if `claimed > delta` → `TransferDeltaInsufficient`; never exact-delta vault lock.
- **L-GAPS-10:** `contracts/interfaces/ISecurePullErrors.sol` — `error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);` (**already on main**).
- **L-GAPS-11:** SE buffer hook leftover spendable design stays; tests only. Book free-spend still CODE.
- **L-GAPS-12:** package-local delta algorithm; shared **error** only (no SecurePullLib rewrite of all clones).
- **L-GAPS-13:** DualLiquidity (fork-first) without Alchemy → `BUILD_BLOCKED`, do not close WP.
- I1: no transfer in-call. J3: call **proxy**, not facet impl. Exact selectors on negatives.
- **Do not edit** `scripts/**` (owned by sibling agent).
- **Do not edit** files outside your slice touch set.
- **Seed `cache_forge/` + `out/` before forge** (§1.6). Prefer symlink `lib/crane` → primary checkout to avoid nested submodule reinstall.
- **Forge patience:** monorepo cold compile can take **20–40+ minutes**. That is normal. Wait for process exit (success **or** real error). **Never** kill solc/forge because it “seems stuck.”

### 0.2 Concurrency state machine

```text
slots_free = 3
queue = [all slices in §3 order]

while queue not empty OR active worktrees:
  while slots_free > 0 AND next slice deps satisfied:
    create worktree + branch from current main
    spawn subagent (slots_free -= 1)
  wait for any subagent completion
  verify acceptance (§5)
  rebase branch onto main
  fast-forward main
  remove worktree (slots_free += 1)
```

**Wave 0:** **DONE** on `main`. `slots_free` starts at **3** for remaining product slices.

### 0.3 Compile / forge patience (non-negotiable)

IndexedEx hermetic compile is large (~1.8k solc inputs). Observed cold times: **~20–30+ minutes** per worktree. This is **expected**, not a hang.

| Rule | Detail |
|------|--------|
| **Never assume stuck** | No progress line for a long time is normal while solc holds a single process at high CPU/RAM. |
| **Never kill the build** | Killing `forge` / `solc` mid-run **wastes all elapsed time** and forces a full or near-full recompile. Every premature kill is pure loss. |
| **Wait for exit** | Keep one long-running command; use a completion notification / background wait until exit code is set. Do not busy-poll every few minutes and abort. |
| **Timeouts** | If a tool requires a timeout, set it to **hours** (e.g. 2–4h) for first compile in a worktree, not 10–20 minutes. |
| **After green** | Copy updated `cache_forge/` + `out/` back to a warm seed location (primary repo or last green worktree) so the next slice benefits. |
| **Parallel solc** | ≤3 worktrees may each run forge, but prefer **not** three simultaneous **full cold** compiles. Prefer seed caches first so incremental work is cheap; serialize only if the machine is thrashing (OOM), not because “slow.” |

---

## 1. Git / worktree protocol (linear history)

### 1.1 Naming

| Item | Pattern | Example |
|------|---------|---------|
| Worktree directory | sibling of repo or under `.worktrees/` | `../gap_cover_i-common` or `.worktrees/gap_cover_i-common` |
| Branch | `gap_cover/<slice-id>` | `gap_cover/i-common` |
| Commit subject | `gap_cover(<slice>): <imperative>` | `gap_cover(i-common): delta-pretransfer + TransferDeltaInsufficient` |

Use the **slice id** from §3 (e.g. `i-common`, `i-detf-mv`). Prefix always `gap_cover_`.

### 1.2 Create worktree (orchestrator)

```bash
# From main repo root; main must be clean and up to date
git checkout main
git pull --ff-only   # if remote tracking is used; else skip

SLICE=i-detf-mb   # example — use next remaining slice id
git branch "gap_cover/${SLICE}" main
git worktree add ".worktrees/gap_cover_${SLICE}" "gap_cover/${SLICE}"

# REQUIRED: seed forge artifacts before any forge command (§1.6)
# REQUIRED: avoid nested crane reinstall thrash
```

### 1.6 Seed forge `cache_forge/` + `out/` (required — expedites compile)

**Do this every time you create or reuse a worktree before the first `forge test` / `forge build`.**

Warm artifacts already live on the primary checkout when present:

| Path | Role |
|------|------|
| `<repo>/cache_forge/` | Foundry solidity file cache (`foundry.toml` `cache_path`) |
| `<repo>/out/` | Compiled artifacts |

After a **green** slice, **copy the worktree’s updated** `cache_forge/` and `out/` **back** into the primary repo (or keep the last green worktree as `SRC_*`) so the next slice inherits incremental compile.

```bash
REPO="$(pwd)"   # indexedex root (primary checkout with warm cache)
SLICE=i-detf-mb
WT="${REPO}/.worktrees/gap_cover_${SLICE}"

# Prefer rsync; fall back to cp -a
seed_dir() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${src}/" "${dest}/"
  else
    cp -a "${src}/." "${dest}/"
  fi
}

# Sources: primary first; override if a greener worktree is newer
SRC_CACHE="${SRC_CACHE:-${REPO}/cache_forge}"
SRC_OUT="${SRC_OUT:-${REPO}/out}"

if [[ -d "$SRC_CACHE" ]]; then seed_dir "$SRC_CACHE" "${WT}/cache_forge"; fi
if [[ -d "$SRC_OUT" ]]; then seed_dir "$SRC_OUT" "${WT}/out"; fi

# Avoid forge re-cloning nested crane deps: symlink crane to primary
if [[ -d "${REPO}/lib/crane" && ! -L "${WT}/lib/crane" ]]; then
  rm -rf "${WT}/lib/crane"
  ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
fi

# After green forge in $WT — refresh seed for next worktrees:
# seed_dir "${WT}/cache_forge" "${REPO}/cache_forge"
# seed_dir "${WT}/out" "${REPO}/out"
```

**Notes:**

- Seeded cache only skips **unchanged** units. CODE edits still recompile those packages — that is expected and still far cheaper than a cold monorepo compile.
- Profile must match: hermetic uses `cache_forge` + `out` per `foundry.toml` (`cache_path = 'cache_forge'`).
- **Do not** delete `out/` or `cache_forge/` “to be safe” mid-program.

### 1.3 Subagent finish checklist

Inside the worktree:

1. All acceptance forge commands green (or `BUILD_BLOCKED` documented for fork-only).
2. Commit(s) on `gap_cover/<slice>` only — prefer **one logical commit** per slice (or few tidy commits).
3. No unrelated files; no `scripts/**`.

### 1.4 Integrate (orchestrator only — linear FF)

```bash
# On main worktree (not the slice worktree)
git checkout main
git pull --ff-only   # if applicable

SLICE=i-common
# Rebase slice onto latest main (handles any intervening FF merges)
git -C ".worktrees/gap_cover_${SLICE}" fetch origin 2>/dev/null || true
git -C ".worktrees/gap_cover_${SLICE}" rebase main

# Fast-forward main (must be FF-only; if not, rebase again or fix conflicts in worktree)
git merge --ff-only "gap_cover/${SLICE}"

# Cleanup
git worktree remove ".worktrees/gap_cover_${SLICE}"
git branch -d "gap_cover/${SLICE}"   # optional after FF
```

**Conflict on rebase:** re-open the **same** worktree with a fix subagent (counts as one of the three slots). Do **not** merge with a merge commit.

**Never:** `git merge` without `--ff-only` onto main; never force-push main; never two slices rebase/merge concurrently onto main (serialize integration even if work was parallel).

### 1.5 Integration lock

While rebasing/FF one slice, **do not** start FF of another. Parallel worktrees may **continue coding**; only **main updates** are serial.

---

## 2. Global product law (implementors — no alternatives)

### 2.1 Pull credit (vaults / DETFs / SE)

```text
observedDelta = balanceAfter - balanceBefore   # over the pull window
if claimed > observedDelta:
    revert TransferDeltaInsufficient(claimed, observedDelta)
// else credit exactly claimed
```

- Absolute `balanceOf >= claimed` without delta is **forbidden**.
- Do **not** require `observedDelta == claimed` (donation must not lock depositors).
- I1: `pretransferred=true`, no transfer, inventory present → delta 0 → revert shared error.

### 2.2 Shared error (Wave 0 creates; all later slices import)

```solidity
// contracts/interfaces/ISecurePullErrors.sol
interface ISecurePullErrors {
    error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);
}
```

### 2.3 Hooks leftover (SE buffers)

Keep leftover spendable design. Tests: unfunded fails; book not free-spent; residual not double-spent. **CODE** only for book free-extract (CP/Dual).

---

## 3. Slice schedule (conflict-free, ≤3 concurrent)

### 3.1 Legend

| Column | Meaning |
|--------|---------|
| **Slice ID** | Worktree suffix / branch path |
| **WPs** | Packed WPs (one worktree; L-GAPS-6) |
| **Deps** | Must be on `main` before spawn |
| **Batch** | Concurrent group (max 3 slices) |

### 3.2 Wave 0 — serial (1 slot)

| Batch | Slice ID | WPs packed | Production touch set (primary) | Test touch set (primary) | Deps |
|-------|----------|------------|--------------------------------|--------------------------|------|
| **W0** | `i-common` | Shared error lib + `WP-I-COMMON-001` + `WP-I-COMMON-002` + `WP-I-CLONE-001` checklist commit | `contracts/interfaces/ISecurePullErrors.sol` (**new**); `contracts/vaults/basic/BasicVaultCommon.sol`; `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol` | `test/foundry/spec/vaults/basic/**` (TokenTransfer, Permit2, new TrustFlags) | none |

**W0 DoD:**

- [ ] `ISecurePullErrors.sol` on main via FF
- [ ] BasicVaultCommon + Aero override: L-GAPS-9 semantics + shared error
- [ ] Theater tests that asserted free credit inverted or deleted
- [ ] `test_I1_*`, `test_I2_*`, `test_I3_*` green on basic vault paths
- [ ] Checklist note in worklog / short `docs/testing/coverage-audit/CLONE_API_FREEZE.md` (optional): packages must implement same delta rules + import shared error (not a second algorithm lib)
- [ ] `forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv` green

**Acceptance commands:**

```bash
forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv
forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I' -vv
```

---

### 3.3 Wave 1 — product CODE + I + J (batches of ≤3)

Spawn only after **W0** is on `main`.

#### Batch W1-A (3 slots)

| Slice ID | WPs packed | Primary production paths | Primary test paths | Notes |
|----------|------------|--------------------------|--------------------|-------|
| `i-detf-mv` | `WP-I-DETF-MV-001`, `WP-I-DETF-MV-002`, `WP-K-DETF-MV-001`, `WP-J-DETF-MV-001` | `contracts/vaults/detf/**/multi-vault-weighted/**` (Common + Targets as needed) | `test/**/multi-vault-weighted/**` adversarial I/J/K | Gold A–H untouched except extend |
| `i-detf-sse` | `WP-I-DETF-SSE-001`, `WP-I-DETF-SSE-002`, `WP-J-DETF-SSE-001` | `contracts/vaults/detf/**/balancer/v3/standardExchange/single/**` | `test/**/standardExchange/single/**` | Balancer Single SE only |
| `i-detf-cs` | `WP-I-DETF-CS-001`, `WP-I-DETF-CS-002` | `contracts/vaults/detf/**/balancer/v3/stable/common/**` (+ RebasingDETFToken if in CS CODE) | `test/**/stable/**` adversarial I | J for CS→ see `j-detf-cs-mb` in W1-F if not done here |

**Forge (examples):**

```bash
# i-detf-mv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' --match-test 'test_I|test_J|test_K1' -vv

# i-detf-sse
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' --match-test 'test_I|test_J' -vv

# i-detf-cs
forge test --match-path 'test/**/stable/**' --match-test 'test_I|test_K1' -vv
```

#### Batch W1-B (3 slots) — after W1-A integrated or in parallel if paths disjoint

W1-B may start **as soon as W0 is on main** (paths disjoint from W1-A). Prefer filling free slots immediately when a W1-A slice finishes.

| Slice ID | WPs packed | Primary production paths | Primary test paths | Notes |
|----------|------------|--------------------------|--------------------|-------|
| `i-detf-mb` | `WP-I-DETF-MB-001` (+ scaffold adversarial dir for I only; full A–H in W2) | `contracts/vaults/detf/**/mixedBuffer/**` | `test/**/mixedBuffer/**` | I suite with CODE |
| `i-detf-dl` | `WP-I-DETF-DL-001`, `WP-I-DETF-DL-002`, `WP-J-DETF-DL-001` | `contracts/vaults/detf/**/uniswap/v4/crossVersion/**` | `test/foundry/fork/**/crossVersion/**` | **Fork**; Alchemy required |
| `i-detf-sse-cp` | `WP-I-DETF-SSE-CP-001`, `WP-J-DETF-SSE-CP-001` | `contracts/vaults/detf/**/uniswap/v4/**/constantProduct/single/**` | matching test tree | Uni V4 CP DETF |

```bash
# i-detf-dl (L-GAPS-13)
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/**/crossVersion/**' \
  --match-test 'test_I|test_J|test_K1' \
  --fork-url base_mainnet_alchemy -vv
```

#### Batch W1-C (3 slots)

| Slice ID | WPs packed | Primary production paths | Primary test paths |
|----------|------------|--------------------------|--------------------|
| `i-detf-sse-uv4` | `WP-I-DETF-SSE-UV4-001` (+ minimal I1) | `contracts/vaults/detf/**/uniswap/v4/standardExchange/single/**` (legacy, not CP) | expand beyond T01/T02 |
| `i-se-uab` | `WP-I-CLONE-UAB-001`, `WP-I-SE-UAB-001`, `WP-J-SE-UAB-001` | Uni V4 SE + Aave Stata under `contracts/protocols/dexes/uniswap/v4/**`, `contracts/protocols/lending/aave/**` | product adversarial I + IFacet/proxy J |
| `i-hook-cp` | `WP-I-HOOK-CP-001` (+ J smoke if same package files) | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/**` | `test/foundry/spec/hooks/**` I1/book free-extract |

#### Batch W1-D (3 slots)

| Slice ID | WPs packed | Primary production paths | Primary test paths |
|----------|------------|--------------------------|--------------------|
| `i-hook-dual` | `WP-I-HOOK-DUAL-001` | `contracts/hooks/uniswap/v4/standardExchange/dual/**` | Dual adversarial / pretransfer |
| `i-hook-sebuf` | `WP-I-HOOK-SEBUF-001` | none unless gate bug found | Orbital/Weighted/Bal/Curve SE buffer adversarial I |
| `i-claim` | `WP-I-CLAIM-001` | RebasingClaimToken / RebasingDETFToken Targets (foreign-token path) | claim trust-flag tests on **proxy** |

#### Batch W1-E (3 slots)

| Slice ID | WPs packed | Primary production paths | Primary test paths | Deps |
|----------|------------|--------------------------|--------------------|------|
| `i-se-ac` | `WP-I-SE-AC-001`, `WP-J-SE-AC-001` | facetFuncs only if OMIT | `test/**/standard-exchange/adversarial/**`; SE IFacet/proxy | **W0 on main** |
| `e5-aero` | `WP-E5-AERO-001` | `AerodromeStandardExchangeInTarget.sol`, `...OutTarget.sol` | route / adversarial E5 deadline | W0 preferred |
| `j-mgr-seigniorage` | `WP-J-MGR-001` | fee oracle Target/Facet/interface (`seeigniorage` typo fix) | proxy loupe + seigniorage call | none |

#### Batch W1-F (fill leftovers, ≤3 at a time)

| Slice ID | WPs packed | Notes |
|----------|------------|-------|
| `j-detf-cs-mb` | `WP-J-DETF-CS-MB-001` | Only if J not completed inside `i-detf-cs` / `i-detf-mb`. Touch **test-only** under stable + mixedBuffer IFacet/proxy. Start after both CODE slices on main if production facets needed. |
| `j-hooks` | `WP-J-HOOK-001` | Hook Target ⊆ facetFuncs ⊆ loupe ⊆ proxy |
| `j-rtr` | `WP-J-RTR-001` | Coordinator J only (I5/N in Wave 2 same tree optional) |

**Orchestrator rule for W1:** Always keep ≤3 active. Preferred fill order when a slot frees: remaining W1-A → W1-B → … → W1-F. Skip DualLiquidity spawn if `ALCHEMY_KEY` unset (mark BUILD_BLOCKED and queue retry).

---

### 3.4 Wave 2 — adversarial expand / N / Permit2 (after product I CODE for that surface)

| Batch | Slice IDs (≤3) | WPs | Deps |
|-------|----------------|-----|------|
| **W2-A** | `adv-se-ac`, `adv-detf-mb`, `adv-hook` | `WP-ADV-SE-AC-001`; `WP-ADV-DETF-MB-001`; `WP-ADV-HOOK-001` | W0; MB I CODE; Dual I if Dual ADV included |
| **W2-B** | `adv-se-uab`, `i5-rtr`, `n-fee` | `WP-ADV-SE-UAB-001`; `WP-I5-RTR-001`+`WP-N-RTR-001` (pack with `j-rtr` if J not done); `WP-N-FEE-001` | UAB I CODE preferred for I-named ADV |
| **W2-C** | `h-cam`, `j-mgr`, `j-router-uab` | `WP-H-CAM-001`; `WP-J-MGR-002`; `WP-J-ROUTER-UAB-001` | none hard |
| **W2-D** | `g-e-detf-cs` | `WP-G-E-DETF-CS-001` | CS CODE/I on main |

**Packing note:** Prefer one slice `rtr` for `WP-J-RTR-001` + `WP-I5-RTR-001` + `WP-N-RTR-001` if none of those landed in W1 — reduces worktrees.

```bash
# W2 examples
forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/routers/balancerV3-uniswapV4/**' --match-test 'test_I5|replay|spender|test_J' -vv
forge test --match-path 'test/**/fee/collector/**' -vv
forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**' -vv
```

---

### 3.5 Wave 3 — property layer (L1/L3)

No formal High WPs in the 44 for pure L1/L3-only products still G. Orchestrator opens **optional** slices only after I CODE on that product:

| Slice ID | Scope | Deps | Max concurrent |
|----------|-------|------|----------------|
| `l3-composed` | ComposedStable / MixedBuffer fuzz or handler if still G | CS/MB Wave 1 | ≤3 with other L3 |
| `l3-dual` | DualLiquidity L3 if product law allows (often RPC-deferred) | DL Wave 1 | |
| `l3-se-cam-v2` | Camelot/UniV2 L1 if still G | SE AC Wave 1–2 | |

If no L1/L3 gaps remain High after Wave 2, **skip Wave 3** and record in final report.

---

### 3.6 Wave 4 — P2 / hygiene

Opportunistic single-slot slices. Not ship-blocking. Examples: bare expectRevert cleanup outside already-closed WPs; stub retirement NatSpec.

---

## 4. Full WP → slice map (44/44)

| WP-ID | Slice ID | Wave |
|-------|----------|------|
| WP-I-COMMON-001 | `i-common` | 0 |
| WP-I-COMMON-002 | `i-common` | 0 |
| WP-I-CLONE-001 | `i-common` (checklist) + enforced by product slices | 0–1 |
| WP-I-DETF-MV-001 | `i-detf-mv` | 1 |
| WP-I-DETF-MV-002 | `i-detf-mv` | 1 |
| WP-K-DETF-MV-001 | `i-detf-mv` | 1 |
| WP-J-DETF-MV-001 | `i-detf-mv` | 1 |
| WP-I-DETF-SSE-001 | `i-detf-sse` | 1 |
| WP-I-DETF-SSE-002 | `i-detf-sse` | 1 |
| WP-J-DETF-SSE-001 | `i-detf-sse` | 1 |
| WP-I-DETF-SSE-CP-001 | `i-detf-sse-cp` | 1 |
| WP-J-DETF-SSE-CP-001 | `i-detf-sse-cp` | 1 |
| WP-I-DETF-SSE-UV4-001 | `i-detf-sse-uv4` | 1 |
| WP-I-DETF-CS-001 | `i-detf-cs` | 1 |
| WP-I-DETF-CS-002 | `i-detf-cs` | 1 |
| WP-G-E-DETF-CS-001 | `g-e-detf-cs` | 2 |
| WP-I-DETF-MB-001 | `i-detf-mb` | 1 |
| WP-ADV-DETF-MB-001 | `adv-detf-mb` | 2 |
| WP-J-DETF-CS-MB-001 | `j-detf-cs-mb` or packed into cs/mb | 1 |
| WP-I-DETF-DL-001 | `i-detf-dl` | 1 |
| WP-I-DETF-DL-002 | `i-detf-dl` | 1 |
| WP-J-DETF-DL-001 | `i-detf-dl` | 1 |
| WP-I-CLONE-UAB-001 | `i-se-uab` | 1 |
| WP-I-SE-UAB-001 | `i-se-uab` | 1 |
| WP-J-SE-UAB-001 | `i-se-uab` | 1 |
| WP-ADV-SE-UAB-001 | `adv-se-uab` | 2 |
| WP-J-ROUTER-UAB-001 | `j-router-uab` | 2 |
| WP-I-SE-AC-001 | `i-se-ac` | 1 |
| WP-J-SE-AC-001 | `i-se-ac` | 1 |
| WP-ADV-SE-AC-001 | `adv-se-ac` | 2 |
| WP-H-CAM-001 | `h-cam` | 2 |
| WP-E5-AERO-001 | `e5-aero` | 1 |
| WP-I-HOOK-CP-001 | `i-hook-cp` | 1 |
| WP-I-HOOK-DUAL-001 | `i-hook-dual` | 1 |
| WP-I-HOOK-SEBUF-001 | `i-hook-sebuf` | 1 |
| WP-J-HOOK-001 | `j-hooks` | 1 |
| WP-ADV-HOOK-001 | `adv-hook` | 2 |
| WP-I-CLAIM-001 | `i-claim` | 1 |
| WP-J-MGR-001 | `j-mgr-seigniorage` | 1 |
| WP-J-MGR-002 | `j-mgr` | 2 |
| WP-N-FEE-001 | `n-fee` | 2 |
| WP-I5-RTR-001 | `rtr` (or `i5-rtr`) | 2 |
| WP-N-RTR-001 | `rtr` | 2 |
| WP-J-RTR-001 | `rtr` or `j-rtr` | 1–2 |

---

## 5. Verification gate (per slice, before rebase/FF)

Orchestrator checks:

1. Subagent reports **touch set only** (spot-check `git diff --name-only main...HEAD`).
2. Acceptance forge command(s) from backlog/PRD for those WPs **exit 0**.
3. Anti-theater:
   - I1 tests do not transfer in-call.
   - J3 uses proxy address.
   - Short delivery expects `TransferDeltaInsufficient` (pull slices).
4. No `via_ir` introduced; no SUT mocks as sole proof.
5. Worklog snippet: WP-IDs closed, forge command, outcome (or BUILD_BLOCKED).

On failure: leave worktree; spawn fix subagent on **same** branch (counts as one slot); do not FF main.

---

## 6. Subagent prompt templates

### 6.1 Universal prefix (paste first)

```text
You are a Stage 3 gap-closure implementer for IndexedEx.

Laws (obey exactly):
- docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md §3–4, especially §4.3 (L-GAPS-9…13)
- docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md (this plan) for YOUR slice only
- docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md for your WP-IDs
- Linked TCA findings in docs/testing/coverage-audit/areas/**

Skills: crane-testing, crane-adversarial-testing (+ implementation-test-dod),
indexedex-testing, indexedex-adversarial-testing
[+ indexedex-uniswap-v4-hook-packages if hooks]

Hard rules:
- Work ONLY in this worktree/branch. Do not touch scripts/**.
- Do not edit files outside your production/test touch sets.
- No via_ir; no mock SUT as coverage; CREATE3 + registry/hook factory deploy.
- DETF roles only: rateAsset, pairToken, underlyingVault, vaultShare, detfToken, reservePool/reserveBpt, rebasingClaimToken.
- Pull law: credit claimed iff claimed <= observedDelta; else revert
  ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta).
- I1 no transfer; J3 on proxy; exact selectors.
- Prefer one tidy commit: gap_cover(<slice>): <summary>
- Run acceptance forge commands and paste results in your final report.
- Do not open PRs or push unless orchestrator asks; leave branch ready for rebase onto main.
- Forge may run 20–40+ minutes. Wait for process exit. NEVER kill solc/forge.
- Assume cache_forge/ + out/ were seeded by the orchestrator; do not wipe them.
```

### 6.2 Wave 0 — `i-common` (**DONE on main** — reference only)

```text
Wave 0 is complete on main (bbe501e). Do not re-open i-common unless regression.
ISecurePullErrors + BasicVaultCommon + Aero override + I1–I3 TrustFlags already shipped.
```

### 6.3 Wave 1 product CODE+I+J (template)

```text
[UNIVERSAL PREFIX]

Slice ID: <SLICE>
Branch: gap_cover/<SLICE>
WPs: <PACKED WP LIST>
Findings: <TCA-*>

Production touch set:
  <paths from backlog>

Test touch set:
  <paths from backlog>

Implement:
1. Package-local delta pull/burn (or receive) per L-GAPS-9; import ISecurePullErrors (already on main).
2. I1–I3 (+ K1 if in WP pack) on production proxy via gold TestBase / registry deploy.
3. J1–J3 if in pack (Target-derived controls; loupe; proxy smoke).
4. Runtime proof: I1 fails free credit on pre-fix narrative in worklog if you can show red→green.

Acceptance:
  <forge commands from plan §3 for this slice>
  Wait for forge exit (20–40+ min possible). NEVER kill solc/forge.

Out of scope: BasicVaultCommon (done); other packages; scripts/**; A–H rewrite unless WP is ADV
```

### 6.4 DualLiquidity special (`i-detf-dl`)

```text
[UNIVERSAL PREFIX + product template]

Slice: i-detf-dl
Fork required: FOUNDRY_PROFILE=fork --fork-url base_mainnet_alchemy
If ALCHEMY_KEY missing: stop with BUILD_BLOCKED; do not claim WP closed.

ShareInflation tests are A3 only — do not count as I1/K1.
```

### 6.5 Hook SEBUF (`i-hook-sebuf`)

```text
[UNIVERSAL PREFIX]

WPs: WP-I-HOOK-SEBUF-001
Law L-GAPS-11: KEEP leftover spendable design. Tests only unless you find book free-spend bug
(then fix book gate only and report).

Prove: unfunded fails; book not free-spent; leftover not double-spent (I3-class).
```

### 6.6 Orchestrator start message (**new goal** — resume from progress)

```text
You are the Stage 3 orchestrator for IndexedEx test coverage gap closure.

Read and obey:
  docs/testing/TEST_COVERAGE_GAP_CLOSURE_IMPLEMENTATION_PLAN.md  (§0.0 handoff FIRST)
  docs/testing/TEST_COVERAGE_GAP_CLOSURE_PRD.md
  docs/testing/coverage-audit/STAGE3_PROGRESS.md

Execution rules:
1. Max 3 concurrent implementer subagents / worktrees.
2. Wave 0 is DONE on main (e2e6482 stack). Do NOT redo i-common unless regression.
3. Before EVERY forge: seed worktree cache_forge/ + out/ from primary (plan §1.6).
   Prefer symlink lib/crane → primary. After green, copy cache/out back to primary.
4. NEVER kill long forge/solc runs. Cold compile 20–40+ min is normal. Wait for exit.
5. Each subagent: own worktree gap_cover_<slice>, branch gap_cover/<slice>.
6. On success: rebase onto main, merge --ff-only into main, remove worktree, free slot.
7. Serialize main updates; parallelize only coding worktrees.
8. Do not touch scripts/**.
9. Follow remaining §3 queue from W1-B; fill free slots from next ready slices.
10. Close all remaining WP-IDs (32 left). No session-budget DEFER. BUILD_BLOCKED only for L-GAPS-13.

Start: confirm main tip ≥ e2e6482; seed + spawn next W1-B slices (i-detf-mb, i-detf-dl if Alchemy, i-detf-sse-cp) ≤3 concurrent.
```

---

## 7. Runtime proof requirements

| Product / WP | Proof |
|--------------|--------|
| Commons | Already confirmed Stage 1; regression I1–I3 must stay green |
| Each Blocker CODE package | Hermetic I1 free-credit impossible (or fork for DualLiquidity) before closing severity |
| DualLiquidity | Fork proof only (L-GAPS-13) |
| Optional artifacts | `docs/testing/coverage-audit/repro/<FINDING_ID>/` — no secrets |

---

## 8. NEEDS_OWNER / non-blocking defaults

Implementors use defaults; do not invent product economics:

| Item | Default |
|------|---------|
| Camelot fork chain | Hermetic `WP-H-CAM-001` only |
| Uni V4 SE fork | Hermetic I closes |
| FeeCollector sync/push | No CODE; tests money-out only |
| ComposedStable nested G | N/A + NatSpec if product forbids; else test |
| Hook leftover | L-GAPS-11 tests only |

---

## 9. Program Definition of Done

- [ ] All **44** WP-IDs closed or explicitly BUILD_BLOCKED (L-GAPS-13 only) with reason — **not** session-budget DEFER
- [x] `main` history linear so far (FF stack of rebased `gap_cover/*` through W1-A)
- [x] Wave 0 commons + `ISecurePullErrors` on main before product pull I suites
- [x] No concurrent main merges; never >3 implementer worktrees (process rule)
- [x] No mock SUT coverage; no via_ir; DETF roles only (on closed slices)
- [ ] I1–I3 / J1–J3 / shared short error on **all remaining** money pretransfer diamonds
- [ ] DualLiquidity closed only with fork green (or open BUILD_BLOCKED)
- [x] `scripts/**` untouched by gap-closure agents (to date)
- [ ] Final orchestrator summary: all 44 accounted; forge evidence; residual BUILD_BLOCKED only

---

## 10. Orchestrator progress log (append-only)

Maintain in [`coverage-audit/STAGE3_PROGRESS.md`](./coverage-audit/STAGE3_PROGRESS.md):

```text
| UTC | Event | Slice | WPs | Result |
|-----|-------|-------|-----|--------|
| 2026-08-09 | ff-main | i-common | COMMON-001/002 CLONE-001 | green 15/15 basic, 5/5 I |
| 2026-08-09 | ff-main | i-detf-cs | CS-001/002 | green 4/4 I; nested SE approve fix |
| 2026-08-09 | ff-main | i-detf-mv | MV-001/002 K-MV J-MV | green 14/14 I/J/K |
| 2026-08-09 | ff-main | i-detf-sse | SSE-001/002 J-SSE | green 8/8 I/J |
| ... | spawn | i-detf-mb | ... | next |
```

---

## 11. Revision history

| Date | Change |
|------|--------|
| 2026-08-09 | Initial execute plan: ≤3 worktree subagents, rebase+FF linear main, packed slices for 44 WPs, product law from gap-closure PRD §4.3. |
| 2026-08-09 | **Resume handoff:** §0.0 progress (12/44 closed on `main` @ `e2e6482`); §0.3 forge patience (never kill solc); §1.6 seed `cache_forge`+`out`; forbid session-budget DEFER; new-goal orchestrator start message. |

---

## Appendix A — Quick batch wall (print for orchestrator)

```text
DONE: [i-common]
DONE: [i-detf-mv | i-detf-sse | i-detf-cs]

NEXT: [i-detf-mb | i-detf-dl | i-detf-sse-cp]     ← start here (≤3)
      [i-detf-sse-uv4 | i-se-uab | i-hook-cp]
      [i-hook-dual | i-hook-sebuf | i-claim]
      [i-se-ac | e5-aero | j-mgr-seigniorage]
      [j-detf-cs-mb | j-hooks | j-rtr]

W2:   [adv-se-ac | adv-detf-mb | adv-hook]
      [adv-se-uab | rtr | n-fee]
      [h-cam | j-mgr | j-router-uab]
      [g-e-detf-cs]

W3/W4: optional property / P2
```

Always ≤3 names active from any row (or across rows when filling freed slots with next ready deps).
