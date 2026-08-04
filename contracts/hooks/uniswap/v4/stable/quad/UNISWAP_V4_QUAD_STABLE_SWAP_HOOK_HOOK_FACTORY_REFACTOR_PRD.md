# PRD: Uniswap V4 Quad Stable Swap Hook — Hook Factory Package Refactor

**Name:** `UniswapV4QuadStableSwapHook` → **Hook Diamond Package**  
**Date:** 2026-08-04  
**Status:** **Draft v1.0 — plan-ready** (deploy-shape law only; StableSwap product law stays on the product PRD)  
**Package path:** `contracts/hooks/uniswap/v4/stable/quad/`  
**Package kind:** **Refactor PRD** — migrate the existing **CREATE3 monomorph** 4-asset StableSwap hook onto the **Uniswap V4 Hook Diamond Package Callback Factory** standard.

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | **Deploy / package / factory / registry** law for the quad migration |
| **Product PRD** [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md) | **Still normative** for StableSwap invariant, rates, zap, fee-on-output, six pair doors, LP — **except** deploy/CREATE3/HookMiner/product-factory decisions this PRD **supersedes** |
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `indexedex-uniswap-v4-hook-packages` |
| Gold consumer | `…/standardExchange/constantProduct/single/` — Single SE BCP Hook DFPkg |

**Out of scope (deliberate):**

- `contracts/hooks/uniswap/v4/standardExchange/single/` (legacy pricing wrapper).  
- General \(n\)-coin StableSwap factory; v1 remains **exactly four** assets.  
- Orbital / dual / weighted migrations (separate PRDs).  
- Re-opening amp ramp, rate fail-closed policy, or zap `sharesMin`-only law unless required for diamond storage.

---

## 0. Terminology

| Term | Meaning |
|------|---------|
| **Legacy quad** | Current tree: monomorph `UniswapV4QuadStableSwapHook` + `UniswapV4QuadStableSwapHookFactory` (ecosystem CREATE3 + `HookMinerCreate3` + all-six pool ensure) |
| **Hook diamond package** | `IUniswapV4HookDiamondPackage` + vault registration via `deployHookVault` |
| **Pair doors** | All \(\binom{4}{2} = 6\) address-sorted V4 pairs sharing one hook + one 4-asset reserve book |
| **Rate-scaled reserve** | 1e18 stable units via decimals + optional `IRateProvider` (product PRD) |
| **DoD** | §11 |

---

## 1. Goal

Refactor Quad Stable so that:

1. Instances are **immutable diamonds** at CREATE2-mined addresses via the **shared hook factory**.  
2. Package is a **registered vault package**; instances are **registered vaults**.  
3. Pure package-constant `requiredHookFlags()` (including **beforeDonate** as today).  
4. Salt law: `PRODUCT_ID` + binding fields + factory `mineNonce` — **no** package address.  
5. **Product behavior** preserved: 4-asset StableSwap, fee-on-output, rate providers fail-closed, proportional add/remove, zap-in, six doors.  
6. **All-six pair-pool ensure** remains first-class product UX (legacy factory `deploy` / `ensurePairPools`).

### 1.1 Why migrate

| Legacy property | Problem under standard |
|-----------------|------------------------|
| CREATE3 monomorph via `HookMinerCreate3` | Instances must be CREATE2 hook-factory diamonds |
| Product `UniswapV4QuadStableSwapHookFactory` owns mine+deploy | Product factory must not replace ecosystem hook factory |
| Salt namespace string + binding in CREATE3 salt | Package `calcSalt` + factory `mineNonce` composition |
| Ctor immutables (tokens, amp, fee, rates) | Diamond `initAccount` → Repo |
| Not vault-registered | Liquidity-holding hook should be a vault |
| No `IUniswapV4HookDiamondPackage` | Required for hook factory |

---

## 2. Current state (as-built gap analysis)

### 2.1 Layout today

```text
contracts/hooks/uniswap/v4/stable/quad/
  UniswapV4QuadStableSwapHook.sol                 # monomorph entry
  UniswapV4QuadStableSwapHookTarget.sol
  UniswapV4QuadStableSwapHookCommon.sol           # many immutables
  UniswapV4QuadStableSwapHookRepo.sol
  UniswapV4QuadStableSwapHookMath.sol
  UniswapV4QuadStableSwapHookFactory.sol          # CREATE3 + six doors
  UniswapV4QuadStableSwapHookDeployer.sol
  UniswapV4QuadStableSwapHook_FactoryService.sol  # HookMinerCreate3
  TestBase_UniswapV4QuadStableSwapHook.sol
  interfaces/IUniswapV4QuadStableSwapHook.sol
  interfaces/IUniswapV4QuadStableSwapHookFactory.sol
  product PRD + implementation plan
```

### 2.2 Deploy path today

```text
factory.deploy(t0..t3, lpFeePips, baseAmp, rateProviders[4], saltNamespace)
  → FactoryService: mine CREATE3 salt via HookMinerCreate3 on create3Factory
  → deploy monomorph with ctor immutables
  → initialize / ensure all six pair PoolKeys
      fee = lpFeePips, tickSpacing = Math.TICK_SPACING, hooks = hook
```

Also: `deployWithMineNonce`, `ensurePairPools`, `predictHookAddress`.

### 2.3 Flags today (must remain package-constant)

```text
BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA | BEFORE_DONATE
```

**Note:** Quad uniquely includes **`BEFORE_DONATE`** among the three hooks in this refactor set. Package pure flags **must** keep donate ban/gate semantics from product PRD (beforeDonate reverts native donate path).

### 2.4 Binding / identity today

| Field | Law |
|-------|-----|
| `token0..token3` | **Strict address ascending** at deploy |
| `lpFeePips` | Deploy-time immutable; also PoolKey fee |
| `baseAmp` | Deploy-time immutable; no ramp v1 |
| `rateProviders[4]` | `IRateProvider` or `address(0)` per leg |
| `poolManager` | Factory immutable = canonical PM |
| Reserves / LP / D | Repo + monomorph ERC-20 |

### 2.5 Gap vs gold Single SE BCP

| Requirement | Quad legacy | Gap |
|-------------|-------------|-----|
| Hook diamond package interface | No | **P0** |
| Registry `deployHookVault` | No | **P0** |
| Shared CREATE2 hook factory | CREATE3 + HookMiner | **P0** |
| `PRODUCT_ID` salt | namespace string + binding | **P0** |
| Thin `isExpectedInstance` | Factory predict / deploy maps | **P0** |
| Facet + DFPkg | Monomorph | **P0** |
| Repo bindings (no ctor immutables) | Common immutables | **P0** |
| Vault registration | No | **P0** |
| Six-door ensure | Product factory | **P1** re-home |
| Rate provider + amp in binding | Yes (keep in salt) | — |

---

## 3. Locked product decisions (refactor)

### 3.1 Identity & placement

| # | Decision | Value |
|---|----------|--------|
| Q1 | Product name | Keep **`UniswapV4QuadStableSwapHook`** |
| Q2 | Package type | **`UniswapV4QuadStableSwapHookDFPkg`** + `IUniswapV4QuadStableSwapHookPackage` |
| Q3 | Path | `contracts/hooks/uniswap/v4/stable/quad/` |
| Q4 | Gold shape | Mirror Single SE BCP (package + facet + Target + Repo + Math + FactoryService for facets/deployPkg) |
| Q5 | Fresh codepath | Do **not** subclass monomorph; pattern-copy math/target into diamond form |
| Q6 | Legacy monomorph / product factory | Retire after DoD |

### 3.2 Deploy path

| # | Decision | Value |
|---|----------|--------|
| Q7 | Product path | `pkg.deployVault(args, mineNonce)` → `deployHookVault` → hook factory |
| Q8 | Auto-mine | Optional `deployVaultAutoMine` only (gas-risky) |
| Q9 | Direct factory | Tests / escape only |
| Q10 | Bootstrap | `setHookDiamondPackageFactory` once |
| Q11 | CREATE3 | Facets + package only — **not** instances |

### 3.3 Salt & flags

| # | Decision | Value |
|---|----------|--------|
| Q12 | `PRODUCT_ID` | `keccak256("uv4-quad-stable-swap-hook")` (lock in plan) |
| Q13 | `calcSalt` includes | `PRODUCT_ID`, `poolManager`, `token0..token3` (sorted), `lpFeePips`, `baseAmp`, `rateProviders[4]` |
| Q14 | `calcSalt` excludes | package/facet addresses, `saltNamespace` string, caller, mineNonce (factory adds mineNonce) |
| Q15 | Token order | Enforce ascending in `processArgs`; salt uses validated sorted order |
| Q16 | Rate providers in salt | **Yes** — different rates = different immortal instance |
| Q17 | `requiredHookFlags` | Pure; flags §2.3 including **BEFORE_DONATE** |
| Q18 | `isExpectedInstance` | Thin: code + flags |
| Q19 | Supersedes product PRD | All CREATE3 mine / product factory deploy sections conflicting with Q7–Q18 |

### 3.4 Storage & diamond

| # | Decision | Value |
|---|----------|--------|
| Q20 | Bindings | Former Common immutables → Repo via `initAccount` |
| Q21 | Decimals / base scales | Computed at init, stored in Repo (fail-closed reads as product) |
| Q22 | LP ERC-20 | Facet selectors; storage in Repo; **proxy** is LP token |
| Q23 | No `diamondCut` in package config | Immutable after postDeploy |
| Q24 | Base facets | Factory HookFlags + loupe/ERC165/etc. |

### 3.5 Vault surface

| # | Decision | Value |
|---|----------|--------|
| Q25 | Package | `IStandardVaultPkg` |
| Q26 | Instance | `IBasicVault` + `IStandardVault`; `vaultTokens` = four bound ERC-20s; reserves from Repo |
| Q27 | SE surface | **Not required** (raw multi-asset StableSwap) |
| Q28 | Vault type id | Distinct from orbital / dual / single SE BCP |

### 3.6 Six pair doors (product UX preserved)

| # | Decision | Value |
|---|----------|--------|
| Q29 | Outcome | All six pair doors ensureable after product deploy flow |
| Q30 | Host | **Default B+C hybrid:** package helper after `deployVault` **or** permissionless `ensurePairPools(hook)` (legacy factory had both deploy-time ensure and explicit `ensurePairPools`). **Do not** put six `initialize` calls exclusively inside gas-fragile auto-mine. Prefer: deploy diamond → `ensurePairPools(proxy)` (package method or library, callable by anyone) |
| Q31 | PoolKey policy | `fee = lpFeePips`, `tickSpacing = Math.TICK_SPACING` (or product constant), currencies address-sorted pair, `hooks = proxy` |
| Q32 | Pool params in salt | **No** — fee/amp already in binding; tickSpacing is package constant |
| Q33 | Idempotent ensure | Skip already-live doors; emit counts like legacy `PairPoolsEnsured` |
| Q34 | Discovery | Registry first; optional `pairPoolKeys(hook)` view on package or helper |

### 3.7 Product law that stays

- StableSwap \(n=4\), Newton D/y solvers, fee-on-output (D20), residual in book (no skim).  
- Rates: `IRateProvider` only; fail closed.  
- First add: all four legs > 0; MINIMUM_LIQUIDITY lock.  
- Zap-in: internal StableSwap rebalance; public slippage **`sharesMin` only**.  
- Swap-live gates: in/out reserves > 0; witnesses may be zero.  
- No BaseHook / DeltaResolver inheritance.  
- No fee oracle dependency for LP fee (unlike orbital/dual) — deploy-time `lpFeePips`.

---

## 4. Target architecture

### 4.1 Suggested layout

```text
contracts/hooks/uniswap/v4/stable/quad/
  interfaces/
    IUniswapV4QuadStableSwapHook.sol           # keep/extend instance ABI
    IUniswapV4QuadStableSwapHookPackage.sol    # NEW
  facets/
    UniswapV4QuadStableSwapHookFacet.sol       # NEW
  UniswapV4QuadStableSwapHookDFPkg.sol         # NEW
  UniswapV4QuadStableSwapHookTarget.sol        # REWRITE (Repo bindings)
  UniswapV4QuadStableSwapHookRepo.sol          # EXTEND
  UniswapV4QuadStableSwapHookMath.sol          # keep
  UniswapV4QuadStableSwapHook_FactoryService.sol  # facet/deployPkg + ensurePairPools helpers
  TestBase_UniswapV4QuadStableSwapHook.sol     # rewrite on hook factory ladder
  product PRD (amend deploy) + THIS FILE + follow-on plan

RETIRE after DoD:
  UniswapV4QuadStableSwapHook.sol
  UniswapV4QuadStableSwapHookFactory.sol
  UniswapV4QuadStableSwapHookDeployer.sol
  UniswapV4QuadStableSwapHookCommon.sol
  interfaces/IUniswapV4QuadStableSwapHookFactory.sol
```

### 4.2 PkgArgs (normative shape)

```solidity
struct PkgInit {
    IVaultRegistryDeployment vaultRegistryDeployment;
    IFacet productFacet;
}

struct PkgArgs {
    address poolManager;
    address token0;
    address token1;
    address token2;
    address token3;
    uint24 lpFeePips;
    uint256 baseAmp;
    address[4] rateProviders;
}
```

`processArgs`: require `token0 < token1 < token2 < token3`; validate amp/fee ranges per product Math constants; zero token revert.

### 4.3 Canonical deploy story

```text
1. setHookDiamondPackageFactory
2. deployPkg(quad package)
3. premine mineNonce for PRODUCT_ID + binding
4. pkg.deployVault(args, mineNonce) → registered diamond hook
5. ensurePairPools(proxy) → all six doors
6. addLiquidity / zapIn / swaps per product PRD
```

---

## 5. Migration phases

| Phase | Work | Exit |
|-------|------|------|
| **0** | Hook factory + registry green | Factory suite green |
| **1** | Package skeleton, salt/flags, vault decl | Inert diamond deploy |
| **2** | Repo full binding + rate scales | Views parity |
| **3** | Port StableSwap IHooks + LP + zap | Hermetic math suite |
| **4** | `ensurePairPools` re-home | Six doors without product CREATE3 factory |
| **5** | TestBase rewrite | Package-path suite |
| **6** | Delete monomorph path; amend product PRD deploy | Single path |

---

## 6. Testing expectations

Ladder: factory TestBase → `TestBase_UniswapV4QuadStableSwapHook`.

| Area | Assert |
|------|--------|
| Deploy / registry / flags / salt / idempotent / immutable | Skill checklist |
| Token sort | Unsorted `PkgArgs` reverts at processArgs |
| Rates | Fail-closed rate reads still revert on bad providers |
| Six doors | After ensure, all six keys live or skip-if-live |
| Product | First four-leg mint; fee-on-output swap; zap `sharesMin`; donate banned; preview fidelity |
| Profile | `FOUNDRY_PROFILE=hook_factory` |

Production-first: no mock package/factory/registry; real PoolManager hermetic port.

---

## 7. Explicit supersessions

| Product PRD deploy topic | Superseded by |
|--------------------------|---------------|
| CREATE3 monomorph + HookMinerCreate3 for instances | Q7–Q11 |
| Product factory as primary UX | Q7, Q30 |
| `saltNamespace` in identity | Q14 (removed from salt; PRODUCT_ID replaces) |
| Package kind “not Facet/DFPkg” | Q2–Q4, Q25–Q28 |

StableSwap math, rates, zap, fee-on-output remain on product PRD.

---

## 8. Non-goals

1. \(n \neq 4\) generalization.  
2. Amp ramp / admin fee skim.  
3. Fee oracle integration for this product.  
4. SE buffer legs.  
5. Parallel monomorph support after DoD.  
6. Refactoring orbital/dual in this PRD.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Six `initialize` gas | Ensure helper separate from CREATE2 mine loop |
| Rate provider addresses in salt bloat | Accept — correct binding identity |
| Donate flag density mining | Premine-first; MAX_LOOP peer |
| Newton solvers on diamond stack | Keep Math pure library; Target thin |

---

## 10. Related files

| Asset | Path |
|-------|------|
| Factory PRD | `…/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Gold package | `…/constantProduct/single/UniswapV4SingleSEBCPHookDFPkg.sol` |
| Product PRD | `./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md` |
| Existing TestBase | `./TestBase_UniswapV4QuadStableSwapHook.sol` (rewrite) |

---

## 11. Definition of Done

1. Production path is only package → registry → hook factory.  
2. `IUniswapV4HookDiamondPackage` + vault surfaces complete.  
3. Flags include beforeDonate; salt law Q12–Q18.  
4. Six doors ensureable without product CREATE3 factory.  
5. Hermetic StableSwap + zap suite green on package path under `hook_factory` profile.  
6. Monomorph + `UniswapV4QuadStableSwapHookFactory` retired from production.  
7. Product PRD deploy sections amended or marked superseded.  
8. Separate implementation plan file exists.

---

## 12. Open items for plan only

| ID | Question | Default |
|----|----------|---------|
| O1 | Ensure host: package method vs free library | Package `ensurePairPools` callable by anyone |
| O2 | Keep `predictHookAddress` UX | Via hook factory `calcAddress` + package `calcSalt` docs |
| O3 | Temporary dual-path | At most one transition release |

---

**End of refactor PRD v1.0**
