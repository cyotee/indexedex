# Implementation Plan — Security Audit Remediation (Stage 3)

| Field | Value |
|-------|--------|
| **Status** | **READY** — start only as a **new Stage 3 goal**. This file is the orchestrator runbook. |
| **Date** | 2026-08-13 |
| **Kind** | Execute plan: parallel `sec_fix_*` worktrees + implementer subagents |
| **Authorizes** | Stage 3 production + Foundry tests **in a later goal** (not the Stage 2 authorship run) |
| **Normative law** | [`SECURITY_AUDIT_REMEDIATION_PRD.md`](./SECURITY_AUDIT_REMEDIATION_PRD.md) §§3–4, 6–9, L-SEC-1…14 |
| **WP inventory** | [`audit/WORK_PACKAGE_BACKLOG.md`](./audit/WORK_PACKAGE_BACKLOG.md) — **36** High `WP-SEC-*`; **Critical: none** |
| **Findings** | [`audit/AGGREGATE.md`](./audit/AGGREGATE.md) + `areas/**` + `specialists/**` |
| **Progress log** | Create [`audit/STAGE3_REMEDIATION_PROGRESS.md`](./audit/STAGE3_REMEDIATION_PROGRESS.md) on first Stage 3 FF (orchestrator-owned) |
| **Max concurrent** | **3** live `sec_fix_*` worktrees (L-SEC-12; not raised) |
| **Worktree / branch** | dir `.worktrees/sec_fix_<slice>` · branch `sec_fix/<slice>` (L-SEC-8) |
| **Merge model** | Rebase slice onto `main` → **fast-forward** `main` (linear). Serialize integration even if coding was parallel. |
| **Forge artifacts** | `foundry.toml`: `cache_path = 'cache_forge'`, `out = 'out'`. Seed **every** new worktree from a warm checkout **before** first `forge`. |
| **Collision** | Gap-closure is **44/44 closed**. Do **not** reopen OWNED_ELSEWHERE primary files (PRD §6). Never open `gap_cover_*`. |

---

## 0. Next-agent handoff (paste into a **new** Stage 3 goal)

> Execute Stage 3 security-audit remediations from `docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md` until all **36** High `WP-SEC-*` are closed or only `BUILD_BLOCKED` (missing Alchemy for fork-first DualLiquidity / Slipstream) / owner-gated `WP-SEC-TOKEN-001` remain. Orchestrator only: create ≤3 `sec_fix_*` worktrees at a time, **seed `cache_forge/` + `out/` from the warm primary checkout before any forge**, spawn one implementer subagent per worktree, verify PRD §9 matchers, rebase + FF `main`, copy updated artifacts **back** to the warm seed, then start the next batch. Never kill long `solc`/`forge` runs. Never `via_ir`. Never reopen OWNED_ELSEWHERE pull bodies. Wave 0 `e6-common` is serial and must land before AMM v2 Out slices.

**Do not start that goal from the Stage 2 planning session.**

---

## 1. Orchestrator charter

You are the **Stage 3 orchestrator**. You do **not** implement CODE/tests except worktree/cache setup, acceptance spot-check, and merge.

1. Read this plan + PRD §§3–4 and §9 **before** the first spawn.
2. Keep `slots_free ≤ 3`. One worktree = one implementer = one slice ID.
3. **Seed compile artifacts** (§3) **before** the child runs `forge`. Prefer incremental compiles over three simultaneous cold solc runs.
4. After a child returns: verify §7 → rebase → FF `main` → harvest `cache_forge/` + `out/` back to primary → remove worktree → free a slot.
5. Never two live agents on the same production or primary test file. Never a fourth concurrent implementer. Never `gap_cover_*`.
6. **Never kill** `forge` / `solc`. First-compile timeouts: **2–4 hours**, not 10–20 minutes.

### 1.1 Concurrency state machine

```text
slots_free = 3
queue = [W0, then W1-A … W1-F, then W3]   # §4 batches

while queue not empty OR active worktrees:
  while slots_free > 0 AND next slice deps satisfied:
    create worktree + branch from current main
    seed cache_forge/ + out/ + symlink lib/crane     # §3 — REQUIRED
    spawn implementer subagent with §8 prompt        # slots_free -= 1
  wait for any subagent completion
  verify acceptance (§7)
  rebase branch onto main
  fast-forward main                                  # serialize this step
  harvest WT cache_forge/ + out/ → primary seed
  remove worktree                                    # slots_free += 1
```

**Wave 0:** `slots_free` starts at **1** (`e6-common` only). After that slice FFs, `slots_free = 3`.

**Fill rule:** when a slot frees, start the next unused slice in §4 order whose deps are on `main`. Do not skip ahead to W3.

### 1.2 Hard rules (copy into every child)

- **No `via_ir`.** No mock SUT as proof. DETF role names only (`rateAsset`, `pairToken`, `underlyingVault` / `standardExchangeVault`, `vaultShare`, `detfToken` / `address(this)`, `reservePool` / `reserveBpt`, `rebasingClaimToken`).
- Facets: CREATE3 / FactoryService. Vault/DETF DFPkgs: **IndexedEx manager vault registry**.
- Pass = **exploit blocked**. Never greenwash free mint / `max−used` skim.
- **I1:** `pretransferred=true`, **no** in-call transfer, inventory already held → revert. Happy pretransfer + real transfer is **not** I1.
- **J3:** call the **proxy** after registry/factory deploy, never the facet impl address.
- Proof-first if the slice flag is yes: red test or throwaway repro **before** claiming CODE closed.
- Do **not** reopen `BasicVaultCommon._secureTokenTransfer`, MultiVault `_pullToken`, Uni V3 `_secureTokenTransfer`, shared claim-token pull, hook I, Coordinator I5/J/N.
- DualLiquidity: never restore no-op `_receive` or `held − amountIn` refund. Owner-silent default = PRD §4 option **B** (keep same-tx; invert theater).
- Edit **only** this slice’s touch-set. Do not edit `scripts/**`.
- Seed `cache_forge/` + `out/` before first forge. Never delete those dirs. Never kill forge/solc.

### 1.3 Forge patience

Monorepo hermetic compile commonly takes **20–40+ minutes** with little output. That is **normal**.

| Rule | Detail |
|------|--------|
| Never assume stuck | A single solc process at high CPU/RAM and no new lines is expected. |
| Never kill the build | A mid-run kill discards elapsed compile and forces a near-full rebuild. |
| Timeouts | Hours (2–4h) for first compile in a seeded worktree. |
| After green | Copy `cache_forge/` + `out/` **back** to the warm primary so the next slice is incremental. |
| Parallel solc | ≤3 worktrees may forge. Prefer **seeded** incremental compiles. Serialize only if the machine OOMs — not because “slow.” |

---

## 2. Git / worktree protocol (linear history)

### 2.1 Naming

| Item | Pattern | Example |
|------|---------|---------|
| Slice ID | from §4 (no `sec_fix_` prefix in the ID) | `e6-common`, `cam-se` |
| Worktree dir | `.worktrees/sec_fix_<slice>` | `.worktrees/sec_fix_cam-se` |
| Branch | `sec_fix/<slice>` | `sec_fix/cam-se` |
| Commit subject | `sec_fix(<slice>): <imperative>` | `sec_fix(e6-common): cap refund and self-burn to this-call unused` |

Prefix is always `sec_fix_`. Never `gap_cover_`.

### 2.2 Create worktree (orchestrator, from primary `main`)

```bash
# Primary checkout must be the warm REPO (has cache_forge/ + out/)
REPO="$(pwd)"   # indexedex root
git checkout main

SLICE=cam-se    # example — use the next free slice ID from §4
git branch "sec_fix/${SLICE}" main
git worktree add ".worktrees/sec_fix_${SLICE}" "sec_fix/${SLICE}"

# REQUIRED before any forge in the child:
#   seed cache_forge/ + out/  (§3)
#   symlink lib/crane         (§3)
```

### 2.3 Integrate (orchestrator only — one slice at a time)

```bash
REPO="$(pwd)"
SLICE=e6-common
WT="${REPO}/.worktrees/sec_fix_${SLICE}"

git checkout main
git -C "$WT" rebase main
git merge --ff-only "sec_fix/${SLICE}"

# Harvest compile artifacts BEFORE removing the worktree (§3.2)
# then:
git worktree remove "$WT"
git branch -d "sec_fix/${SLICE}"   # optional after FF
```

**Conflict on rebase:** keep the same worktree; spawn a fix subagent on the same branch (still one of the three slots). No merge commits onto `main`. Never two FFs at once. Parallel worktrees may **keep coding** while one slice integrates.

### 2.4 Integration lock

While rebasing/FF one slice, do not start FF of another. Coding in other live worktrees may continue.

---

## 3. Seed `cache_forge/` + `out/` (required — expedites compile)

**Do this every time you create or reuse a worktree, before the first `forge test` / `forge build`.**

This repo’s `foundry.toml` uses **`cache_path = 'cache_forge'`** and **`out = 'out'`**. Do **not** invent a `cache/` path.

Warm artifacts live on the primary checkout (or the last green worktree):

| Path | Role |
|------|------|
| `<repo>/cache_forge/` | Foundry solidity file cache |
| `<repo>/out/` | Compiled artifacts |

Seeded cache skips **unchanged** units. CODE edits still recompile those packages — expected, and far cheaper than a cold monorepo compile.

### 3.1 Seed into a new worktree

```bash
REPO="$(pwd)"   # primary indexedex checkout with warm cache
SLICE=cam-se
WT="${REPO}/.worktrees/sec_fix_${SLICE}"

seed_dir() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "${src}/" "${dest}/"
  else
    cp -a "${src}/." "${dest}/"
  fi
}

SRC_CACHE="${SRC_CACHE:-${REPO}/cache_forge}"
SRC_OUT="${SRC_OUT:-${REPO}/out}"

if [[ -d "$SRC_CACHE" ]]; then seed_dir "$SRC_CACHE" "${WT}/cache_forge"; fi
if [[ -d "$SRC_OUT" ]]; then seed_dir "$SRC_OUT" "${WT}/out"; fi

# Avoid nested crane reinstall thrash
if [[ -d "${REPO}/lib/crane" && ! -L "${WT}/lib/crane" ]]; then
  rm -rf "${WT}/lib/crane"
  ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
fi
```

**If the primary `cache_forge/` / `out/` is empty** (new clone): do **not** start three cold compiles. Run **one** seeded (or one cold) Wave 0 forge to completion, harvest artifacts, **then** fan out.

### 3.2 Harvest after a green slice (before `worktree remove`)

```bash
seed_dir "${WT}/cache_forge" "${REPO}/cache_forge"
seed_dir "${WT}/out"         "${REPO}/out"
```

Next slices inherit that incremental cache. **Never** delete `out/` or `cache_forge/` “to be safe” mid-program.

### 3.3 What the child must not do

- Do not set `HOME` / Foundry homes / cargo homes into scratch.
- Do not `rm -rf out cache_forge`.
- Do not enable `via_ir` or add package-specific IR profiles.
- Do not `forge clean` unless the orchestrator orders it (it throws away the seed).

---

## 4. Slice schedule (conflict-free, ≤3 concurrent)

Slice IDs below are the **only** spawn keys. Cross-package Stage 1 WPs (`WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001`, `WP-SEC-CROPS-001`) are **split by package** (L-SEC-13). Same WP-ID, different slices — do not invent a fourth tree on those files.

### 4.1 Wave 0 — serial (1 slot)

| Batch | Slice ID | WPs | Production (primary) | Tests (primary) | Deps |
|-------|----------|-----|----------------------|-----------------|------|
| **W0** | `e6-common` | `WP-SEC-E6-COMMON-001` | `contracts/vaults/basic/BasicVaultCommon.sol` (`_refundExcess`, `_secureSelfBurn` only). Optional NatSpec on `ISecurePullErrors.sol`. **Not** `_secureTokenTransfer` | `test/foundry/spec/vaults/basic/**` | none |

**W0 DoD**

- [ ] Refund = this-call unused inbound (`min(max−used, unused U)`), not raw `max−used` against booked `R`
- [ ] Self-burn does not sweep leftover `address(this)` shares that were not delivered this call
- [ ] I1–I3 on token pull stay green (do not regress I-ABS)
- [ ] Proof-first: seed inventory; fat max + transfer-only-`used` does not skim `R`

```bash
forge test --match-path 'test/foundry/spec/vaults/basic/**' \
  --match-test 'test_E6_|test_I1_|test_I2_|test_I3_' -vv
```

---

### 4.2 Wave 1 — package slices (batches of ≤3, after W0 on `main`)

All Wave 1 slices are **file-disjoint**. Prefer filling free slots immediately when a sibling finishes (do not wait for the whole batch if deps are met). AMM v2 Out slices (`cam-se`, `aero-se`, `univ2-se`) **require W0 on `main`**.

#### Batch W1-A (3 slots) — highest new extracts

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `cam-se` | `WP-SEC-CAM-OUT-001` + Camelot portion of `WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol`; `…InTarget.sol` | `test/**/camelot/v2/**` | **yes** |
| `aave-loop` | `WP-SEC-I-AAVE-LOOP-001` | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchange{In,Out}Target.sol`. **Not** `aave/v3.6/**` | `test/**/aave/cross-version/**` | **yes** |
| `bal-single-i` | `WP-SEC-I-BAL-SINGLE-001` | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` | `test/**/balancer/v3/pools/**` | **yes** |

```bash
# cam-se
forge test --match-path 'test/**/camelot/**' \
  --match-test 'test_CAM_OUT_|test_E6_|test_R4_|test_A0_|test_I1_lpDeposit' -vv

# aave-loop
forge test --match-path 'test/**/aave/cross-version/**' \
  --match-test 'test_I1_|test_I2_|test_I3_' -vv

# bal-single-i
forge test --match-path 'test/**/balancer/v3/pools/**' \
  --match-test 'test_I1_|test_E6_|test_M_' -vv
```

#### Batch W1-B (3 slots)

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `aero-se` | Aero portion of `WP-SEC-E6-SE-001`, `WP-SEC-A0-SE-001`, `WP-SEC-I-SE-4626-001` | `contracts/protocols/dexes/aerodrome/v1/**` Out Execute + In (zap-in / LP-deposit) + DFPkg `decimalOffset` only | `test/**/aerodrome/v1/**` | **yes** |
| `slip-e6` | `WP-SEC-E6-SLIP-001` | `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol`; `…OutTarget.sol` | `test/**/slipstream/**` | **yes** |
| `univ3-e6` | `WP-SEC-E6-U3-001`, `WP-SEC-I-U3-SHARE-001`, `WP-SEC-A0-U3-001` | `contracts/protocols/dexes/uniswap/v3/**` In / Out / PositionImport. **Not** `_secureTokenTransfer` | `test/**/uniswap/v3/**` | **yes** |

```bash
# aero-se
forge test --match-path 'test/**/aerodrome/v1/**' \
  --match-test 'test_E6_|test_A0_|test_I1_lpDeposit' -vv

# slip-e6  (fork if that is the gold path)
forge test --match-path 'test/**/slipstream/**' \
  --match-test 'test_E6_|test_I1_|test_J' -vv
# if hermetic cannot hit CL books:
# FOUNDRY_PROFILE=fork forge test --match-path 'test/**/slipstream/**' \
#   --match-test 'test_E6_|test_I1_|test_J' --fork-url base_mainnet_alchemy -vv

# univ3-e6
forge test --match-path 'test/**/uniswap/v3/**' \
  --match-test 'test_E6_|test_I1_|test_A0_' -vv
```

#### Batch W1-C (3 slots)

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `univ2-se` | Uni V2 portion of E6-SE / R4 / A0 / I-SE-4626 + Uni V2 portion of `WP-SEC-CROPS-001` | `contracts/protocols/dexes/uniswap/v2/**` In/Out + Common disable on **Out** / `vaultShare` exit | `test/**/uniswap/v2/**` | **yes** (E6/R4/A0) |
| `univ4-se` | `WP-SEC-E6-U4-001`, `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001` | `contracts/protocols/dexes/uniswap/v4/**` **SE vault only**. Not DETF/hooks; not token `_secureTokenTransfer` | SE vault tests under `test/**/uniswap/v4/**` (not `…/standardExchange/{weighted,orbital,stable}`) | **yes** |
| `detf-cs` | `WP-SEC-DETF-CS-LOCK-001`, `WP-SEC-DETF-CS-TOKEN-001`, `WP-SEC-DETF-CS-A0-001` | CS `ExchangeIn.sol` + `BondingFacet.sol` + satellite `detfToken` DFPkg/Targets. **Not** MixedBuffer pull | `test/**/stable/**` + MixedBuffer `test_A0_*` only | **yes** (lock + minter) |

```bash
# univ2-se
forge test --match-path 'test/**/uniswap/v2/**' \
  --match-test 'test_E6_|test_R4_|test_A0_|test_I1_lpDeposit|test_CROPS_' -vv

# univ4-se (narrow to SE vault trees; do not run extra DETF families)
forge test --match-path 'test/**/uniswap/v4/**' \
  --match-test 'test_E6_|test_IMP_|test_A0_' -vv

# detf-cs
forge test --match-path 'test/**/stable/**' --match-test 'test_C|test_A0_|test_F_' -vv
forge test --match-path 'test/**/mixedBuffer/**' --match-test 'test_A0_' -vv
```

#### Batch W1-D (3 slots)

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `detf-uv4-extra` | UV4-BURN, I-SUITE, J, A0, NFT, ORB-CLAIM + UV4 extra CROPS | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**`; `…/uniswap/v4/common/{nft,rebasing}/**`. **Not** CP-single; **not** mint `_pullToken` body | matching `test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**` | **yes** (burn + NFT) |
| `detf-dl` | DL-A0, DL-DELTA, DL-I-HONESTY + DualLiq CROPS | `…/crossVersion/v2/**` MathLib / Common / In-Out. Do **not** restore no-op receive | `test/foundry/fork/**/crossVersion/v2/**` | **yes** (A0 + delta) |
| `detf-mv` | `WP-SEC-PKG-MV-001`, `WP-SEC-DETF-MV-A0-001` | `MultiVaultWeightedDetfDFPkg.sol` `processArgs` only. **Not** I/J/K Common/Targets | `test/**/multi-vault-weighted/**` | no |

```bash
# detf-uv4-extra
forge test --match-path 'test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**' \
  --match-test 'test_I|test_J|test_A0_|test_depositClaim|test_F1_|test_CROPS_' -vv

# detf-dl  (L-SEC-5 / L-SEC-6) — skip spawn if ALCHEMY_KEY unset → BUILD_BLOCKED
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/**/crossVersion/v2/**' \
  --match-test 'test_I|test_A0_|test_K1_|test_CROPS_' \
  --fork-url base_mainnet_alchemy -vv

# detf-mv
forge test --match-path 'test/**/multi-vault-weighted/**' \
  --match-test 'test_PKG_|test_C1_|test_A0_' -vv
```

#### Batch W1-E (3 slots)

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `detf-sse` | `WP-SEC-DETF-SSE-A0-001` + Single SE / Uni V4 CP CROPS | disable-gated `*Common.sol` / Bonding / Out only. **Not** `_pullToken` | SSE + CP adversarial `test_A0_*`, `test_CROPS_*` | no (A0 TEST) |
| `lst-ij` | `WP-SEC-I-LST-001`, `WP-SEC-J-LST-001` | none unless PAT-J-OMIT | `test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/**` | no |
| `erc4626-ij` | `WP-SEC-I-ERC4626-001` | none | `test/foundry/spec/vaults/standard/erc4626/**` | no |

```bash
# detf-sse — Balancer Single SE + Uni V4 CP
forge test --match-path 'test/**/standardExchange/single/**' --match-test 'test_A0_|test_CROPS_' -vv
forge test --match-path 'test/**/uniswap/v4/standardExchange/constantProduct/single/**' \
  --match-test 'test_A0_|test_CROPS_' -vv

# lst-ij
forge test --match-path 'test/foundry/spec/protocol/staking/**' \
  --match-test 'test_I1_|test_I2_|test_I3_|test_J' -vv

# erc4626-ij
forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/**' \
  --match-test 'test_I1_|test_I2_|test_I3_|test_J' -vv
```

#### Batch W1-F (1 slot)

| Slice ID | WPs packed | Production | Tests | Proof-first |
|----------|------------|------------|-------|-------------|
| `detf-com-j` | `WP-SEC-DETF-COM-J-001` | none unless PAT-J-OMIT. **Not** `WP-I-CLAIM-001` pull | claim + NFT vault `test_J*` after CREATE3/registry | no |

```bash
forge test --match-path 'test/**/claimToken/**' --match-test 'test_J' -vv
forge test --match-path 'test/**/bondNft/**' --match-test 'test_J' -vv
```

---

### 4.3 Wave 3 — owner-gated (1 slot)

| Batch | Slice ID | WPs | Deps |
|-------|----------|-----|------|
| **W3** | `token-policy` | `WP-SEC-TOKEN-001` | All Wave 1 FFd **and** written owner policy (LOCKED 2026-08-13: FoT forbidden; no rebasing underlyings; non-18 decimals allowed / scale to 18; pause accepted; docs + `test_L2_FoT_forbidden` only) |

Do **not** invent an allowlist. Policy is recorded in [`docs/agent/INDEXEDEX_AGENT_LAW.md`](../agent/INDEXEDEX_AGENT_LAW.md) § Token policy.

```bash
forge test --match-test 'test_L2_FoT_credits_actualIn|test_L2_FoT_forbidden' -vv
```

---

## 5. Full WP → slice map (36/36)

| WP-ID | Slice ID(s) | Wave |
|-------|-------------|------|
| `WP-SEC-E6-COMMON-001` | `e6-common` | 0 |
| `WP-SEC-CAM-OUT-001` | `cam-se` | 1 |
| `WP-SEC-E6-SE-001` | `cam-se` + `aero-se` + `univ2-se` (package split) | 1 |
| `WP-SEC-R4-SE-001` | `cam-se` + `univ2-se` | 1 |
| `WP-SEC-A0-SE-001` | `cam-se` + `aero-se` + `univ2-se` | 1 |
| `WP-SEC-I-SE-4626-001` | `cam-se` + `aero-se` + `univ2-se` | 1 |
| `WP-SEC-I-AAVE-LOOP-001` | `aave-loop` | 1 |
| `WP-SEC-E6-SLIP-001` | `slip-e6` | 1 |
| `WP-SEC-E6-U3-001` | `univ3-e6` | 1 |
| `WP-SEC-I-U3-SHARE-001` | `univ3-e6` | 1 |
| `WP-SEC-A0-U3-001` | `univ3-e6` | 1 |
| `WP-SEC-E6-U4-001` | `univ4-se` | 1 |
| `WP-SEC-IMP-U4-001` | `univ4-se` | 1 |
| `WP-SEC-A0-U4-001` | `univ4-se` | 1 |
| `WP-SEC-I-BAL-SINGLE-001` | `bal-single-i` | 1 |
| `WP-SEC-DETF-UV4-BURN-I1-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-UV4-I-SUITE-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-UV4-J-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-UV4-A0-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-UV4-NFT-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-UV4-ORB-CLAIM-001` | `detf-uv4-extra` | 1 |
| `WP-SEC-DETF-CS-LOCK-001` | `detf-cs` | 1 |
| `WP-SEC-DETF-CS-TOKEN-001` | `detf-cs` | 1 |
| `WP-SEC-DETF-CS-A0-001` | `detf-cs` | 1 |
| `WP-SEC-DETF-DL-A0-001` | `detf-dl` | 1 |
| `WP-SEC-DETF-DL-DELTA-001` | `detf-dl` | 1 |
| `WP-SEC-DETF-DL-I-HONESTY-001` | `detf-dl` | 1 |
| `WP-SEC-CROPS-001` | `univ2-se` + `detf-uv4-extra` + `detf-dl` + `detf-sse` (package split) | 1 |
| `WP-SEC-PKG-MV-001` | `detf-mv` | 1 |
| `WP-SEC-DETF-MV-A0-001` | `detf-mv` | 1 |
| `WP-SEC-DETF-SSE-A0-001` | `detf-sse` | 1 |
| `WP-SEC-DETF-COM-J-001` | `detf-com-j` | 1 |
| `WP-SEC-I-LST-001` | `lst-ij` | 1 |
| `WP-SEC-J-LST-001` | `lst-ij` | 1 |
| `WP-SEC-I-ERC4626-001` | `erc4626-ij` | 1 |
| `WP-SEC-TOKEN-001` | `token-policy` | 3 |

A split WP is **closed** only when **every** listed slice has merged its portion.

---

## 6. Product law for implementers (no alternatives)

| Topic | Rule |
|-------|------|
| Refund / E6 | Cap to **this-call unused inbound**. Seed booked `R`. Fat `max` + transfer of only `used` must not pay `R`. |
| I credit | L-CLAIM-3 / L-GAPS-9: `claimed ≤ delta` (or durable `U = B − R` where the package already books `R`) → credit `claimed`; else `TransferDeltaInsufficient`. No exact-delta grief. |
| I1 | No in-call transfer. Inventory already held. Expect revert. |
| J | Target ⊆ `facetFuncs` ⊆ cuts ⊆ loupe ⊆ **proxy**. |
| A0 | Donate / pre-seed **before** first mint or first bond; first mover cannot drain residual. |
| CROPS disable | After `setVaultAddressDisabled(true)`, mature `closeBondMature` / `redeemClaim` / user `exchangeOut` must still work. Inbound-only gates may remain. Do not add disable to MultiVault. |
| DualLiquidity | Default **B**: keep same-tx; invert `pushThenTrue` / Permit2-`true` / surplus-refund-to-caller. Never restore no-op or `held−amountIn`. ShareInflation is **not** I. |
| Orbital `depositClaim` | Default: implement (copy weighted). Owner may amend the family PRD instead. |
| CS leftover minter | Unown / revoke after deploy. `owner()==0`; stranger mint reverts. |
| PkgArgs `vaultShare` | No silent `address(0)` alias to `vaults[i]`. Require registered SE share. |
| Seigniorage | Documented open-threshold skew is ACCEPTED_RISK. Do not “fix” it. |

---

## 7. Verification gate (per slice, before rebase/FF)

Orchestrator checks:

1. `git -C "$WT" diff --name-only main...HEAD` is inside the slice touch-set (spot-check).
2. The **exact** §4 forge matcher(s) for that slice **exit 0** (or `BUILD_BLOCKED` with missing `ALCHEMY_KEY` only).
3. Required `test_<ID>_` names exist (`rg 'function test_E6_|function test_I1_|function test_A0_|function test_J'` on the test touch-set).
4. Anti-theater: I1 does not transfer in-call; J3 uses proxy; no bare `expectRevert()` as the only negative.
5. No `via_ir`; no SUT mocks as sole proof; DETF role names in new tests.
6. Proof-first slices: worklog shows a pre-fix fail or repro **or** an explicit “exploit blocked” post-fix path (seed inventory / no transfer).
7. Worklog: WP-IDs closed, forge command, outcome.

On failure: leave the worktree; spawn a fix subagent on the **same** branch (one slot); do not FF `main`.

---

## 8. Subagent prompt (orchestrator fills the header, then pastes)

### 8.1 Universal prefix

```text
You are a Stage 3 security-remediation implementer for IndexedEx.

CWD: <REPO>/.worktrees/sec_fix_<SLICE>
Branch: sec_fix/<SLICE>
Do not merge. Do not touch other worktrees. Leave the branch for the orchestrator to rebase+FF.

Laws (obey exactly):
- docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md §§3–4, 8–9
- docs/security/SECURITY_AUDIT_REMEDIATION_IMPLEMENTATION_PLAN.md — YOUR slice only
- docs/security/audit/WORK_PACKAGE_BACKLOG.md for your WP-IDs
- Linked SEC-* in docs/security/audit/areas/** and specialists/**
- Claude.md + docs/agent/INDEXEDEX_AGENT_LAW.md (DETF/deploy)

Skills: crane-testing, crane-adversarial-testing + implementation-test-dod.md,
indexedex-testing, indexedex-adversarial-testing

Hard rules:
- No via_ir. DETF role names only. CREATE3 facets; vault/DETF DFPkg via manager registry.
- No mock SUT. Pass = exploit blocked.
- I1: pretransferred=true, NO in-call transfer, inventory already held → revert.
  Happy pretransfer + real transfer is NOT I1.
- J3: call the proxy after registry/factory deploy, never facet impl.
- Proof-first if this slice flag is yes: red test or throwaway repro BEFORE claiming CODE closed.
- Do not reopen _secureTokenTransfer / MultiVault _pullToken / Uni V3 pull / shared claim pull.
- DualLiquidity: never restore no-op _receive or held−amountIn refund.
- Edit ONLY the production + test touch-set below.
- cache_forge/ + out/ should already be seeded. Do not forge clean. Do not kill forge/solc.
  First compile can take 20–40+ minutes; wait for process exit (timeout hours).
```

### 8.2 Per-slice fill-in (one block per spawn)

Replace the header placeholders, then append **one** of these bodies.

#### `e6-common`

```text
SLICE: e6-common
WPs: WP-SEC-E6-COMMON-001
Production: contracts/vaults/basic/BasicVaultCommon.sol (_refundExcess, _secureSelfBurn only)
Tests: test/foundry/spec/vaults/basic/**
Out of scope: _secureTokenTransfer body; all SE/DETF packages
Proof-first: yes
Acceptance:
  forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_E6_|test_I1_|test_I2_|test_I3_' -vv
```

#### `cam-se`

```text
SLICE: cam-se
WPs: WP-SEC-CAM-OUT-001 + Camelot portions of WP-SEC-E6-SE-001, WP-SEC-R4-SE-001, WP-SEC-A0-SE-001, WP-SEC-I-SE-4626-001
Production: contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol; …InTarget.sol
Tests: test/**/camelot/v2/**
Out of scope: Aero/Uni V2; BasicVaultCommon; Camelot H tests as coverage
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/camelot/**' --match-test 'test_CAM_OUT_|test_E6_|test_R4_|test_A0_|test_I1_lpDeposit' -vv
Notes: pay tokenOut to recipient; do not overwrite amountIn; Route4 convert vs pre-deposit reserve.
```

#### `aave-loop`

```text
SLICE: aave-loop
WPs: WP-SEC-I-AAVE-LOOP-001
Production: contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol; …OutTarget.sol
Tests: test/**/aave/cross-version/**
Out of scope: aave/v3.6/** (Stata); BasicVaultCommon
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/aave/cross-version/**' --match-test 'test_I1_|test_I2_|test_I3_' -vv
Notes: I1 no transfer on In and Out; call the proxy.
```

#### `bal-single-i`

```text
SLICE: bal-single-i
WPs: WP-SEC-I-BAL-SINGLE-001
Production: contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol
Tests: test/**/balancer/v3/pools/**
Out of scope: buffer pools; Coordinator; WP-J-ROUTER-UAB-001
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/balancer/v3/pools/**' --match-test 'test_I1_|test_E6_|test_M_' -vv
```

#### `aero-se`

```text
SLICE: aero-se
WPs: Aero portions of WP-SEC-E6-SE-001, WP-SEC-A0-SE-001, WP-SEC-I-SE-4626-001
Production: contracts/protocols/dexes/aerodrome/v1/** Out Execute + In (zap-in / LP-deposit) + DFPkg decimalOffset only
Tests: test/**/aerodrome/v1/**
Out of scope: Slipstream; BasicVaultCommon body; deadline CODE (already closed)
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/aerodrome/v1/**' --match-test 'test_E6_|test_A0_|test_I1_lpDeposit' -vv
```

#### `slip-e6`

```text
SLICE: slip-e6
WPs: WP-SEC-E6-SLIP-001
Production: contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol; …OutTarget.sol
Tests: test/**/slipstream/**
Out of scope: Aero v1; Uni V3
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/slipstream/**' --match-test 'test_E6_|test_I1_|test_J' -vv
Notes: J3 on proxy. If hermetic cannot hit CL books, FOUNDRY_PROFILE=fork + *_alchemy. Missing ALCHEMY_KEY → BUILD_BLOCKED.
```

#### `univ3-e6`

```text
SLICE: univ3-e6
WPs: WP-SEC-E6-U3-001, WP-SEC-I-U3-SHARE-001, WP-SEC-A0-U3-001
Production: contracts/protocols/dexes/uniswap/v3/** In / Out / PositionImport
Tests: test/**/uniswap/v3/**
Out of scope: _secureTokenTransfer body (WP-I-CLONE-001)
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/uniswap/v3/**' --match-test 'test_E6_|test_I1_|test_A0_' -vv
```

#### `univ2-se`

```text
SLICE: univ2-se
WPs: Uni V2 portions of WP-SEC-E6-SE-001, WP-SEC-R4-SE-001, WP-SEC-A0-SE-001, WP-SEC-I-SE-4626-001 + Uni V2 CROPS
Production: contracts/protocols/dexes/uniswap/v2/**
Tests: test/**/uniswap/v2/**
Out of scope: manager disable API; Aero/Camelot
Proof-first: yes (E6/R4/A0)
Acceptance:
  forge test --match-path 'test/**/uniswap/v2/**' --match-test 'test_E6_|test_R4_|test_A0_|test_I1_lpDeposit|test_CROPS_' -vv
Notes: setVaultAddressDisabled(true) then exchangeOut must still work.
```

#### `univ4-se`

```text
SLICE: univ4-se
WPs: WP-SEC-E6-U4-001, WP-SEC-IMP-U4-001, WP-SEC-A0-U4-001
Production: contracts/protocols/dexes/uniswap/v4/** SE vault only
Tests: Uni V4 SE vault tests only (not DETF weighted/orbital/quad)
Out of scope: DETF/hooks; token _secureTokenTransfer
Proof-first: yes
Acceptance:
  forge test --match-path 'test/**/uniswap/v4/**' --match-test 'test_E6_|test_IMP_|test_A0_' -vv
Notes: untrusted importPosition owner must revert.
```

#### `detf-cs`

```text
SLICE: detf-cs
WPs: WP-SEC-DETF-CS-LOCK-001, WP-SEC-DETF-CS-TOKEN-001, WP-SEC-DETF-CS-A0-001
Production: …/stable/common/ComposedStableCommonDetfExchangeIn.sol; …BondingFacet.sol; RebasingDETFToken DFPkg/Targets
Tests: test/**/stable/** + MixedBuffer test_A0_* only
Out of scope: MixedBuffer pull; shared claim token
Proof-first: yes (lock + minter)
Acceptance:
  forge test --match-path 'test/**/stable/**' --match-test 'test_C|test_A0_|test_F_' -vv
  forge test --match-path 'test/**/mixedBuffer/**' --match-test 'test_A0_' -vv
```

#### `detf-uv4-extra`

```text
SLICE: detf-uv4-extra
WPs: WP-SEC-DETF-UV4-BURN-I1-001, …-I-SUITE-001, …-J-001, …-A0-001, …-NFT-001, …-ORB-CLAIM-001 + UV4 CROPS
Production: contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**; …/common/{nft,rebasing}/**
Tests: matching test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**
Out of scope: CP-single; mint _pullToken helper; shared detf/common claim
Proof-first: yes (burn + NFT)
Acceptance:
  forge test --match-path 'test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**' \
    --match-test 'test_I|test_J|test_A0_|test_depositClaim|test_F1_|test_CROPS_' -vv
Notes: burn must _pullToken. I1 no transfer on burn. J3 proxy. Default: add orbital depositClaim.
```

#### `detf-dl`

```text
SLICE: detf-dl
WPs: WP-SEC-DETF-DL-A0-001, WP-SEC-DETF-DL-DELTA-001, WP-SEC-DETF-DL-I-HONESTY-001 + DualLiq CROPS
Production: contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**
Tests: test/foundry/fork/**/crossVersion/v2/**
Out of scope: restoring no-op _receive / held−amountIn; Single SE matrix consumers
Proof-first: yes
Acceptance:
  FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' \
    --match-test 'test_I|test_A0_|test_K1_|test_CROPS_' --fork-url base_mainnet_alchemy -vv
Notes: owner-silent default B (keep same-tx, invert theater). ShareInflation is not I.
  Missing ALCHEMY_KEY → BUILD_BLOCKED; do not close.
```

#### `detf-mv`

```text
SLICE: detf-mv
WPs: WP-SEC-PKG-MV-001, WP-SEC-DETF-MV-A0-001
Production: MultiVaultWeightedDetfDFPkg.sol processArgs only
Tests: test/**/multi-vault-weighted/**
Out of scope: MultiVault I/J/K Common/Targets
Proof-first: no
Acceptance:
  forge test --match-path 'test/**/multi-vault-weighted/**' --match-test 'test_PKG_|test_C1_|test_A0_' -vv
Notes: donate before first bond; J/I CODE stay OE.
```

#### `detf-sse`

```text
SLICE: detf-sse
WPs: WP-SEC-DETF-SSE-A0-001 + Single SE / Uni V4 CP CROPS
Production: SingleStandardExchangeDETF* and UniswapV4SingleStandardExchangeDETF* Common/Bonding/Out disable gates only
Tests: SSE + CP adversarial
Out of scope: _pullToken
Proof-first: no
Acceptance:
  forge test --match-path 'test/**/standardExchange/single/**' --match-test 'test_A0_|test_CROPS_' -vv
  forge test --match-path 'test/**/uniswap/v4/standardExchange/constantProduct/single/**' --match-test 'test_A0_|test_CROPS_' -vv
```

#### `lst-ij`

```text
SLICE: lst-ij
WPs: WP-SEC-I-LST-001, WP-SEC-J-LST-001
Production: none unless PAT-J-OMIT
Tests: test/foundry/spec/protocol/staking/{lido,etherfi,rocket-pool}/**
Out of scope: Aave Loop; Uni V3; commons
Proof-first: no
Acceptance:
  forge test --match-path 'test/foundry/spec/protocol/staking/**' --match-test 'test_I1_|test_I2_|test_I3_|test_J' -vv
```

#### `erc4626-ij`

```text
SLICE: erc4626-ij
WPs: WP-SEC-I-ERC4626-001
Production: none
Tests: test/foundry/spec/vaults/standard/erc4626/**
Out of scope: Aave Stata; Morpho Blue port
Proof-first: no
Acceptance:
  forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/**' --match-test 'test_I1_|test_I2_|test_I3_|test_J' -vv
Notes: rename theater preview-equality off the I1 name; add real I1 (no transfer).
```

#### `detf-com-j`

```text
SLICE: detf-com-j
WPs: WP-SEC-DETF-COM-J-001
Production: none unless PAT-J-OMIT
Tests: claim + NFT vault J after CREATE3/registry
Out of scope: WP-I-CLAIM-001 pull body
Proof-first: no
Acceptance:
  forge test --match-path 'test/**/claimToken/**' --match-test 'test_J' -vv
  forge test --match-path 'test/**/bondNft/**' --match-test 'test_J' -vv
Notes: J3 on proxy.
```

#### `token-policy`

```text
SLICE: token-policy
WPs: WP-SEC-TOKEN-001
Production: none (no processArgs allowlist)
Tests: test_L2_FoT_forbidden on IERC20-config surfaces (ERC4626 SE + Camelot V2 SE)
Out of scope: official LST/Stata faces; inventing economics; credits_actualIn
Proof-first: no
Acceptance: written policy (agent law § Token policy) + forge test --match-test 'test_L2_FoT_forbidden' -vv
Notes: real FoT as the configured token, not mock SUT. Owner policy LOCKED 2026-08-13.
```

---

## 9. BUILD_BLOCKED / red forge

| Symptom | Action |
|---------|--------|
| Compile error in this slice’s files | Fix in-slice. No `via_ir`. |
| Compile error outside touch-set | Stop. Report. Do not “fix the monorepo.” |
| DualLiq / Slipstream fork: no `ALCHEMY_KEY` | `BUILD_BLOCKED`. WP stays open. Hermetic helper-only is not DualLiq close. |
| Red test that still shows the exploit | CODE not closed. Do not invert the assert. |
| Red test pre-existing outside touch-set | Note; do not expand scope. |
| `gap_cover_*` suddenly live on the same file | Park this slice. Do not dual-edit. |
| Machine OOM with 3 live forges | Pause a slot; keep seeds; do not kill a compile that is still making progress. |

---

## 10. Program DoD (Stage 3)

- [x] All **36** High `WP-SEC-*` merged (token-policy recorded; no BUILD_BLOCKED)
- [ ] Split WPs (`E6-SE`, `R4-SE`, `A0-SE`, `I-SE-4626`, `CROPS`) closed on **every** listed slice
- [ ] Each slice’s §4 forge matcher green on `main` (worklog evidence)
- [ ] No unbounded extract greenwashed; I1 ≠ happy pretransfer+transfer; J calls proxy
- [ ] No `via_ir`; DETF role names; registry/CREATE3 deploy bar
- [ ] OWNED_ELSEWHERE primary files not “fixed again”
- [ ] Live concurrency never exceeded 3; branches used `sec_fix/` only
- [ ] Warm `cache_forge/` + `out/` harvested after each green slice

**Stop.** Do not start this queue until a dedicated Stage 3 goal is opened.
