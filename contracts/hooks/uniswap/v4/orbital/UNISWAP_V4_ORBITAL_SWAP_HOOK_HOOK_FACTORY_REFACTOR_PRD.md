# PRD: Uniswap V4 Orbital Swap Hook — Hook Factory Package Refactor

**Name:** `UniswapV4OrbitalSwapHook` → **Hook Diamond Package**  
**Date:** 2026-08-04  
**Status:** **Draft v1.0 — plan-ready** (deploy-shape law only; product math stays on the product PRD)  
**Package path:** `contracts/hooks/uniswap/v4/orbital/`  
**Package kind:** **Refactor PRD** — migrate the existing **CREATE3 monomorph** orbital hook onto the **Uniswap V4 Hook Diamond Package Callback Factory** standard (`IUniswapV4HookDiamondPackage` + Vault Registry `deployHookVault`).

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | **Deploy / package / factory / registry** law for the orbital migration |
| **Product PRD** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md) | **Still normative** for sphere math, LP, fees, Permit2, multi-pool doors, growth fee, previews — **except** every deploy/CREATE3/HookMiner/on-chain monomorph-factory decision this PRD **supersedes** |
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Skill | `.claude/skills/indexedex-uniswap-v4-hook-packages/` (canonical under Crane skill sync; use IndexedEx copies) |
| Gold consumer | `…/standardExchange/constantProduct/single/` — **Single SE BCP Hook DFPkg** (Option B package shape) |

**Out of scope (deliberate):**

- `contracts/hooks/uniswap/v4/standardExchange/single/` (legacy pricing wrapper) — **not** this refactor.
- Re-opening Orbital sphere / growth-fee / Permit2 product law unless a decision **must** change for diamond storage / proxy address identity.
- Migrating weighted / other monomorph hooks in this workstream.

---

## 0. Terminology

| Term | Meaning |
|------|---------|
| **Legacy orbital** | Current tree: monomorph `UniswapV4OrbitalSwapHook` + `UniswapV4OrbitalSwapHookFactory` (CREATE3, `deployer = factory`, `effectiveSalt = keccak256(salt, msg.sender)`) |
| **Hook diamond package** | `IUniswapV4HookDiamondPackage` DFPkg + product facet(s); instance = `MinimalDiamondCallBackProxy` at CREATE2-mined address |
| **Hook factory** | Ecosystem `UniswapV4HookDiamondPackageCallBackFactory` (shared; not product-specific) |
| **Product path** | `pkg.deployVault(args, mineNonce)` → `registry.deployHookVault` → hook factory |
| **Binding** | Immortal instance identity in `calcSalt` (`PRODUCT_ID` + binding fields) |
| **Pair doors** | Three V4 pools (01, 12, 02) sharing one hook address and one 3-asset reserve book |
| **DoD** | §11 |

---

## 1. Goal

Refactor Orbital so that:

1. Hook **instances** deploy as **immutable diamonds** via the **shared hook factory** (CREATE2 + `mineNonce`), **not** monomorph CREATE3.
2. The package is a **registered vault package** (`IStandardVaultPkg`) and instances are **registered vaults** via `deployHookVault`.
3. `requiredHookFlags()` is **pure / package-constant** on the package; instance exposes flags via base HookFlags facet.
4. Salt law matches factory PRD: `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` — **no** package address, **no** `msg.sender` in CREATE2 salt.
5. **Product behavior** (sphere invariant, three doors, LP ERC-20 + EIP-2612, fee oracle trading + growth fee, Permit2, previews) is **preserved** per product PRD.
6. **All-three pair-pool initialize** remains a **first-class product UX** after instance deploy (legacy factory always did this — keep the outcome, change the host).

### 1.1 Why migrate

| Legacy property | Problem under Hook Factory standard |
|-----------------|-------------------------------------|
| CREATE3 monomorph | Factory callback proxy requires CREATE2; monomorph is out of standard |
| Product-owned factory as CREATE3 deployer | Ecosystem has one hook factory; product factories must not re-invent mining |
| `msg.sender` in salt (Q53/Q61) | Salt must be binding-stable; package path is permissionless via registry ACL, not caller-scoped address |
| Not vault-registered | Liquidity-holding hooks should be vaults for discovery / indexing |
| Ctor immutables for bindings | Diamond init writes bindings in **Repo / diamond storage** via `initAccount` |
| No `IUniswapV4HookDiamondPackage` | Required package surface for hook factory |

---

## 2. Current state (as-built gap analysis)

### 2.1 Layout today

```text
contracts/hooks/uniswap/v4/orbital/
  UniswapV4OrbitalSwapHook.sol              # monomorph entry (IHooks + IERC20 + LP)
  UniswapV4OrbitalSwapHookTarget.sol        # hooks + execute
  UniswapV4OrbitalSwapHookCommon.sol        # immutables + views + shared helpers
  UniswapV4OrbitalSwapHookRepo.sol          # diamond-style storage layout (partial)
  UniswapV4OrbitalSwapHookMath.sol
  UniswapV4OrbitalSwapHookFactory.sol       # CREATE3 + init three pools + binding discovery
  UniswapV4OrbitalSwapHook_FactoryService.sol
  interfaces/IUniswapV4OrbitalSwapHook.sol
  interfaces/IUniswapV4OrbitalSwapHookFactory.sol
  UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md       # product law (keep; amend deploy sections)
  UNISWAP_V4_ORBITAL_SWAP_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md
```

### 2.2 Deploy path today

```text
off-chain mine userSalt for (factory, msg.sender)
  → factory.deploy(feeOracle, t0, t1, t2, salt, tickSpacing, sqrtPriceX96)
    → effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender))
    → CREATE3.deploy(hook bytecode + ctor args) at factory
    → initialize three PoolKeys (DYNAMIC_FEE_FLAG, hooks = hook)
    → record hooksOfBinding(feeOracle, t0, t1, t2)
```

### 2.3 Flags today (must remain package-constant)

```text
BEFORE_INITIALIZE | BEFORE_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP | BEFORE_SWAP_RETURNS_DELTA
```

### 2.4 Binding / identity today

| Field | Where |
|-------|--------|
| `poolManager` | Factory immutable + hook ctor immutable |
| `feeOracle` | Hook ctor immutable |
| `token0, token1, token2` | Hook ctor immutables (binding order, not address-sorted) |
| R / L² / reserves / kLast / LP | Repo + ERC-20 state on monomorph |

### 2.5 Gap vs gold Single SE BCP package

| Requirement (standard) | Orbital legacy | Gap |
|------------------------|----------------|-----|
| `IUniswapV4HookDiamondPackage` | No | **P0** |
| `PkgInit` / `PkgArgs` on interface | No | **P0** |
| `deployVault` → `deployHookVault` | No | **P0** |
| Shared hook factory CREATE2 | Product CREATE3 factory | **P0** |
| `PRODUCT_ID` + args salt (no pkg addr) | userSalt + msg.sender | **P0** |
| Thin `isExpectedInstance` | N/A / factory maps | **P0** |
| Facet CREATE3 + diamond cuts | Single bytecode | **P0** |
| Bindings in `initAccount` Repo | Ctor immutables in Common | **P0** |
| `vaultConfig` / vault registration | No | **P0** |
| No live `diamondCut` | N/A (monomorph) | **P0** (ensure package config) |
| Multi-pool init product UX | Factory.deploy | **P1** — re-home, do not drop |
| Binding discovery `hooksOfBinding` | Factory AddressSet | **P1** — vault registry + optional package views |

---

## 3. Locked product decisions (refactor)

### 3.1 Identity & placement

| # | Decision | Value |
|---|----------|--------|
| R1 | Product name (instance surface) | Keep **`UniswapV4OrbitalSwapHook`** as product type name / vault type id basis |
| R2 | Package type | **`UniswapV4OrbitalSwapHookDFPkg`** (or `…Package`) implementing `IUniswapV4OrbitalSwapHookPackage` |
| R3 | Path | Stay under `contracts/hooks/uniswap/v4/orbital/` |
| R4 | Gold shape | **Mirror Single SE BCP**: interface package + DFPkg + product Facet + Target + Repo + Math + FactoryService (CREATE3 facets + deployPkg helpers only) |
| R5 | Fresh codepath | **Do not subclass** monomorph contracts; pattern-copy Target/Math/Repo into facet/target with **no ctor immutables for bindings** |
| R6 | Legacy monomorph | **Retire** after green DoD: remove or quarantine monomorph + product CREATE3 factory from production path (plan may keep one release as deprecated) |

### 3.2 Deploy path (normative)

| # | Decision | Value |
|---|----------|--------|
| R7 | Instance deploy | **Only** package → registry `deployHookVault` → shared hook factory |
| R8 | Typed helper | `deployVault(PkgArgs, mineNonce)` + optional `deployVaultAutoMine` (gas-risky) |
| R9 | Direct hookFactory.deploy* | **Tests / escape only** — not product UX |
| R10 | Vault registry factory | Requires `setHookDiamondPackageFactory` once per env |
| R11 | Facets / package | CREATE3 + `deployPkg` / FactoryService; **never** `new` for SUT |
| R12 | Premine-first | Off-chain mine `mineNonce` for package salt + pure flags |

### 3.3 Salt & flags

| # | Decision | Value |
|---|----------|--------|
| R13 | `PRODUCT_ID` | Stable `keccak256("uv4-orbital-swap-hook")` (or equal fixed string — lock in plan; **never** change after first mainnet) |
| R14 | `calcSalt` includes | `PRODUCT_ID`, `poolManager`, `feeOracle`, `token0`, `token1`, `token2` in **binding order** (product Q62) |
| R15 | `calcSalt` excludes | package address, facet addresses, `msg.sender`, tickSpacing, sqrtPriceX96, saltNamespace noise |
| R16 | Token order in salt | **Exact binding order** as today (not address-sorted) — preserves product binding key law |
| R17 | `requiredHookFlags` | Package pure; same five flags as §2.3 |
| R18 | `isExpectedInstance` | **Thin**: code present + flags match (no loupe equality; no deep binding try-calls required for v1) |
| R19 | Supersedes product PRD | D78–D96 / Q49–Q62 **deploy/salt/factory** decisions that conflict with R7–R18 |

### 3.4 Storage & diamond shape

| # | Decision | Value |
|---|----------|--------|
| R20 | Bindings | All former Common **immutables** → Repo layout written in package `initAccount` (delegatecall proxy storage) |
| R21 | LP ERC-20 | Selectors on product facet; balances in Repo; **proxy address** is the LP token address (same as monomorph identity model) |
| R22 | EIP-2612 | Keep on instance surface (domain separator uses **proxy** address) |
| R23 | `diamondConfig` | Product facet cuts only; **no** `diamondCut` facet |
| R24 | Base cuts | Factory supplies ERC165 / Loupe / ERC8109 / HookFlags / temporary PostDeploy |
| R25 | Immutability | Live instance has no cut; bad config → abandon instance |

### 3.5 Vault surface

| # | Decision | Value |
|---|----------|--------|
| R26 | Package | `IStandardVaultPkg` + `vaultDeclaration` |
| R27 | Instance | Implement `IBasicVault` + `IStandardVault` (`vaultTokens` = three bound tokens; `reserveOfToken` / `reserves` from Repo; `vaultConfig` for registry) |
| R28 | SE surface | **Not required** for orbital (raw ERC-20 inventory — not dual SE buffer) |
| R29 | Vault type id | Distinct `HOOK_VAULT_TYPE` / `bytes4` for orbital (do not reuse Single SE BCP id) |

### 3.6 Multi-pool initialize (product UX preserved)

| # | Decision | Value |
|---|----------|--------|
| R30 | Outcome | After a successful product deploy flow, **all three** pair pools exist (or are ensured) with `hooks = proxy`, `fee = DYNAMIC_FEE_FLAG`, shared `tickSpacing` + `sqrtPriceX96` policy per product PRD |
| R31 | Host | **Not** a separate CREATE3 product factory. Prefer one of (plan picks one; **default recommended A**): **(A)** package `postDeploy(proxy)` initializes three pools (needs tick/sqrt in `PkgArgs` or fixed product defaults); **(B)** typed package helper `deployVaultAndInitPools(args, mineNonce, tickSpacing, sqrtPriceX96)` that deploys then inits; **(C)** thin permissionless `ensurePairPools(hook)` library/helper callable by anyone after deploy |
| R32 | Pool init args in salt | **No** — tickSpacing / sqrtPriceX96 are **not** binding identity (R15). If needed for postDeploy, pass via `PkgArgs` for process/init only, or fixed defaults in package constants |
| R33 | Idempotent ensure | Re-init of live pool reverts at PoolManager; helper must skip already-initialized doors (legacy factory behavior) |
| R34 | Discovery | Prefer registry `vaultsOfPackage` / vault tokens; optional `hooksOfBinding` view may live on package or a thin indexer — **not** a CREATE3 factory |

### 3.7 Product law that stays (do not re-open)

- Sphere invariant, R set-once, L², WAD boundary, seed/partial/full book, sphere-NAV mint (product Q44/D72).  
- Fee oracle `dexSwapFeeOfVault` + growth `usageFeeOfVault` / `kLast`.  
- Custom add/remove liquidity; ban native V4 modifyLiquidity.  
- `beforeSwap` + `beforeSwapReturnDelta` settle pattern; no BaseHook inheritance.  
- Preview bit-exact vs execution where product PRD requires.  
- Permit2 packing for inventory pulls.

---

## 4. Target architecture

### 4.1 Suggested layout

```text
contracts/hooks/uniswap/v4/orbital/
  interfaces/
    IUniswapV4OrbitalSwapHook.sol              # instance product ABI (keep/extend)
    IUniswapV4OrbitalSwapHookPackage.sol       # NEW: PkgInit, PkgArgs, deployVault
  facets/
    UniswapV4OrbitalSwapHookFacet.sol          # NEW: IFacet + Target
  UniswapV4OrbitalSwapHookDFPkg.sol            # NEW: package
  UniswapV4OrbitalSwapHookTarget.sol           # REWRITE: no binding ctor immutables
  UniswapV4OrbitalSwapHookRepo.sol             # EXTEND: full bindings + LP
  UniswapV4OrbitalSwapHookMath.sol             # keep
  UniswapV4OrbitalSwapHook_FactoryService.sol  # REWRITE: CREATE3 facet + deployPkg helpers; mineNonce helpers for tests
  TestBase_UniswapV4OrbitalSwapHook.sol        # rewrite on hook factory TestBase ladder
  UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md          # product (amend deploy sections to point here)
  THIS FILE
  UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

RETIRE (after DoD / plan phase):
  UniswapV4OrbitalSwapHook.sol                 # monomorph entry
  UniswapV4OrbitalSwapHookFactory.sol
  UniswapV4OrbitalSwapHookCommon.sol           # fold into Target/Repo
  interfaces/IUniswapV4OrbitalSwapHookFactory.sol
```

### 4.2 PkgArgs (normative shape)

```solidity
// On IUniswapV4OrbitalSwapHookPackage
struct PkgInit {
    IVaultRegistryDeployment vaultRegistryDeployment;
    IFacet productFacet;
}

struct PkgArgs {
    address poolManager;
    address feeOracle;
    address token0;
    address token1;
    address token2;
    // Optional for R31A/B — NOT in calcSalt:
    // int24 tickSpacing;
    // uint160 sqrtPriceX96;
}
```

Validation (processArgs / initAccount): non-zero addresses; distinct tokens; feeOracle non-zero (product).

### 4.3 Canonical deploy story (after refactor)

```text
1. setHookDiamondPackageFactory(hookFactory)   // once
2. registry.deployPkg(orbitalPkg initCode, PkgInit, salt)
3. off-chain: processArgs → calcSalt → mine mineNonce for requiredHookFlags
4. pkg.deployVault(args, mineNonce)
     → registry.deployHookVault → hook factory CREATE2 diamond
     → initAccount binds Repo; postDeploy / helper ensures three pools
5. Instance is vault + IHooks + LP ERC-20 at mined address
6. Users addLiquidity / swap via pair doors as product PRD
```

---

## 5. Migration plan (phases for implementation plan)

| Phase | Work | Exit |
|-------|------|------|
| **0** | Prerequisites: hook factory + registry `deployHookVault` green; `FOUNDRY_PROFILE=hook_factory` | Factory suite green |
| **1** | Package skeleton: interface, DFPkg, empty facet cuts, salt/flags, vault declaration | Deploy inert diamond via `deployVault` |
| **2** | Storage migration: Repo holds all bindings; Target reads Repo only | Views match former immutables |
| **3** | Port IHooks + LP + sphere execute (no monomorph) | Hermetic sphere lifecycle vs product PRD |
| **4** | Multi-pool ensure (R30–R33) | All three doors after product deploy flow |
| **5** | TestBase rewrite; retire monomorph factory path from TestBase | Product suite on package path |
| **6** | Deprecate / delete monomorph + product factory; amend product PRD deploy sections | Single production path |

**Do not** dual-ship monomorph and package as equal production paths after DoD.

---

## 6. Testing expectations

Ladder: `CraneTest` → `IndexedexTest` → `TestBase_UniswapV4HookDiamondPackageCallBackFactory` → `TestBase_UniswapV4OrbitalSwapHook`.

| Area | Assert |
|------|--------|
| Deploy | `deployPkg` + `deployVault(args, mineNonce)` |
| Registry | `isVault(proxy)`; `vaultsOfPackage` |
| Flags | Address bits + instance `requiredHookFlags()` |
| Salt | `calcAddress` == deploy; **no** package address in salt; same args → same address independent of package redeploy address |
| Idempotent | Second deploy same args/nonce returns same |
| Immutable | No diamondCut; PostDeploy removed |
| Pools | Three pair doors initialized / ensured |
| Product | First mint R set-once; swap previews; growth fee; ban native modifyLiquidity; Permit2 paths as product PRD |
| Profile | `FOUNDRY_PROFILE=hook_factory` |

Production-first: real factory, registry, package, facets; no mock SUT. Premine in CI; auto-mine optional smoke only.

---

## 7. Explicit supersessions of product PRD deploy law

When product PRD and this PRD conflict on **deploy**, **this PRD wins**:

| Product PRD topic | Superseded by |
|-------------------|---------------|
| CREATE3 monomorph + product factory as deployer | R7–R11 |
| Off-chain salt with `msg.sender` scope | R13–R16, R19 |
| Package kind “not DFPkg / not vault diamond” | R2, R26–R29 |
| `HookMinerCreate3` / CREATE3.getDeployed for instances | Shared hook factory CREATE2 mining |
| `isDeployedByFactory` monomorph map as primary truth | Registry vault index + thin `isExpectedInstance` |

**Product math and user APIs remain** on the product PRD until amended only for “instance = diamond proxy” wording.

---

## 8. Non-goals

1. Changing sphere geometry, fee formulas, or Permit2 packing.  
2. Adding SE buffer legs to orbital.  
3. Variable \(n\)-asset orbital.  
4. Post-deploy upgradeable hook diamonds.  
5. Migrating weighted / quad / dual in this PRD.  
6. Public marketing docs under `docs/`.  
7. Keeping monomorph CREATE3 as a parallel “supported” path after DoD.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Proxy vs monomorph gas / stack | Facet split if needed; profile `hook_factory`; preserve settle order |
| EIP-712 domain on proxy | Domain uses `address(this)` = proxy; retest permit |
| Multi-pool init in postDeploy gas | Prefer ensure helper with skip-if-live; or separate call after deploy |
| Binding order vs currency sort bugs | Keep existing pair-door construction tests |
| Abandoned product factory discovery | Document registry as SoT; optional package indexer later |

---

## 10. Related files

| Asset | Path |
|-------|------|
| Factory PRD | `contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md` |
| Gold package | `…/standardExchange/constantProduct/single/UniswapV4SingleSEBCPHookDFPkg.sol` |
| Skill | `indexedex-uniswap-v4-hook-packages` |
| Product PRD | `./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md` |

---

## 11. Definition of Done

Refactor is **done** when:

1. No production path uses monomorph CREATE3 or `UniswapV4OrbitalSwapHookFactory` for new instances.  
2. Package implements `IUniswapV4HookDiamondPackage` + `IStandardVaultPkg` with interface-held `PkgInit`/`PkgArgs`.  
3. `deployVault` → registry → hook factory is the **only** product deploy path.  
4. Flags, salt law (R13–R18), immutability, and vault registration match the skill checklist.  
5. All three pair doors are creatable/ensurable without a product CREATE3 factory.  
6. Hermetic product suite (sphere LP + swaps + fees) is green under `FOUNDRY_PROFILE=hook_factory` on the package path.  
7. Product PRD deploy sections are amended to point at this PRD / new plan (or marked superseded).  
8. Implementation plan exists as a separate file and is executable by a follow-on agent.

---

## 12. Open items for implementation plan only

| ID | Question | Default |
|----|----------|---------|
| O1 | Pool init host R31 A/B/C | **A** if gas OK; else **B** |
| O2 | Exact `PRODUCT_ID` string | `keccak256("uv4-orbital-swap-hook")` |
| O3 | Keep temporary dual-path during migration | At most one release; not long-term |
| O4 | Whether `hooksOfBinding` is reimplemented | Optional; registry first |

---

**End of refactor PRD v1.0**
