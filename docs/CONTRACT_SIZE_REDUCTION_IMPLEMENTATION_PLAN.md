# Implementation Plan — Contract Size Reduction (EIP-170 Deployability)

| Field | Value |
|-------|--------|
| **Status** | **EXECUTED — G1 CLEAR** (2026-08-12) |
| **Date** | 2026-08-11 (executed 2026-08-12) |
| **Kind** | Execute plan (orchestrator + worktree implementers) |
| **Normative law** | [`CONTRACT_SIZE_REDUCTION_PRD.md`](./CONTRACT_SIZE_REDUCTION_PRD.md) — **only** size/deploy law; this plan does **not** reopen §1.1 |
| **Baseline inventory** | `OVERSIZE_CONTRACTS.log` + `SIZES.log` (from `yarn sizes`) |
| **Hard limit** | Runtime ≤ **24,576** bytes (EIP-170) |
| **G1 ship set** | **18 product Facets** with negative runtime margin (Targets are diagnostic only) |
| **Worktree / branch prefix** | `fix_size_` / `fix_size/<wave-slice>` |
| **Merge model** | Rebase onto `main` → fast-forward `main` (linear history) |
| **Max concurrent implementers** | **3** after Wave 0 (non-overlapping package trees) |
| **Skills** | `crane-architecture`, `crane-deployment`, `crane-code-style`, `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |

---

## 0. Executive summary

**Problem:** 18 production **Facets** exceed EIP-170 runtime size and cannot deploy. Root causes are packaging (monotarget inheritance, combined lifecycle Facets, inheritance towers, fat Commons)—not missing IR.

**Fix strategy (locked):**

1. **Option 1 (preferred):** Split Facets/Targets so each deployable Facet only inherits the code for its selectors.
2. **Option 2 (if needed):** Move heavy pure/view or multi-step helpers to **`external`** libraries or CREATE3 delegates.
3. **Option 3:** **Forbidden** — escalate to owner if 1+2 still fail.

**Success:** `yarn sizes` shows every in-scope Facet with runtime margin ≥ 0; regenerate product Facet oversize list empty; package TestBases green; CREATE3/DFPkg wiring updated; selectors/semantics stable.

**Not in this program:** soft headroom targets, near-miss preemptive splits, gas reports, vendored/test oversize, Target-only size gates, logic rewrites for efficiency.

---

## 1. Locked law (copy into every subagent prompt)

Full text: PRD §1.1 / §4 / §6.

| ID | Implementer rule |
|----|------------------|
| **L-SIZE-HARD** | Facet runtime ≤ **24,576**. No soft headroom. |
| **L-SIZE-SCOPE** | Clear **all** product Facets from the oversize inventory (waves OK). |
| **L-SIZE-FACET-GATE** | G1 measures **Facets** (CREATE3-deployed package components). Target-only artifact size is **not** a blocker. Still thin/split Targets so Facets inherit less bytecode. |
| **L-SIZE-OPT1** | Prefer **more Facets** over external libs when both clear the limit. |
| **L-SIZE-NEAR** | Near-miss Facets (**out of scope**). Do not make them worse when editing shared Commons. |
| **L-SIZE-GAS** | **No** gas measurement / % caps. |
| **L-SIZE-VENDOR** | Vendored + test-only oversize **out of scope**. |
| **L-SIZE-SURFACE** | **Stable selectors + semantics**; additive new Facets OK. |
| **L-SIZE-OPT3** | **No** business-logic efficiency refactors. Escalate if 1+2 fail. |
| **L-SIZE-ENFORCE** | Gate = `yarn sizes` + empty product Facet oversize list. No CI size job required. |

### Global hard rules

```text
HARD RULES:
1. via_ir forbidden. Stack relief = structs / helpers / scoping only.
2. Never `new` facets or DFPkgs. CREATE3 + FactoryService; vault/DETF via indexedexManager.deploy*DFPkg / registry.
3. Production-first tests. No mocks of SUT (vaults, DETF, manager, registry, fee oracle, facets, DFPkgs).
4. DETF role names only: rateAsset, pairToken, underlyingVault, vaultShare, detfToken, reservePool/reserveBpt, rebasingClaimToken.
5. Do not change fee / threshold / bond maturity / claim / reserve accounting semantics while shrinking.
6. Uni V4 hook CREATE3 salts / flag bits / mining law unchanged unless a package PRD already allows it.
7. Libraries that must shrink Facet size MUST be `external` (or separate contracts). `internal` libs are inlined — they do NOT reduce Facet size.
8. Option 3 forbidden. If Options 1+2 cannot clear a Facet, STOP and escalate.
9. Forge patience: cold compiles can take 20–40+ minutes. Never kill forge for silence. Seed cache_forge/ + out/ in new worktrees.
10. Prefer Option 1 (Facet/Target split) before Option 2.
```

### Forbidden

- `via_ir` / IR-only “fixes”
- Option 3 algorithm rewrites or route-matrix “unifications” that change formula structure
- Soft-headroom campaigns or near-miss preemptive work
- Gas-report gates as ship criteria
- Mocking SUT diamonds/vaults/manager
- Deleting security checks / reentrancy locks to win size
- Changing diamond money-path selectors or product economics
- Spending effort on VaultMock / Balancer Vault / `*TestDeployLib` / NPM / Morpho factories

---

## 2. G1 ship set (18 Facets)

Baseline from `SIZES.log` / `OVERSIZE_CONTRACTS.log` (2026-08-11). **Ignore** Target-only rows for G1.

| # | Facet | RT (B) | Margin | Wave |
|--:|-------|-------:|-------:|------|
| 1 | `UniswapV4StandardExchangeOrbitalBufferHookHooksFacet` | 46,457 | −21,881 | W3 |
| 2 | `UniswapV4StandardExchangeOrbitalBufferHookDepositFacet` | 44,442 | −19,866 | W3 |
| 3 | `UniswapV4StandardExchangeOrbitalBufferHookSeFacet` | 44,331 | −19,755 | W3 |
| 4 | `UniswapV4StandardExchangeOrbitalBufferHookWithdrawFacet` | 44,278 | −19,702 | W3 |
| 5 | `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet` | 41,471 | −16,895 | W4 |
| 6 | `UniswapV4WeightedSwapHookHooksFacet` | 37,320 | −12,744 | W4 |
| 7 | `UniswapV4WeightedSwapHookLiquidityFacet` | 36,079 | −11,503 | W4 |
| 8 | `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet` | 35,907 | −11,331 | W4 |
| 9 | `UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet` | 32,905 | −8,329 | W2 |
| 10 | `UniswapV4StandardExchangeWeightedDETFFacet` | 31,831 | −7,255 | W5 |
| 11 | `UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet` | 31,437 | −6,861 | W2 |
| 12 | `UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet` | 31,145 | −6,569 | W2 |
| 13 | `UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet` | 31,054 | −6,478 | W2 |
| 14 | `MultiVaultWeightedDetfExchangeInFacet` | 29,513 | −4,937 | W1 |
| 15 | `AerodromeStandardExchangeOutFacet` | 29,386 | −4,810 | W6 |
| 16 | `UniswapV4StandardExchangeOutFacet` | 28,547 | −3,971 | W6 |
| 17 | `MixedBufferMultiVaultStableDetfExchangeInFacet` | 28,438 | −3,862 | W1 |
| 18 | `UniswapV4StandardExchangeOrbitalDETFFacet` | 26,773 | −2,197 | W5 |

**Diagnostic only (not G1):** `AerodromeStandardExchangeOutTarget`, `UniswapV4StandardExchangeOutTarget`.

---

## 3. Measurement & inventory tooling

### 3.1 Canonical commands

```bash
# Repo root
yarn sizes
# = forge compile --sizes | tee SIZES.log
# Patience: first compile may take hours; do not kill.

# After a wave, extract Facet margins for the G1 name list (example):
python3 - <<'PY'
import re
from pathlib import Path
# G1 names = §2 Facets only
g1 = Path("docs/CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md")  # or maintain scripts/list_g1_facets.txt
# Prefer a small script: scripts/size_oversize_facets.py
text = Path("SIZES.log").read_text()
# parse table; print name, RT, margin for names ending in Facet with margin < 0 under contracts/**
print("see Wave 0 script")
PY
```

### 3.2 Wave 0 deliverables (required before CODE waves)

| Deliverable | Path / action |
|-------------|----------------|
| Baseline freeze | Copy current `SIZES.log` snapshot note + table §2 into wave notes if sizes drift |
| Parser script (recommended) | `scripts/size_oversize_facets.py` — read `SIZES.log`, emit product Facets with RT margin &lt; 0 (exclude `lib/**` vendored names and `*Mock*` / `*TestDeployLib*` unless CREATE3 product) |
| Regenerated inventory | `OVERSIZE_CONTRACTS.log` = product Facets with negative margin only (or keep full list but mark Facet vs Target) |
| Wave results log | `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md` (create empty template with columns: wave, facet, before RT, after RT, margin, option used) |

### 3.3 Per-wave size gate

```text
PASS when: every Facet owned by this wave has Runtime Margin ≥ 0
FAIL when: any wave Facet still negative → continue Option 1 splits or Option 2; never Option 3
REGRESSION: any previously green product Facet elsewhere that newly goes negative when shared Common touched → fix before merge
```

---

## 4. Cross-cutting wiring checklist (every new Facet)

Apply on **every** wave that adds Facets:

1. **Target(s)** — role/query body only; no unrelated role code on inherited base.
2. **Facet** — `IFacet` + `facetName` / `facetInterfaces` / `facetFuncs` / `facetMetadata` match selectors.
3. **FactoryService** — CREATE3 `deploy*Facet(ICreate3FactoryProxy)` (or package facet factory).
4. **DFPkg** — `PkgInit` / constructor immutables / `facetAddresses` / `facetCuts` / interfaces.
5. **Component / Pkg FactoryService** — build helpers pass new facet addresses.
6. **TestBase** — deploy path includes new facets; diamond still resolves all money selectors.
7. **Deploy scripts** — any stage that constructs PkgInit.
8. **Optional docs** — `docs/components/*` only if they list facet inventories.
9. **Verify** — package tests + `yarn sizes` (or scoped size check if full monorepo too heavy mid-wave; **final** W7 requires full `yarn sizes`).

**Reference implementations (copy patterns, do not invent):**

| Pattern | Location |
|---------|----------|
| Multi-Target hook | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |
| Weighted Buffer multi-Target | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| View/execute Facet split | `PLAN_facet_split.md`, Protocol DETF Query Facets |
| ExecutionDelegate | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol` |

---

## 5. Wave plan

### Wave 0 — Inventory tooling (serial)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w0-inventory` |
| **Parallelism** | 1 |
| **CODE** | Optional script only; no product Facet changes required |
| **Exit** | Parser + empty/updated wave results template; G1 list confirmed against latest `SIZES.log` |

**Tasks:**

1. Run `yarn sizes` if `SIZES.log` is stale relative to `main`.
2. Implement or document extraction of G1 Facets (margin &lt; 0, product paths).
3. Write `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md` skeleton.
4. Confirm no scope creep into vendored/test names.

---

### Wave 1 — MultiVault + MixedBuffer DETF packaging (Option **1c**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w1-detf-combined-facets` |
| **Parallelism** | 1–2 (MultiVault ∥ MixedBuffer if no shared files) |
| **Pattern** | Combined Facet → separate Exchange / Bonding / Info / Query Facets |
| **Exit** | Both G1 Facets under limit; package TestBases green |

#### 1A — MultiVault Weighted DETF

**Root:** `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/`

| Action | Detail |
|--------|--------|
| **Today** | `MultiVaultWeightedDetfExchangeInFacet` multi-inherits Query + Bonding + Info (~29.5 KiB, 33 selectors) |
| **Targets exist** | `MultiVaultWeightedDetfExchangeQueryTarget`, `...BondingTarget`, `...InfoTarget`, `...ExchangeInTarget`, `...ExchangeOutTarget` |
| **Create** | e.g. `MultiVaultWeightedDetfExchangeFacet` (In/Out + previews as appropriate), `MultiVaultWeightedDetfBondingFacet`, `MultiVaultWeightedDetfInfoFacet`, optional `MultiVaultWeightedDetfQueryFacet` if previews need isolation |
| **Modify** | DFPkg, `*_Facet_FactoryService`, `*_Component_FactoryService`, `*_Pkg_FactoryService`, `TestBase_MultiVaultWeightedDetf.sol` |
| **Remove/slim** | Combined mega-Facet either deleted or reduced to one role only |

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' -vv
# plus package-local TestBase if under contracts/.../TestBase_MultiVaultWeightedDetf.sol
```

#### 1B — MixedBuffer MultiVault Stable DETF

**Root:** `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/`

Same packaging pattern as 1A (`MixedBufferMultiVaultStableDetfExchangeInFacet` → role Facets).

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**' -vv
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/**' -vv
```

**Size gate W1:**

| Facet | Required |
|-------|----------|
| `MultiVaultWeightedDetfExchangeInFacet` (or its replacements) | All new Facets RT ≤ 24,576; old mega-Facet gone or under limit |
| `MixedBufferMultiVaultStableDetfExchangeInFacet` (or replacements) | Same |

---

### Wave 2 — Dual SE CP Buffer Hook monotarget → multi-Target (Option **1a**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w2-dual-se-cp` |
| **Root** | `contracts/hooks/uniswap/v4/standardExchange/dual/` |
| **Template** | Single SE CP Buffer multi-Target layout |
| **Exit** | All 4 Dual Facets under limit |

**Today:** four Facets inherit one `UniswapV4DualStandardExchangeBufferConstantProductHookTarget` (~1.7k lines).

**Implement:**

1. Split into role Targets (minimum):
   - `...HooksTarget` — IHooks callbacks + permissions + swap previews if hooks-owned
   - `...DepositTarget` — deposit / depositFlexible / deposit previews
   - `...WithdrawTarget` — withdraw / withdrawFlexible / withdraw previews
   - `...SeTarget` — StandardExchange In/Out entrypoints + SE helpers used only there
2. Thin `...Common` (or keep a slim shared base): bindings, lock, buffer/unwrap, reserve sync only.
3. Each Facet inherits **only** its Target + Common.
4. Move role-only internals off shared base (critical — otherwise monotarget returns).
5. Wire DFPkg / FactoryService (cuts already exist for 4 facets; bytecode isolation is the fix).
6. **Do not** change hook CREATE3 salts/flags.

**Option 2 fallback:** if any Facet still over after isolation, convert CP quote / zap-split helpers in `*Math.sol` / `*PullLib.sol` to **`external`** functions.

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/**' -vv
```

**Size gate W2:** Dual Hooks/Deposit/Se/Withdraw Facets all margin ≥ 0.

---

### Wave 3 — Orbital Buffer Hook monotarget → multi-Target (Option **1a → 2a**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w3-orbital-buffer` |
| **Root** | `contracts/hooks/uniswap/v4/standardExchange/orbital/` |
| **Exit** | All 4 Orbital Facets under limit |

**Today:** `UniswapV4StandardExchangeOrbitalBufferHookTarget` (~2.5k lines) inherited by all four Facets (~44–46 KiB each).

**Implement (mirror W2 + Single SE CP):**

1. Create role Targets:
   - `...HooksTarget`
   - `...DepositTarget` (addLiquidity, depositSingle, depositFlexible, previews)
   - `...WithdrawTarget` (removeLiquidity, withdrawFlexible, previews)
   - `...SeTarget` (exchangeIn/Out + SE buffer helpers owned by SE surface)
2. Thin Common: poolManager/token bindings, reentrancy, buffer/unwrap primitives, reserve sync, radius helpers **only if shared**.
3. Facets inherit role Target only.
4. Existing `*Math.sol`, `*ClaimLib.sol`, `*PairPoolLib.sol` — keep; if still oversize after isolation, promote hot pure paths to **`external`** (Option 2a).
5. Optional further split: Views/Query Facet for product binding views + previews if Hooks Facet remains large.
6. Preserve hook mining / flags / CREATE3 salts.

**Tests:** package TestBase under orbital dir + any `test/foundry/**/orbital/**` hook suites:

```bash
forge test --match-contract UniswapV4StandardExchangeOrbitalBuffer -vv
# or match-path once known under test/foundry/spec/hooks/.../orbital/**
```

**Size gate W3:** four Orbital Facets margin ≥ 0.

**Escalation:** if still over after 1a + external Math/Liquidity, **stop** (L-SIZE-OPT3).

---

### Wave 4 — Liquidity-heavy hooks (Option **1d → 2a**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w4-liquidity-hooks` (or 3 sub-branches) |
| **Parallelism** | Up to 3 (Weighted Buffer ∥ Curve Quad ∥ Weighted Swap) if isolated trees |
| **Exit** | Facets 5–8 (+ Weighted Swap pair) under limit |

#### 4A — Weighted Buffer Liquidity

**Root:** `contracts/hooks/uniswap/v4/standardExchange/weighted/`

| Today | `UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet` (~41 KiB), 32 selectors on one LiquidityTarget |
| **Already OK** | Hooks Facet, Se Facet |
| **Option 1** | Prefer split **Join** vs **Exit** Facets **or** **Core** vs **Flexible** Facets (flexible SE-share is a large surface). Each gets its own Target. |
| **Option 2** | `LiquidityLib` / Math **`external`** for quote + commit helpers if still over |

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**' -vv
```

#### 4B — Curve Quad Stable Buffer Liquidity

**Root:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`

Same join/exit or core/flexible template. Reference green sibling: Balancer Quad Stable Buffer Liquidity (~22 KiB).

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/**' -vv
```

#### 4C — Weighted Swap Hook (Hooks + Liquidity)

**Root:** `contracts/hooks/uniswap/v4/weighted/`

1. Ensure Hooks Facet does **not** inherit LiquidityTarget body (separate Targets).
2. Split Liquidity further if needed (join/exit or external math).
3. Promote `UniswapV4WeightedSwapHookMath` / PairPoolLib hot paths to **`external`** if required.

**Tests:** match-path under `test/foundry/spec/hooks/uniswap/v4/weighted/**` (create/extend if missing; prefer existing package tests).

**Size gate W4:** Facets 5–8 and Weighted Swap Hooks/Liquidity all margin ≥ 0.

---

### Wave 5 — Uni V4 Weighted + Orbital DETF lifecycle towers (Option **1e / 1c**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w5-detf-lifecycle` |
| **Parallelism** | 2 (Weighted DETF ∥ Orbital DETF) |
| **Exit** | Both DETF lifecycle Facets under limit |

#### Pattern (both families)

**Today:** `*DETFFacet` inherits `BondingTarget` → `ExchangeInTarget` → `ExchangeOutTarget` → fat `Common`.

**Implement:**

1. Break inheritance tower: Bonding / ExchangeIn / ExchangeOut / Compound as **siblings** of Common (not a chain).
2. Prefer separate CREATE3 Facets:
   - Exchange Facet (In + Out or In/Out split)
   - Bonding Facet
   - Compound / expansion Facet (if compound selectors live on lifecycle Facet today)
   - Keep existing Info Facet pattern
3. Each Facet inherits **only** the Target(s) for exposed selectors.
4. Update DFPkg cuts + facet factories + TestBases.
5. Option 2: externalize compound/expansion pure helpers only if still over.

**Roots:**

- Weighted: `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/`
- Orbital: `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/`

**Template size shape:** Single SE DETF Facet (already under limit).

**Tests:**

```bash
forge test --match-contract UniswapV4StandardExchangeWeightedDETF -vv
forge test --match-contract UniswapV4StandardExchangeOrbitalDETF -vv
# plus match-path under test/foundry/** as available
```

**Size gate W5:** WeightedDETFFacet + OrbitalDETFFacet (or replacements) margin ≥ 0.

---

### Wave 6 — Aerodrome Out + Uni V4 SE Out (Option **1b → 2b**)

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w6-se-out` |
| **Parallelism** | 2 if trees don’t fight |
| **Exit** | Both Out **Facets** under limit |

#### 6A — Aerodrome SE Out

**Root:** `contracts/protocols/dexes/aerodrome/v1/`

| Today | `AerodromeStandardExchangeOutFacet` inherits fat OutTarget (~7 routes × preview/execute) + Common |
| **Option 1** | View/execute split: `AerodromeStandardExchangeOutQueryTarget` + Facet (previews only); OutTarget/Facet keeps state-changing `exchangeOut` only. If still over, split execute routes into two Facets (e.g. pass-through vs vault routes) — still Option 1 packaging, **not** formula changes. |
| **Option 2** | External library for pure quote helpers (`external`); optional delegate only if needed |
| **Forbidden** | Rewriting 7-route economics (Option 3) |

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**' -vv
```

#### 6B — Uni V4 SE Out

**Root:** `contracts/protocols/dexes/uniswap/v4/`

| Today | OutFacet pulls fat `UniswapV4StandardExchangeCommon` (~1.1k lines) with In helpers |
| **Option 1** | Split Common: Out Facet must not inherit In-only helpers. Optional OutQuery Facet for `previewExchangeOut`. |
| **Option 2** | Extend `UniswapV4StandardExchangeInExecutionDelegate` pattern for zap-out / position burn (`*OutExecutionDelegate`) CREATE3 + FactoryService |
| **Care** | Do not break In Facet when splitting Common; re-check In Facet still green (near-miss policy: don’t push In over limit) |

**Tests:**

```bash
forge test --match-path 'test/foundry/spec/**/uniswap/v4/**StandardExchange**' -vv
# prefer package TestBase_UniswapV4StandardExchange under contracts/protocols/dexes/uniswap/v4/test/
```

**Size gate W6:** `AerodromeStandardExchangeOutFacet`, `UniswapV4StandardExchangeOutFacet` margin ≥ 0. Target artifacts may still show large — ignore for G1.

---

### Wave 7 — Final gate + docs

| Field | Value |
|-------|--------|
| **Branch** | `fix_size/w7-final-gate` |
| **Parallelism** | 1 |
| **Exit** | G1–G5 complete |

**Tasks:**

1. Full `yarn sizes` (seed cache; long patience).
2. Regenerate product Facet oversize list — **must be empty** for G1 names (and any new Facets introduced must also be ≤ 24,576).
3. Fill `docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md` before/after table for all 18 Facets (+ new Facets).
4. Smoke critical TestBases across waves if not already run on final tree.
5. Update PRD document control note only if needed (“program complete”); optional one-line in `docs/components/*` for facet inventory changes.
6. Confirm no Option 3 landings; confirm CREATE3-only deploy paths.

---

## 6. Parallelism matrix

| After | May run in parallel |
|-------|---------------------|
| W0 | — |
| W1 done | W2, W5 (if not touching balancer multi-vault), W6 Aerodrome |
| W2 done | W3 (similar pattern; separate tree) |
| W0 | W4A ∥ W4B ∥ W4C (distinct roots) |
| Avoid parallel | Two agents editing same DFPkg / Common / FactoryService |

**Max concurrent implementers:** 3.

**Worktree seed (mandatory on new worktree):**

```bash
# REPO = warm checkout; WT = worktree root
rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"
rsync -a "${REPO}/out/" "${WT}/out/"
rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
```

After green forge, copy `cache_forge/` + `out/` back to warm seed.

---

## 7. Subagent prompt template (per wave)

```text
You are implementing Wave <N> of docs/CONTRACT_SIZE_REDUCTION_IMPLEMENTATION_PLAN.md
under law docs/CONTRACT_SIZE_REDUCTION_PRD.md §1.1.

SCOPE: <package roots>
G1 FACETS: <names>
STRATEGY: Option 1 first (<1a|1b|1c|1d|1e>); Option 2 only if still over.
FORBIDDEN: via_ir; Option 3; mocks of SUT; changing selectors/economics; near-miss campaigns; gas gates.

STEPS:
1. Read current Facet/Target/DFPkg/FactoryService for the package.
2. Apply packaging split per wave section (copy Single SE CP / Protocol DETF patterns).
3. Wire CREATE3 + DFPkg cuts + TestBase deploys.
4. Run package tests (production-first).
5. Run yarn sizes (or compile --sizes); record Facet RT before/after in docs/CONTRACT_SIZE_REDUCTION_WAVE_RESULTS.md.
6. Confirm every wave G1 Facet margin ≥ 0. If not, deepen Option 1 or apply Option 2 (external libs). If still failing, STOP and escalate.

DO NOT: rewrite business formulas for size; delete security checks; deploy facets with `new`.
```

---

## 8. Testing matrix (summary)

| Wave | Primary test filter | Size check |
|------|---------------------|------------|
| W0 | n/a | inventory only |
| W1 | multi-vault-weighted + mixedBuffer DETF paths | both mega-Facets cleared |
| W2 | dual SE CP hook | 4 Dual Facets |
| W3 | orbital buffer hook | 4 Orbital Facets |
| W4 | weighted buffer + curve quad + weighted swap | liquidity/hooks Facets |
| W5 | WeightedDETF + OrbitalDETF | 2 lifecycle Facets |
| W6 | Aerodrome SE + UniV4 SE | 2 Out Facets |
| W7 | full `yarn sizes` + selective retests | all 18 + new Facets |

**Behavior bar (G2):** existing hermetic TestBases/Behavior suites for touched packages pass. Preview↔execute parity where view/execute split. Reentrancy locks preserved.

**Gas (G5 removed by law):** skip gas reports.

---

## 9. Definition of done (program)

| Gate | Check |
|------|--------|
| **G1** | All §2 Facets (and any newly introduced product Facets) have runtime ≤ 24,576 |
| **G2** | Touched package tests green (hermetic) |
| **G3** | All new Facets CREATE3-wired via FactoryService; DFPkg cuts complete; no `new` |
| **G4** | Product Facet oversize list empty after `yarn sizes` |
| **G5** | Wave results doc filled; component docs updated only if facet inventories documented |

**Not required:** soft headroom, CI size job, Target-only artifact clearance, gas snapshots, near-miss sweeps.

---

## 10. Risk register (execute-time)

| Risk | Mitigation |
|------|------------|
| Monotarget “split” still inherits full base | Audit inheritance graph; Facet must not import mega-Target |
| Selector missing after cut | Compare pre/post `facetFuncs` union to diamond loupe / TestBase calls |
| External lib uses wrong context | Prefer `DELEGATECALL` libraries; diamond storage only via delegatecall |
| Hook address changes | Never retune salts/flags for size work |
| Shared Common pushes In Facet over limit (W6) | Size-check sibling In Facet after Common split |
| Forge killed mid-compile | Patience + cache seed; timeout hours not minutes |
| Option 3 drift | Code review: reject formula rewrites framed as “cleanup” |

---

## 11. Orchestrator runbook

1. Confirm PRD status READY-FOR-IMPLEMENTATION and this plan READY TO EXECUTE.
2. Ship **W0** serially on `fix_size/w0-inventory`.
3. Open W1 (highest packaging ROI, smallest design risk).
4. Fan out W2 / W4 / W5 / W6 per parallelism matrix (max 3).
5. Run W3 after W2 pattern proven (largest monotarget).
6. W7 final sizes + results doc.
7. Fast-forward merge waves in dependency order; avoid long-lived divergent Commons.

**Per PR / wave merge checklist:**

- [ ] Strategy ladder respected (1 before 2; no 3)
- [ ] G1 Facets for wave ≤ 24,576
- [ ] Package tests green
- [ ] CREATE3 / DFPkg / FactoryService updated
- [ ] Selectors stable
- [ ] Wave results row(s) filled
- [ ] No near-miss-only work
- [ ] No vendored/test size work

---

## 12. File index (starting points)

| Family | Primary paths |
|--------|----------------|
| MultiVault DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` |
| MixedBuffer DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/` |
| Dual SE CP Hook | `contracts/hooks/uniswap/v4/standardExchange/dual/` |
| Orbital Buffer Hook | `contracts/hooks/uniswap/v4/standardExchange/orbital/` |
| Weighted Buffer Hook | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| Curve Quad Stable Hook | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` |
| Weighted Swap Hook | `contracts/hooks/uniswap/v4/weighted/` |
| Weighted DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/` |
| Orbital DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/` |
| Aerodrome SE | `contracts/protocols/dexes/aerodrome/v1/` |
| Uni V4 SE | `contracts/protocols/dexes/uniswap/v4/` |
| Template multi-Target | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |
| Prior facet split notes | `PLAN_facet_split.md` |

---

## 13. Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-08-11 | Initial execute plan from locked PRD v0.2; waves W0–W7; 18-Facet G1 set |

**Normative law remains the PRD.** If plan and PRD conflict, **PRD §1.1 wins**.
