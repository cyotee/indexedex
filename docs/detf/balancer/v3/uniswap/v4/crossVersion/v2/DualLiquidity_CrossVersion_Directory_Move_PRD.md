# PRD: DualLiquidity Linked Cross-Version — directory move into DETF Balancer V3 tree

| Field | Value |
|-------|--------|
| **Status** | **LOCKED for implement** — open items resolved 2026-07-31 (see §0 / §0.2) |
| **Date** | 2026-07-31 |
| **Product** | `DualLiquidityLinkedCrossVersionUniswapVault` (as-built package under `contracts/vaults/protocol/uniswap/crossVersion/`) |
| **Target code path** | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| **Target test path** | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| **Target product docs** | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` (product PRD + optional-rates plan; **not** co-located with Solidity) |
| **This pass** | **Move only** — import path / doc path updates; **no** Solidity type renames; **no** product behavior change |
| **Risk posture** | Medium path churn (fork suite + matrix consumers + research fixture); **CREATE3 salts unchanged** (type names stay); no intentional on-chain behavior change |

---

## 0. Locked decisions (2026-07-31)

| Topic | Decision |
|-------|----------|
| **Source** | Everything under `contracts/vaults/protocol/uniswap/crossVersion/` (Solidity + currently co-located markdown) |
| **Destination (code)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` — **Solidity only** (empty scaffold already present) |
| **Destination (fork tests)** | Mirror under `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` (including `adversarial/`) |
| **Product reclassification** | **Layout only.** DualLiquidity remains a **pro-rata BPT share vault** (not a true seigniorage DETF). Moving under `detf/…` does **not** apply true-DETF product law (thresholds, bond NFT, claim, natural expansion). See §2. |
| **Type / CREATE3 names** | **No renames.** Keep `DualLiquidityLinkedCrossVersionUniswapVault*`, `IDualLiquidityLinkedCrossVersionUniswapVaultDFPkg`, facet `name()` string returns, and `type(X).name` salts exactly as today. Leaf `v2` is **directory only**. |
| **Product docs** | **Docs only — no co-located package markdown.** Relocate product PRD + optional-rates plan under `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/`. Package directory holds Solidity only (aligned with true-DETF reorg doc policy). |
| **Process PRD home** | This file under the same `docs/detf/.../v2/` leaf as product docs. |
| **AGENTS Key reference paths** | **Yes** — add DualLiquidity new path with explicit **not a true DETF** note; also update gold TestBase path. |
| **Placeholder conflict** | Keep empty `contracts/vaults/detf/protocols/dexes/uniswap/v4/` for a **future Uniswap-reserve host family**. DualLiquidity is **Balancer-reserve + Uni legs** → lives under `balancer/v3/uniswap/…`, not under the Uni host placeholder. |
| **Parent cleanup** | **Yes — delete empty parents.** After move, remove empty `crossVersion/`, then empty `uniswap/` and empty `protocol/` under both `contracts/vaults/` and the old fork test parents if nothing else remains. |
| **Delivery shape** | **Single PR** covering code move + test move + doc relocate + import rewrites + repo-wide path grep + verification. |
| **Verification bar** | DualLiquidity full fork suite (incl. adversarial) + **direct consumers** (Single SE DualLiquidity/UniV4 matrix) + research fixture compile. **Not** the four true-DETF full suites. See §9. |
| **Relation to DETF reorg PRD** | Supersedes the **non-goal** “do not move DualLiquidity” in [`DETF_DIRECTORY_REORGANIZATION_PRD.md`](../../../../../../contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md) §2 for this product only. Does not re-open true-DETF layout law. |

### 0.2 Open items resolved (Q&A 2026-07-31)

| # | Question | Lock |
|---|----------|------|
| 1 | Product PRD + optional-rates plan location | **Docs only** under `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` — **do not** co-locate next to Solidity |
| 2 | AGENTS Key reference paths entry | **Yes** — path + not-true-DETF note |
| 3 | Empty `contracts/vaults/protocol/` parents | **Yes — delete** empty parent tree after move |
| 4 | Forge verification width | **DualLiquidity + direct consumers** only (not full four true-DETF suites) |
| 5 | Meaning of leaf `v2` | **Directory leaf only** — no Solidity type rename; no follow-on rename planned in this PRD |

### 0.1 Path axis (why this tree)

```text
contracts/vaults/detf/protocols/dexes/
  balancer/v3/          ← reserve host (Balancer V3 Weighted Pool is pricing engine)
    uniswap/v4/         ← primary SE leg family (commonToken/tokenA|B Uniswap V4 SE vaults)
      crossVersion/     ← topology: V4 legs + Uniswap V2 pair leg
        v2/             ← package tree leaf version (directory only; not a Solidity rename)
```

**Contrast (do not merge):**

| Tree | Role |
|------|------|
| `contracts/protocols/dexes/uniswap/v2\|v4/` | SE vault packages (legs DualLiquidity composes) |
| `contracts/protocols/dexes/balancer/v3/` | Pools, routers, rate providers |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/<true-DETF families>/` | True DETF families (seigniorage, bond, thresholds) |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` | **This product** — DualLiquidity linked cross-version vault |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/` | Placeholder for a **future** Uni-reserve DETF host — **empty; leave alone** |

---

## 1. Problem statement

1. DualLiquidity production code still lives under the historical **`contracts/vaults/protocol/uniswap/crossVersion/`** tree, outside the post-reorg DETF host layout.
2. Agents and docs already treat DualLiquidity as a **Balancer-reserve vault product** that composes Uniswap SE legs (pool inventory F7, AGENTS gold TestBase, Single SE matrix rows). The path no longer matches that mental model.
3. An empty destination scaffold already exists at the target path; leaving production code on the old path invites dual trees and stale imports.
4. Fork tests, research fixtures, DETF matrix tests, skills, and many docs hardcode the old path. A partial move will break compile / CI.

Without a single coordinated move, import rewrites, and a full fork verification bar, the package will bit-rot across tests and research.

---

## 2. Product identity (must not be confused)

| Attribute | DualLiquidity (this package) | True DETF families (Single SE, MultiVault Weighted, MixedBuffer, Composed Stable) |
|-----------|------------------------------|-----------------------------------------------------------------------------------|
| Share model | Pro-rata claim on reserve **BPT** | Diamond is DETF ERC-20; seigniorage mint/burn vs reserve |
| Bond NFT / claim | **No** | Yes (family-default) |
| Mint/burn thresholds / Policy|Open | **No** | Yes (`DETFThresholdPolicy`) |
| Protocol compound / natural expansion | **No** | Yes (shared libs + family stages) |
| Reserve | Balancer V3 **Weighted** 3-leg (vaultA, vaultB, pair) | Family-specific Balancer reserve |
| Legs | Uni V4 SE ×2 + Uni V2 SE pair | `IStandardExchange` opacity |
| Deploy | DFPkg + vault registry + CREATE3 facets | Same registry pattern |
| Immutability | Immutable unowned instance | Same |

**Layout under `detf/`** means: co-locate Balancer-reserve vault **packages** that participate in the DETF / SE composition story.

**Does not mean:** reclassify DualLiquidity as a true DETF or apply AGENTS “DETF families — common expectations” product gates.

Product as-built law remains:

- Co-located after move: `…/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`
- Optional rates: `…/v2/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md`

---

## 3. Goals / non-goals

### Goals

1. Move **all** files from `contracts/vaults/protocol/uniswap/crossVersion/` → `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`.
2. Mirror the **full** fork test tree (including `adversarial/`) to the DETF-aligned path under `test/foundry/fork/base_main/vaults/detf/...`.
3. Rewrite **every** import / path string that pointed at the old locations (production, tests, scripts, skills, AGENTS, docs, research).
4. Update consumers that only import the TestBase or package paths (Single SE DualLiquidity / Uni V4 matrix tests; research fixture).
5. Clean empty parent directories left by the move.
6. Prove **behavior unchanged**: full DualLiquidity fork suite green; matrix consumers that inherit DualLiquidity TestBase green; research fixture still compiles against the moved TestBase.
7. Update layout law docs (AGENTS, pool inventory, DETF reorg non-goal footnote, indexedex-testing skill).

### Non-goals

- Renaming any Solidity **type**, **interface**, **library**, **error**, or facet `name()` string.
- Changing CREATE3 salts, DFPkg registration keys, vault type IDs, or facet selectors.
- Product behavior changes (routes, fees, optional rates, residual, immutability, disable hook).
- Moving Uniswap V2/V4 **SE** packages under `contracts/protocols/dexes/uniswap/`.
- Filling `contracts/vaults/detf/protocols/dexes/uniswap/v4/` (host placeholder stays empty).
- Frontend feature work (no DualLiquidity address wiring required for this pass beyond accidental path strings — none found in app code).
- Research **scenario** rewrites (plots, findings narratives) beyond path fixes for SUT / TestBase.
- Converting DualLiquidity into a true DETF (bond NFT, thresholds, expansion).
- Hermetic (non-fork) DualLiquidity suite (does not exist today; do not invent).

---

## 4. Source inventory (complete)

### 4.1 Production + co-located docs

**From:** `contracts/vaults/protocol/uniswap/crossVersion/`

| File | Role |
|------|------|
| `DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol` | Shared target base |
| `DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol` | Storage + errors |
| `DualLiquidityLinkedCrossVersionUniswapVaultMathLib.sol` | Pure math helpers |
| `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` | DFPkg + `I*DFPkg` interface |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` | Exchange-in logic |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet.sol` | In facet |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget.sol` | In preview/query |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet.sol` | In query facet |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol` | Exchange-out logic |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet.sol` | Out facet |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget.sol` | Out preview/query |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet.sol` | Out query facet |
| `DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService.sol` | CREATE3 facet deploy |
| `DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService.sol` | Registry DFPkg deploy |
| `DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.sol` | Facet+pkg composition |
| `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` | Product as-built PRD |
| `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` | Optional rates plan (done) |

**Count:** 15 Solidity + 2 markdown = **17 files**.

### 4.2 Fork tests

**From:** `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/`

| File | Role |
|------|------|
| `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Gold fork TestBase |
| `DualLiquidityLinkedCrossVersionUniswapVault_*.t.sol` | ~30 suite files (deposits, swaps, fees, rates, reentrancy, invariants, permit2, disable, …) |
| `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg_Registry.t.sol` | Registry path |
| `DualLiquidityLinkedCrossVersionUniswapVaultMathLib.t.sol` | Math unit-on-fork |
| `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` | Adversarial catalog suite |
| `adversarial/DualLiquidity_ADVERSARIAL_CATALOG.md` | Catalog markdown |

### 4.3 External consumers (must rewrite; files stay)

| Consumer | Current dependency |
|----------|-------------------|
| `test/.../standardExchange/single/SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol` | Imports DualLiquidity TestBase |
| `test/.../standardExchange/single/SingleStandardExchangeDETF_UniswapV4Matrix.t.sol` | Imports DualLiquidity TestBase |
| `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol` | Imports DualLiquidity TestBase |
| Research scripts under same folder | Inherit fixture (path indirect) |

### 4.4 Path string references (repo-wide grep list)

At least **~68 files** mention `DualLiquidityLinkedCrossVersion` and/or `vaults/protocol/uniswap/crossVersion` (as of 2026-07-31), including:

- `AGENTS.md` (gold TestBase path)
- `.claude/skills/indexedex-testing/SKILL.md` (and synced skill copies if present)
- `docs/DETF_POOL_INTEGRATION_INVENTORY.md` (F7 path columns)
- `docs/OPTIONAL_RATE_PROVIDERS_*.md`
- `docs/testing/ADVERSARIAL_*`, `docs/testing/FUZZ_INVARIANT_*`
- `docs/superpowers/plans/2026-07-17-vault-registry-disable.md`
- `research/scenarios/dualLiquidityLinkedCrossVersion/*` path tables
- Production + test Solidity imports

**Implementer obligation:** re-run a full-repo grep after the move (§9) and clear **zero** remaining old-path hits for production/test/script/skill/AGENTS/inventory surfaces. Historical research *findings* may keep narrative file names (`dualLiquidityLinkedCrossVersion`) that are **scenario IDs**, not filesystem package paths — only update strings that point at `contracts/…` or `test/…` package locations.

---

## 5. Target tree (end state)

```text
contracts/vaults/detf/protocols/dexes/balancer/v3/
  uniswap/
    v4/
      crossVersion/
        v2/
          DualLiquidityLinkedCrossVersionUniswapVault*.sol   # all 15
          DualLiquidityLinkedCrossVersionUniswapVault_PRD.md
          DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md
          # process PRD lives under docs/ (this file), not required co-located

test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/
  uniswap/
    v4/
      crossVersion/
        v2/
          TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol
          DualLiquidityLinkedCrossVersionUniswapVault_*.t.sol
          DualLiquidityLinkedCrossVersionUniswapVaultDFPkg_Registry.t.sol
          DualLiquidityLinkedCrossVersionUniswapVaultMathLib.t.sol
          adversarial/
            Adversarial_DualLiquidity_Catalog.t.sol
            DualLiquidity_ADVERSARIAL_CATALOG.md

docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/
  DualLiquidity_CrossVersion_Directory_Move_PRD.md   # this PRD

# REMOVED after empty:
contracts/vaults/protocol/uniswap/crossVersion/   (and empty parents)
test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/  (and empty parents)
```

**Note:** `TestBase` stays **next to** the DualLiquidity fork suite (current pattern), not under `contracts/…`. True DETF families sometimes co-locate TestBases under contracts; DualLiquidity’s gold path is fork-only and remains under `test/foundry/fork/…` after the mirror.

---

## 6. Mechanical move procedure

### 6.1 Preconditions

- [ ] Working tree clean enough to isolate this PR (or a dedicated branch / worktree).
- [ ] Confirm destination dirs empty (no accidental partial copy).
- [ ] Note baseline: run DualLiquidity suite once **before** move if RPC available (optional golden baseline).

### 6.2 File move (git-preserving)

Prefer `git mv` so history follows:

```bash
# Production
mkdir -p contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2
git mv contracts/vaults/protocol/uniswap/crossVersion/* \
  contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/

# Fork tests
mkdir -p test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2
git mv test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/* \
  test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/

# Remove empty parents if empty
rmdir contracts/vaults/protocol/uniswap/crossVersion \
      contracts/vaults/protocol/uniswap \
      contracts/vaults/protocol 2>/dev/null || true
rmdir test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion \
      test/foundry/fork/base_main/vaults/protocol/uniswap \
      test/foundry/fork/base_main/vaults/protocol 2>/dev/null || true
```

If `rmdir` fails, inspect for leftover files (do **not** force-delete foreign content).

### 6.3 Import rewrite rules

**Old prefix → new prefix:**

| Old | New |
|-----|-----|
| `contracts/vaults/protocol/uniswap/crossVersion/` | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/` | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |

Apply to:

1. All moved Solidity files (internal package imports).
2. All moved test files (imports of package + sibling TestBase).
3. External consumers (§4.3).
4. Markdown path columns and forge `--match-path` examples in docs/skills/AGENTS.

**Do not rewrite:**

- `type(DualLiquidity…).name` / string facet names.
- Scenario directory names under `research/scenarios/dualLiquidityLinkedCrossVersion/`.
- Script folder `scripts/foundry/research/dualLiquidityLinkedCrossVersion/` (research harness root stays; only **import paths inside** Solidity change).

### 6.4 Suggested bulk rewrite

After `git mv`:

```bash
# Example — dry-run with ripgrep first
rg -n 'contracts/vaults/protocol/uniswap/crossVersion|vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'

# Then apply controlled replacements (agent/editor or a one-shot script).
# Prefer path-scoped edits over blind sed on the whole monorepo if unsure.
```

Order of rewrite:

1. Production package internals.
2. Fork suite + adversarial.
3. Single SE matrix tests.
4. Research fixture.
5. AGENTS + skills.
6. Docs / research path tables / match-path examples.

### 6.5 Co-located markdown path updates

Inside moved:

- `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` — Scope path, test path, status line.
- `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` — any self-paths / forge match-path.

Also update external links that pointed at the co-located files (e.g. `docs/OPTIONAL_RATE_PROVIDERS_IMPLEMENTATION_PLAN.md` gold-path table).

---

## 7. Docs, skills, AGENTS checklist

| Surface | Action |
|---------|--------|
| **AGENTS.md** | Gold TestBase path → new fork path; key reference table if DualLiquidity listed under `contracts/vaults/protocol/uniswap/` |
| **Claude.md** | Only if it duplicates DualLiquidity paths (usually points at AGENTS) |
| **indexedex-testing skill** | Dual-liquidity (fork) TestBase path row |
| **indexedex-adversarial-testing skill** | If DualLiquidity adversarial path is cited |
| **DETF_DIRECTORY_REORGANIZATION_PRD.md** | Footnote / amend non-goal: DualLiquidity **was** excluded; now moved by **this** PRD |
| **docs/DETF_POOL_INTEGRATION_INVENTORY.md** | F7 Path column + summary table + DFPkg path row |
| **docs/OPTIONAL_RATE_PROVIDERS_*.md** | Package path + forge match-path |
| **docs/testing/ADVERSARIAL_*** / **FUZZ_INVARIANT_*** | Production + test paths + match-path |
| **docs/superpowers/plans/2026-07-17-vault-registry-disable.md** | Test path / match-path examples |
| **research/scenarios/dualLiquidityLinkedCrossVersion/** | SUT path + gold TestBase path tables only |
| **research/run_dual_liquidity_research.sh** | Only if it embeds package/test paths (scenario out paths may stay) |

**No stubs:** do not leave README path-forwarders under the old `protocol/uniswap/crossVersion` tree. Update links; delete empty dirs.

---

## 8. Implementation phases

### P0 — Move + internal imports

1. `git mv` production + tests.
2. Rewrite package-internal imports.
3. Rewrite fork suite imports (package + TestBase relative paths).
4. `forge build` (or compile path that includes DualLiquidity) succeeds.

### P1 — External consumers

1. Single SE DualLiquidity matrix + Uni V4 matrix TestBase imports.
2. Research fixture TestBase import.
3. Parent directory cleanup.

### P2 — Repo-wide path grep

1. AGENTS, skills, pool inventory, optional rates docs, testing plans, research path tables.
2. Zero remaining hits for `contracts/vaults/protocol/uniswap/crossVersion` and `test/.../vaults/protocol/uniswap/crossVersion` outside intentional historical quotes (prefer zero everywhere).

### P3 — Verification (§10)

1. Full DualLiquidity fork suite.
2. Matrix consumers.
3. Optional research fixture compile / smoke script if RPC allows.
4. Grep gate clean.

### P4 — Layout law touch-ups

1. AGENTS product map: DualLiquidity path under detf tree; still **not** a true DETF family row.
2. DETF reorg PRD non-goal amendment or “superseded for DualLiquidity” note.
3. Optional: one-line note in product PRD Status that filesystem home changed.

---

## 9. Verification gates (definition of done)

### 9.1 Static gates

```bash
# Must return no matches for old package / test roots
rg -n 'contracts/vaults/protocol/uniswap/crossVersion' --glob '!out/**' --glob '!cache/**' --glob '!lib/**'
rg -n 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'

# New roots exist and are non-empty
test -f contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol
test -f test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol

# Old roots gone
test ! -e contracts/vaults/protocol/uniswap/crossVersion
test ! -e test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion
```

### 9.2 Compile / test gates

```bash
# Compile (project default)
forge build

# Full DualLiquidity fork suite (requires fork profile + RPC per foundry.toml)
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' \
  -vv

# Adversarial subfolder (included above; can run alone)
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/adversarial/**' \
  -vv

# DETF matrix consumers that inherit DualLiquidity TestBase
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol' \
  -vv
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_UniswapV4Matrix.t.sol' \
  -vv
```

### 9.3 CREATE3 / salt non-regression

Spot-check (no automated salt dump required if types unchanged):

- Facet FactoryService still salts with `type(*Facet).name`.
- Pkg FactoryService still salts with `type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).name`.
- Facet contracts that return hardcoded string names (e.g. `"DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet"`) unchanged.

### 9.4 Research harness

```bash
# Fixture must compile against moved TestBase (script path unchanged)
forge build --contracts scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol
# Optional: existing research smoke scripts if Base RPC available
```

---

## 10. Risk register

| Risk | Mitigation |
|------|------------|
| Missed import → compile fail | Full-repo path grep; `forge build` before claiming done |
| Missed match-path in docs → agent runs wrong suite | Grep old match-path strings; update in same PR |
| Accidental type rename → CREATE3 address drift | Explicit non-goal; code review forbid rename |
| Product law confusion (true DETF vs DualLiquidity) | §2 table; AGENTS wording: path under detf, product class unchanged |
| Dual empty trees | Delete old parents; no stubs |
| Fork suite flaky / RPC | Pre-move baseline optional; same profile as today |
| Confusing `detf/…/uniswap/v4` host placeholder | Leave placeholder empty; document contrast in §0.1 |
| Partial PR lands | Single PR delivery; do not merge half-moved tree |

---

## 11. Out-of-scope follow-ons (explicit)

| Follow-on | Notes |
|-----------|--------|
| Shorten type names (`DualLiquidity…` → shorter) | Separate rename PRD; CREATE3 impact |
| Move TestBase into `contracts/…` next to package | Optional consistency with some DETF families; not required |
| Hermetic DualLiquidity TestBase | Large; not part of move |
| Product → true DETF conversion | Separate product PRD |
| Uni V4–reserve DETF under `detf/protocols/dexes/uniswap/v4/` | Unrelated placeholder work |
| Frontend DualLiquidity product surfaces | Unrelated |

---

## 12. Acceptance criteria (checklist)

- [ ] All 15 Solidity + 2 co-located markdown files live under `…/balancer/v3/uniswap/v4/crossVersion/v2/`.
- [ ] Full fork suite + adversarial live under mirrored `test/.../v2/`.
- [ ] No remaining filesystem use of `contracts/vaults/protocol/uniswap/crossVersion` or old fork test root.
- [ ] Zero broken imports; `forge build` green.
- [ ] `FOUNDRY_PROFILE=fork` DualLiquidity match-path suite green.
- [ ] Single SE DualLiquidity + Uni V4 matrix tests green (or same pre-move status if environmental).
- [ ] Research fixture import points at new TestBase; compiles.
- [ ] AGENTS gold TestBase path updated.
- [ ] indexedex-testing skill DualLiquidity path updated.
- [ ] Pool inventory F7 path updated.
- [ ] CREATE3-affecting names untouched.
- [ ] Product class still documented as pro-rata dual-liquidity vault (not true DETF).
- [ ] This process PRD remains the normative move record under `docs/detf/…/v2/`.

---

## 13. Suggested PR title / description

**Title:** `chore(dual-liquidity): move package under detf/balancer/v3/uniswap/v4/crossVersion/v2`

**Body (outline):**

- Move DualLiquidity production package + co-located docs from `vaults/protocol/uniswap/crossVersion` to DETF Balancer host tree leaf `uniswap/v4/crossVersion/v2`.
- Mirror fork tests (including adversarial) to matching path under `test/foundry/fork/.../detf/...`.
- Update imports, AGENTS, skills, pool inventory, research fixture; no type renames; no product behavior change.
- Verification: forge build + full DualLiquidity fork suite + matrix consumers.

---

## 14. References

| Doc / path | Role |
|------------|------|
| `contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` | Product as-built (moves with package) |
| `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md` | True DETF layout law; DualLiquidity previously out of scope |
| `AGENTS.md` | Gold TestBase; DETF product law (true DETFs only) |
| `docs/DETF_POOL_INTEGRATION_INVENTORY.md` | F7 DualLiquidity inventory |
| `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Current gold TestBase (moves) |
| `scripts/foundry/research/dualLiquidityLinkedCrossVersion/` | Research harness (stays; imports update) |

---

## 15. Open questions (resolve before or during implement)

| # | Question | Proposed default |
|---|----------|------------------|
| 1 | Keep product PRD co-located after move, or also copy under `docs/detf/.../v2/`? | **Co-located only** (move with package); process PRD stays under `docs/detf` |
| 2 | Should AGENTS “Key reference paths” add DualLiquidity under the detf tree explicitly? | **Yes** — one line, with “not a true DETF” note |
| 3 | Delete empty `contracts/vaults/protocol/` entirely if DualLiquidity was the only child? | **Yes** if empty after move |
| 4 | Run full four true-DETF suites as part of this PR? | **No** — only DualLiquidity + direct matrix consumers unless opportunistic |
| 5 | Leaf name `v2` vs package generation? | **Directory leaf only** — no Solidity rename; documents package generation / tree version |

---

*End of PRD. Implement per §6–§9; do not claim done without §12 checklist.*
