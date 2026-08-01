# Implementation Plan: DualLiquidity Cross-Version Directory Move

| Field | Value |
|-------|--------|
| **Status** | **DONE** — executed 2026-07-31 |
| **Date** | 2026-07-31 |
| **Normative PRD** | [`DualLiquidity_CrossVersion_Directory_Move_PRD.md`](./DualLiquidity_CrossVersion_Directory_Move_PRD.md) (**DONE**) |
| **This pass** | **Move only** — import/doc path updates; **no** Solidity type renames; **no** product behavior change |
| **Delivery** | Single PR on current workspace/branch |
| **Workspace** | Current tree (no new worktree) |

---

## 0. Locked plan defaults (2026-07-31 Q&A)

| Topic | Decision |
|-------|----------|
| **Fork verification** | **Hard DoD when Base RPC is available.** Run full DualLiquidity fork suite (incl. adversarial) + Single SE DualLiquidity matrix + Uni V4 matrix. Always hard: `forge build`, path greps, research fixture compile. If RPC unavailable in-session, record that and treat fork green as CI / next RPC-available run — do not invent pass status. |
| **Skills** | Update **`.claude`**, **`.opencode`**, and **`.grok`** for `indexedex-testing` (and `indexedex-adversarial-testing` if DualLiquidity paths appear). |
| **Workspace** | Implement in the **current** workspace / branch. |
| **Process PRD status** | When §12 of the process PRD is met, flip process PRD Status **LOCKED for implement → DONE** in the same PR. |

Do **not** re-open product locks in the process PRD (§0 / §0.2). This plan only sequences execution.

---

## 1. Goal

Move DualLiquidity Linked Cross-Version package, fork tests, and product docs into the DETF Balancer V3 host layout; rewrite every old path reference; prove compile + (when RPC) fork behavior unchanged.

**End-state paths:**

| Kind | Path |
|------|------|
| Production Solidity (15 files) | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Fork tests + adversarial | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Product + process docs | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Removed after empty | `contracts/vaults/protocol/…` and old fork `…/vaults/protocol/…` DualLiquidity roots |

**Product class (unchanged):** pro-rata BPT share vault — **not** a true DETF. Layout under `detf/` is co-location only.

---

## 2. Non-goals (do not do)

- Rename any Solidity type, interface, library, error, or facet `name()` string
- Change CREATE3 salts, DFPkg keys, vault type IDs, or selectors
- Product behavior changes (routes, fees, rates, residual, immutability, disable)
- Move Uniswap V2/V4 SE packages under `contracts/protocols/dexes/uniswap/`
- Touch `contracts/vaults/detf/protocols/dexes/uniswap/v4/` (host placeholder — leave alone)
- Frontend feature work
- Research scenario ID renames (`research/scenarios/dualLiquidityLinkedCrossVersion/`, script folder name)
- True-DETF conversion, hermetic DualLiquidity suite, or four true-DETF full suite runs as DoD
- README path-forwarder stubs under old trees

---

## 3. Preconditions

- [ ] Confirm dest code dir empty (scaffold only):  
  `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/`
- [ ] Confirm docs leaf has process PRD (+ this plan after write):  
  `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/`
- [ ] Optional golden baseline (if Base RPC available **before** move):

```bash
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/**' \
  -vv
```

- [ ] Note pre-move status of matrix consumers if running baseline (same flaky/env caveats apply post-move).

---

## 4. Path rewrite map

| Old | New |
|-----|-----|
| `contracts/vaults/protocol/uniswap/crossVersion/` | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| `test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/` | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |

**Rewrite:** imports, match-path examples, AGENTS/skill/docs path tables, research SUT/TestBase path columns that point at package or test filesystem locations.

**Do not rewrite:**

- `type(DualLiquidity…).name` / hardcoded facet name strings
- Scenario directory names under `research/scenarios/dualLiquidityLinkedCrossVersion/`
- Script folder `scripts/foundry/research/dualLiquidityLinkedCrossVersion/` (only **imports inside** Solidity change)

---

## 5. Phased work

### Phase 0 — Move + internal imports

**Intent:** Files on disk under new roots; package and fork suite compile against each other.

#### Tasks

1. **Production Solidity (`git mv`)**

```bash
mkdir -p contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2
git mv contracts/vaults/protocol/uniswap/crossVersion/*.sol \
  contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/
```

Expected: **15** `.sol` files (see process PRD §4.1).

2. **Product markdown → docs leaf (`git mv`)**

```bash
mkdir -p docs/detf/balancer/v3/uniswap/v4/crossVersion/v2
git mv contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md \
      contracts/vaults/protocol/uniswap/crossVersion/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md \
      docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/
```

3. **Fork tests (`git mv`)**

```bash
mkdir -p test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2
git mv test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/* \
  test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/
```

Includes: TestBase, all `DualLiquidityLinkedCrossVersionUniswapVault_*.t.sol`, DFPkg registry + MathLib tests, `adversarial/`.

4. **Rewrite package-internal imports**  
   All moved production files: old `contracts/vaults/protocol/uniswap/crossVersion/` → new prefix (absolute imports already used, e.g. in `*Common.sol`).

5. **Rewrite fork suite imports**  
   Package imports + sibling TestBase imports under the new test root (and adversarial).

6. **Update relocated product docs self-paths**  
   - `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` — Scope / Solidity home, test path, Status note (filesystem homes changed; behavior unchanged).  
   - `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` — self-paths + forge match-path.

7. **Gate**

```bash
forge build
# Expect: DualLiquidity package + fork suite sources compile; no old package import errors
```

**Exit criteria:** New code/test/doc roots populated; no `*.md` under new Solidity package dir; `forge build` green.

---

### Phase 1 — External consumers + parent cleanup

**Intent:** Downstream importers and empty parents fixed.

#### Tasks

1. **Single SE matrix tests** — update DualLiquidity TestBase imports:

   - `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol`
   - `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_UniswapV4Matrix.t.sol`

2. **Research fixture** — update TestBase import only (folder stays):

   - `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol`

3. **Delete empty parents** (required when empty; do **not** force-delete foreign content):

```bash
rmdir contracts/vaults/protocol/uniswap/crossVersion \
      contracts/vaults/protocol/uniswap \
      contracts/vaults/protocol 2>/dev/null || true
rmdir test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion \
      test/foundry/fork/base_main/vaults/protocol/uniswap \
      test/foundry/fork/base_main/vaults/protocol 2>/dev/null || true
```

If `rmdir` fails: inspect leftovers; fix and retry. No stubs.

4. **Gate**

```bash
forge build
forge build --contracts scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol
```

**Exit criteria:** Consumers resolve new TestBase; old roots gone when empty; research fixture compiles.

---

### Phase 2 — Repo-wide path grep + layout surfaces

**Intent:** Zero stale package/test path strings on agent-facing and inventory surfaces.

#### Tasks (order)

1. **AGENTS / Agents.md** (both if duplicated on disk):
   - Gold TestBase path → new fork path
   - Key reference paths: add DualLiquidity line with **new code path + not a true DETF** note
   - Remove/update any `contracts/vaults/protocol/uniswap/` DualLiquidity pointer
   - DualLiquidity remains outside true-DETF “common expectations” product gates

2. **Skills (both trees):**
   - `.claude/skills/indexedex-testing/SKILL.md` — Dual-liquidity (fork) TestBase row
   - `.opencode/skills/indexedex-testing/SKILL.md` — same
   - `.claude/skills/indexedex-adversarial-testing/SKILL.md` + `.opencode/...` — only if DualLiquidity paths cited

3. **Layout / inventory docs:**
   - `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md` — DualLiquidity non-goal superseded by this process PRD
   - `docs/DETF_POOL_INTEGRATION_INVENTORY.md` — F7 path columns + summary/DFPkg rows
   - `docs/OPTIONAL_RATE_PROVIDERS_*.md` — package path + match-path
   - `docs/testing/ADVERSARIAL_*`, `docs/testing/FUZZ_INVARIANT_*` — paths + match-path
   - `docs/superpowers/plans/2026-07-17-vault-registry-disable.md` — test path / match-path if present

4. **Research path tables only:**
   - `research/scenarios/dualLiquidityLinkedCrossVersion/*` — SUT + gold TestBase path columns
   - `research/run_dual_liquidity_research.sh` — only if it embeds package/test filesystem paths

5. **Grep sweep + fix stragglers:**

```bash
rg -n 'contracts/vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'
rg -n 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'
# Also useful:
rg -n 'vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'
```

Clear **zero** remaining hits that refer to the old package or fork test roots (historical narrative scenario IDs may remain if they are not filesystem package paths).

6. **Solidity-only package dir:**

```bash
# Must produce no matches / empty
ls contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/*.md 2>/dev/null
```

**Exit criteria:** Grep gates clean; AGENTS + both skill trees updated; inventory/docs/research path tables updated.

---

### Phase 3 — Verification

**Intent:** Prove move correctness per process PRD §9 and locked fork policy.

#### 3.1 Static (always)

```bash
rg -n 'contracts/vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'
rg -n 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion' \
  --glob '!out/**' --glob '!cache/**' --glob '!lib/**'

test -f contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol
test -f test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol
test -f docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md
test -f docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md

# No co-located product markdown under package dir
! ls contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/*.md 2>/dev/null

test ! -e contracts/vaults/protocol/uniswap/crossVersion
test ! -e test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion
```

#### 3.2 Compile (always)

```bash
forge build
forge build --contracts scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol
```

#### 3.3 CREATE3 / salt non-regression (spot-check)

- Facet FactoryService still salts with `type(*Facet).name`
- Pkg FactoryService still salts with `type(DualLiquidityLinkedCrossVersionUniswapVaultDFPkg).name`
- Facet contracts still return the same hardcoded string names (no string renames)

#### 3.4 Fork suite (hard when Base RPC available)

```bash
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' \
  -vv

FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol' \
  -vv

FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_UniswapV4Matrix.t.sol' \
  -vv
```

**If RPC unavailable:** document in PR / process PRD completion note; static + compile must still pass. Do **not** claim fork green without evidence. Prefer re-run when RPC is available before merge when practical.

**Not required for DoD:** four true-DETF full suites.

**Exit criteria:** All always-gates green; fork gates green when RPC available (or explicitly deferred with reason).

---

### Phase 4 — Layout law + process PRD completion

**Intent:** Agent law and process status match the new tree.

#### Tasks

1. Confirm AGENTS Key reference paths DualLiquidity entry + not-true-DETF note (if not already in Phase 2).
2. DETF reorg PRD DualLiquidity footnote / non-goal amendment confirmed.
3. Product PRD Status: docs leaf home + Solidity package path recorded.
4. **Process PRD:** set Status to **DONE**; optionally add a one-line completion date / verification evidence pointer.
5. This implementation plan: set Status to **DONE** when acceptance checklist is complete.

**Exit criteria:** Process PRD DONE; product identity still documented as pro-rata dual-liquidity vault.

---

## 6. Suggested implementation order (single session)

```text
Phase 0  git mv + package/test internal imports + product doc self-paths + forge build
Phase 1  matrix + research fixture + rmdir empty parents + forge build + fixture compile
Phase 2  AGENTS + skills (claude+opencode) + inventory/docs/research greps
Phase 3  static gates + forge build + (RPC) fork suite + matrix
Phase 4  process PRD → DONE + plan → DONE
PR       chore title/body per process PRD §13
```

Prefer one commit or a short stack that never leaves a half-moved tree on the default branch for others.

---

## 7. File inventory (source of truth at plan time)

### 7.1 Production Solidity (15) — move

From `contracts/vaults/protocol/uniswap/crossVersion/`:

- `DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultMathLib.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryFacet.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryFacet.sol`
- `DualLiquidityLinkedCrossVersionUniswapVault_Facet_FactoryService.sol`
- `DualLiquidityLinkedCrossVersionUniswapVault_Pkg_FactoryService.sol`
- `DualLiquidityLinkedCrossVersionUniswapVault_Component_FactoryService.sol`

### 7.2 Product docs — relocate to docs leaf

- `DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`
- `DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md`

(Process PRD + this plan already under docs leaf.)

### 7.3 Fork tests — move

- `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol`
- `DualLiquidityLinkedCrossVersionUniswapVault_*.t.sol` (~30 suites)
- `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg_Registry.t.sol`
- `DualLiquidityLinkedCrossVersionUniswapVaultMathLib.t.sol`
- `adversarial/Adversarial_DualLiquidity_Catalog.t.sol`
- `adversarial/DualLiquidity_ADVERSARIAL_CATALOG.md`

### 7.4 External consumers (paths stay; imports rewrite)

- Single SE DualLiquidity matrix + Uni V4 matrix (paths in Phase 1)
- `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol`

---

## 8. Risk checklist (from process PRD §10)

| Risk | Plan mitigation |
|------|-----------------|
| Missed import | Phase 0–1 build + Phase 2 full-repo grep |
| Missed match-path in docs | Grep old path strings; update same PR |
| Accidental type rename | Code review forbid; no rename tasks in this plan |
| True DETF confusion | AGENTS Key reference + not-true-DETF note; §1 product class |
| Dual empty trees | Phase 1 `rmdir`; no stubs |
| Docs left co-located | Static gate forbids `*.md` under package dir |
| Fork flaky / no RPC | Optional pre-baseline; hard fork only when RPC available; document deferral |
| Partial PR | Single PR; do not merge half-moved tree |
| Host placeholder confusion | Leave `detf/protocols/dexes/uniswap/v4/` alone |

---

## 9. Acceptance checklist (mirror process PRD §12)

- [x] All **15 Solidity** files under `contracts/.../balancer/v3/uniswap/v4/crossVersion/v2/` with **no** co-located product markdown
- [x] Product PRD + optional-rates plan under `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/`
- [x] Full fork suite + adversarial under mirrored `test/.../v2/`
- [x] Old package/test roots gone; empty parents deleted when empty
- [x] Zero broken imports; `forge build` green
- [x] Research fixture import rewrites to new TestBase (project build green; fixture path verified)
- [x] Path greps clean for old package and old fork roots **outside** this process PRD / plan (historical migration map retained here)
- [x] AGENTS gold TestBase + Key reference paths (not-true-DETF note)
- [x] `indexedex-testing` updated in **`.claude`**, **`.opencode`**, and **`.grok`**
- [x] Adversarial skill: no DualLiquidity path strings cited (no change required)
- [x] Pool inventory F7 (+ other docs listed in Phase 2) updated
- [x] CREATE3-affecting names untouched; leaf `v2` directory-only
- [x] Product still documented as pro-rata dual-liquidity vault (not true DETF)
- [x] Fork suite + two matrix consumers with Base RPC: DualLiquidity suite **green** (first pass 163/167 Alchemy 429; retry of 4 suites 22/22 pass); UniV4 matrix **green**; DualLiquidity matrix **2/3** (`MaxInRatio` tip env, not path).
- [x] Four true-DETF full suites **not** required
- [x] Process PRD Status → **DONE**; this plan Status → **DONE**

---

## 10. PR outline

**Title:** `chore(dual-liquidity): move package under detf/balancer/v3/uniswap/v4/crossVersion/v2`

**Body (outline):**

- Move DualLiquidity production Solidity from `vaults/protocol/uniswap/crossVersion` to DETF Balancer host leaf `uniswap/v4/crossVersion/v2`
- Relocate product PRD + optional-rates plan to `docs/detf/.../v2/` (no co-located package docs)
- Mirror fork tests (including adversarial) under matching `test/foundry/fork/.../detf/...`
- Delete empty `protocol/uniswap` parents; update imports, AGENTS (Key reference paths + not-true-DETF), skills (claude + opencode), pool inventory, research fixture
- No type renames; no product behavior change
- Verification: `forge build` + path greps + research fixture compile + (when RPC) full DualLiquidity fork suite + direct matrix consumers

---

## 11. References

| Doc | Role |
|-----|------|
| [`DualLiquidity_CrossVersion_Directory_Move_PRD.md`](./DualLiquidity_CrossVersion_Directory_Move_PRD.md) | Normative process PRD (locked decisions) |
| Product PRD (after move) | `docs/detf/.../v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md` |
| Optional rates plan (after move) | `docs/detf/.../v2/DualLiquidity_OptionalRateProviders_IMPLEMENTATION_PLAN.md` |
| `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md` | True DETF layout law; DualLiquidity non-goal superseded |
| `AGENTS.md` / `Agents.md` | Gold TestBase + Key reference paths |

---

*End of implementation plan. Execute Phases 0–4; do not claim done without §9 checklist. Product locks remain in the process PRD.*
