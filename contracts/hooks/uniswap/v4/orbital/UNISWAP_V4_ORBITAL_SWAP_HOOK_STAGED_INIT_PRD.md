# PRD: Uniswap V4 Orbital Swap Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4OrbitalSwapHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.5** — Q&A #4 still locked for diamond shape (S47–S57). **v0.5 door ABI:** `deployPair(address,address)` only. Named `deployPairPool01/12/02` and pairId are void. Shared `IUniswapV4HookStagedPairInit`. CODE already in this worktree must be amended.  
**Package path:** `contracts/hooks/uniswap/v4/orbital/`  
**Package kind:** **Amend** the existing hook diamond package (`UniswapV4OrbitalSwapHookDFPkg`). Not a new product. Not a factory rewrite.

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | **Normative** for staged bring-up: bootstrap vs production cuts, door calls, `finalizeInitialization` (internal cut), `pkg.postDeploy`, and which in-repo callers must follow |
| [Hook factory refactor PRD](./UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md) | CREATE2, salt, flags, `deployVault` arity — **except** R30–R31 / “atomic all-three in `postDeploy`,” which **this PRD supersedes** |
| [Product PRD](./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md) | Sphere, LP, fees, Permit2, `beforeInitialize` *rules*, extra PoolKeys (Q31) — **except** D8 / D80 / O6 same-tx all-three doors, which **this PRD supersedes** |
| [Hook factory PRD](../factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md) | Unchanged. **F33 stays:** no public `diamondCut` selector. Finalize uses `ERC2535Repo._processFacetCuts` only |
| Skill | `indexedex-uniswap-v4-hook-packages` |

If this PRD conflicts with the refactor or product PRD on **door timing**, **which facets exist when**, or **finalize**, **this PRD wins**.

**Follow-on (not this file):** `UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md` after acceptance. Other V4 hook families: [`../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md).

---

## 0. One-line goal

Bring up an Orbital hook in three caller stages — **deploy a bootstrap diamond**, **create each product pair door**, **`finalizeInitialization`** — so the deploy transaction does not also install the full production ABI or run three `PoolManager.initialize`s.

Callers never issue a diamond cut. `finalizeInitialization` performs the cut **internally**: remove the init facet, add the production facets.

---

## 1. Why

Today `_deployAt` is one transaction:

```text
CREATE2 proxy
  → initAccount: factory base + 7 production cuts + storage init
  → pkg.postDeploy: three PoolManager.initialize (+ beforeInitialize each)
  → factory freeze (remove PostDeploy)
```

That is the public-network gas cliff. Orbital is the simplest multi-door family (exactly three product doors) and the gold for this pattern.

`PoolManager.initialize` is an external PoolManager call. The hook is only `PoolKey.hooks`. Staging is about **transaction size** and **when the production ABI appears**, not about inventing a new pool-creation opcode.

---

## 2. Terminology

| Term | Meaning |
|------|---------|
| **Product doors** | Binding pairs **01**, **12**, **02**. Address-sorted currencies. `fee = DYNAMIC_FEE_FLAG`. `hooks = proxy`. Tick/sqrt from Repo (PkgArgs process-only) |
| **Door 01 / 12 / 02** | `(token0, token1)`, `(token1, token2)`, `(token0, token2)` in **binding order** |
| **Deploy tx** | `pkg.deployVault(args, mineNonce)` → `deployHookVault` → hook factory |
| **Bootstrap facets** | Cut in during factory `initAccount` via `pkg.diamondConfig().facetCuts`. Vault pair + **package-as-init**. **Not** the swap/LP ABI |
| **Init facet** | The **package contract itself**. `UniswapV4OrbitalSwapHookDFPkg` inherits `UniswapV4OrbitalSwapHookInitFacet`. Factory Adds `address(pkg)` with **init-only** selectors. **Not** a CREATE3 facet. **Not** the factory PostDeploy facet |
| **Production facets** | Existing hooks + liquidity + ERC20 + ERC5267 + ERC2612. **`facetFuncs()` unchanged.** Absent from the diamond until finalize |
| **Registry vault facets** | `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet`. **Bootstrap** — `deployHookVault` calls `IStandardVault(vault).vaultConfig()` in the same tx |
| **Factory freeze** | Existing `IPostDeployAccountHook(proxy).postDeploy()` in the deploy tx |
| **Finalized** | `finalizeInitialization` has run once; init facet gone; production facets live |
| **DoD** | §11 |

---

## 3. Current as-built (gap)

| Piece | Today | Gap |
|-------|--------|-----|
| `pkg.postDeploy` | `ensureThreePairPools` in the deploy tx | **P0** — zero inits |
| `facetCuts()` | 7 production facets, no init facet | **P0** — vault pair + package-as-init only at deploy |
| Instance ABI after deploy | Full hooks + LP | **P0** — bootstrap only until finalize |
| `finalizeInitialization` | Missing | **P0** — Remove init + Add production |
| Factory `_deployAt` | `pkg.postDeploy` then freeze | Keep both; change `postDeploy` body |
| F33 / no public `diamondCut` | Yes | **Keep** |
| `beforeInitialize` | Hooks facet only | **P0** — must exist **before** any door; hooks facet is not there yet |
| `vaultConfig` at register | Vault facets on proxy | **Keep** those two facets in bootstrap |
| Extra PoolKeys (Q31) | Allowed | **Keep** |
| Tests / research fixture | Assume doors + full ABI after `deployVault` | **P0** |

---

## 4. Locked decisions

Status **Locked** = accepted in the 2026-08-17 Q&A (or required by registry / V4 flags). Do not reopen without editing this PRD.

### 4.1 Scope

| # | Decision | Status |
|---|----------|--------|
| S1 | **Family:** `contracts/hooks/uniswap/v4/orbital/` (DFPkg, interfaces, facets, PairPoolLib, Repo, TestBase, FactoryService, co-located + mirrored tests). | Locked |
| S1b | **Grep-and-fix in the same change set.** Plan greps `UniswapV4OrbitalSwapHookDFPkg` and this package’s `deployVault` / `deployVaultAutoMine`. Known hits: gold TestBase, orbital hook tests, `scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol`. Fix every additional hit. **Do not** expand to SE Orbital, frontend, or unrelated Anvil scripts unless that grep hits them. | Locked |
| S2 | **Do not** change hook factory salt, mining, callback, or F33. Factory still calls `pkg.postDeploy` then `proxy.postDeploy()` in `_deployAt`. | Locked |
| S3 | **Do not** reopen sphere, LP math, fees, Permit2, flags, `calcSalt`, `PRODUCT_ID`, thin `isExpectedInstance`, or `deployHookVault` arity. | Locked |
| S4 | **Do not** implement SE Orbital / weighted / quad in this change set. This PRD is the pattern those families may copy. | Locked |
| S5 | Single / dual (one-pool) hooks are **out of scope**. | Locked |

### 4.2 Lifecycle (normative)

```text
tx Deploy (factory._deployAt — unchanged control flow):
  CREATE2 proxy
  factory.initAccount(pkg, args)             # on the proxy via callback
    — factory base cuts (ERC165, Loupe, ERC8109, PostDeploy, HookFlags)
    — factory ERC165Repo._registerInterfaces(factory.facetInterfaces())
    — pkg.diamondConfig().facetCuts  (S7 / S48):
        MultiAssetBasicVaultFacet
        MultiAssetStandardVaultFacet
        address(pkg)                    # package-as-init; init-only selectors
    — factory ERC165Repo._registerInterfaces(pkg.facetInterfaces())
      # today's six IDs, including IERC20* (S52). Not a lying-ERC165 fix.
    — pkg._initAccount: bindings, ERC20Repo + EIP712Repo, vault repos
      (storage written even though ERC20/hooks/liquidity facets are not cut yet)
    — no Repo write of production facet addresses (S40 superseded)
  pkg.postDeploy(proxy)                      # S12 / S56: return true; zero inits
  IPostDeployAccountHook(proxy).postDeploy() # factory freeze (remove PostDeploy)
  emit HookDiamondDeployed
  registry: IStandardVault(proxy).vaultConfig() then _registerVault

tx Door 01 / 12 / 02 (anyone, any order):
  proxy.deployPair(tokenA, tokenB)           # delegatecall → package bytecode; product pair only
  → PoolManager.initialize → proxy.beforeInitialize (package-as-init)

tx Finalize (anyone, once):
  proxy.finalizeInitialization()             # delegatecall → package bytecode
  → require all three product doors live
  → nonReentrant
  → one ERC2535Repo._processFacetCuts:
       Remove  address(SELF) + InitFacet.facetFuncs()
       Add     productionFacetCuts() from package immutables
               + each production facet's live facetFuncs()
  → emit IDiamond.DiamondCut(cuts, address(0), "")
  → emit InitializationFinalized(proxy)
  → initializationFinalized = true
  → no extra ERC165 register (already done at deploy)
```

| # | Decision | Status |
|---|----------|--------|
| S6 | **Three caller stages:** deploy bootstrap diamond → one call per product door → `finalizeInitialization`. | Locked |
| S7 | **Deploy tx cuts bootstrap only** (S2 factory base + vault pair + **package-as-init**). Production facets (hooks, liquidity, ERC20, ERC5267, ERC2612) are **not** in `facetCuts()` / `diamondConfig` used at `initAccount`. See S47–S49. | Locked |
| S8 | **Package-as-init is temporary on the diamond.** After finalize those selectors are unmatched on the proxy. The package contract remains the registered DFPkg. | Locked |
| S9 | **No public `diamondCut`.** Callers never pass `FacetCut[]`. Finalize is the only post-deploy facet-map mutation. | Locked |
| S10 | **`finalizeInitialization` Adds `productionFacetCuts()`** (hooks, liquidity, ERC20, ERC5267, ERC2612) and **Removes** the package-as-init cut in the **same** `_processFacetCuts`. Remove entries **first**, then Add (so `beforeInitialize` moves package → hooks facet). No Replace. Cuts built from package immutables (S51). | Locked |
| S11 | Factory freeze still runs in the **deploy tx**. | Locked |
| S12 | **`pkg.postDeploy` initializes zero V4 pools.** Keep the existing signature: `function postDeploy(address) public returns (bool)` returning `true`. **Not** `pure` (interface stays). No `ensureThreePairPools`. No new required event (`HookDiamondDeployed` already exists). | Locked |

### 4.3 Why vault stays on the bootstrap diamond

**Confirmed (Q&A #3 correction).** A draft idea to put **only** the package in `facetCuts()` is **void**. Registry deploy still needs the vault declaration facets on the proxy at the end of the deploy transaction.

`VaultRegistryDeploymentTarget.deployHookVault` does, in the same transaction as CREATE2:

```solidity
vault = hookFactory.deployWithMineNonce(...);
VaultRegistryVaultRepo._registerVault(vault, address(pkg), IStandardVault(vault).vaultConfig());
```

`vaultConfig()` is implemented by `MultiAssetStandardVaultFacet` and reads `StandardVaultRepo` + `MultiAssetBasicVaultRepo`. Those two facets **must** be callable at the end of the deploy tx. S3 forbids changing `deployHookVault`. Therefore they are **bootstrap**, not production-deferred, and they stay **after** finalize.

`initAccount` still writes ERC20 / EIP712 / product Repo storage in the deploy tx. Missing ERC20 facets only means those *selectors* are absent until finalize.

The package is the init facet (S47). It must **not** implement `vaultConfig` / vault views. Those stay on the two vault facets so finalize can Remove the entire package-as-init selector set without dropping registration.

### 4.4 Why the init facet implements `beforeInitialize`

The mined address includes `BEFORE_INITIALIZE`. Each `deployPair` calls `PoolManager.initialize`, which callbacks `beforeInitialize` on the proxy **before** finalize (hooks facet not installed yet).

| # | Decision | Status |
|---|----------|--------|
| S35 | Package-as-init **implements** `IHooks.beforeInitialize` with **exactly today’s** hooks-target checks: `_onlyPoolManager`, pair ⊂ bound tokens, distinct, `fee == DYNAMIC_FEE_FLAG`. Return `IHooks.beforeInitialize.selector`. Shared library used by InitTarget and HooksTarget — **do not** fork two validators. **Do not** add a new `hooks == address(this)` check (not in today’s target; production `facetFuncs()` stay unchanged). | Locked |
| S35b | Package-as-init **does not** implement `beforeSwap`, `beforeAddLiquidity`, or other flagged callbacks. A swap or V4 `modifyLiquidity` before finalize hits an unmatched selector and reverts. That is intended. | Locked |
| S35c | After finalize, `beforeInitialize` lives **only** on the existing hooks facet (same library). The package-as-init `beforeInitialize` selector is Removed in the same cut that Adds the hooks facet. | Locked |

### 4.5 Caller surface

| # | Decision | Status |
|---|----------|--------|
| S13 | **Superseded by S58.** Named `deployPairPool01/12/02` are void. | Void |
| S14 | **Superseded by S58.** | Void |
| S15 | **No** bulk `ensureThreePairPools` on the init facet. | Locked |
| S16 | `finalizeInitialization() external returns (bool)` — returns **`true`** after a successful cut. S20–S24, S10, S54. | Locked |
| S17 | **Superseded by S53.** Door views exist **only** on package-as-init and vanish at finalize. Do **not** add them to the hooks facet. | Locked |
| S18 | **Superseded by S58.** No `deployPairPool(uint8)` and no pairId on any family. | Void |
| S19 | Door calls and finalize are **permissionless**. ERC8109 multicall may bundle doors + finalize after deploy. Not required. | Locked |
| S33 | **Superseded by S58 / S59.** Init surface is shared `IUniswapV4HookStagedPairInit`. Orbital may `is` that interface (thin `IUniswapV4OrbitalSwapHookInit` alias allowed). **Do not** add door views to `IUniswapV4OrbitalSwapHook`. | Void |

```solidity
// IUniswapV4HookStagedPairInit — every family Init, unmatched after finalize
error InitializationAlreadyFinalized();
error ProductDoorsNotLive();

event PairPoolDeployed(
    address indexed hook,
    address indexed currency0,
    address indexed currency1,
    bytes32 poolId
);
event InitializationFinalized(address indexed hook);

function deployPair(address tokenA, address tokenB) external returns (PoolKey memory key);
function finalizeInitialization() external returns (bool);
function isPairPoolLive(address tokenA, address tokenB) external view returns (bool);
function pairPoolKey(address tokenA, address tokenB) external view returns (PoolKey memory);
function isInitializationFinalized() external view returns (bool);
```

`deployPair` sorts internally (`currency0 < currency1`). `(a,b)` and `(b,a)` are the same door. Same token, or a pair that is not an Orbital product door `(t0,t1)/(t1,t2)/(t0,t2)`, reverts (`InvalidPoolToken` or family equivalent). Builds the **product** PoolKey (S34) and `initIfNeeded`. Skip-if-live returns that key and emits nothing.

`pairPoolKey(a,b)` always returns that constructed product key when `(a,b)` is a product pair, even if not live. `isPairPoolLive` is `PairPoolLib.isPoolLive` on that key. Non-product pairs revert.

After finalize those selectors are unmatched. Callers reconstruct keys from `token0`/`token1`/`token2` + `pairPoolTickSpacing` via `PairPoolLib.pairKey`. Tests treat unmatched `finalizeInitialization` / `isInitializationFinalized` as “finalized.”

### 4.6 Finalize (internal cut)

| # | Decision | Status |
|---|----------|--------|
| S20 | Finalize **reverts** `ProductDoorsNotLive()` unless all three **product** doors are live. Live = `PairPoolLib.isPoolLive` on the **exact** product PoolKey (S34). Extra Q31 PoolKeys do not count. | Locked |
| S21 | **One-shot.** Repo `initializationFinalized`. Second call reverts `InitializationAlreadyFinalized()`. Set the flag **after** a successful cut (a reverting cut must not brick the instance as “finalized” with package-as-init still attached). Use the existing product **`nonReentrant`** modifier (not an alternate lock) on finalize so a callback cannot run a second cut mid-function. Do **not** reuse `NotLive` (that error is sphere / \(R\)). | Locked |
| S22 | Cut payload is **fixed in code**. Remove = `address(SELF)` + `InitFacet.facetFuncs()`. Add = `productionFacetCuts()` from package **immutables** (`HOOKS_FACET`, `LIQUIDITY_FACET`, `ERC20_FACET`, `ERC5267_FACET`, `ERC2612_FACET`) and each facet’s live `facetFuncs()`. No caller-supplied cuts. No Repo-stored facet addresses. | Locked |
| S23 | After success, no remaining selector may call `_processFacetCuts`. | Locked |
| S24 | Any caller may finalize once the three product doors exist (including doors created by raw `PoolManager.initialize` with the product PoolKey). | Locked |
| S25 | Unfinalized instances are valid bootstrap diamonds. Registry registration in the deploy tx **stays**. `isExpectedInstance` **stays thin** (code + flags). First-deployer-wins must not require finalized. | Locked |
| S26 | **Swaps and `addLiquidity` / `removeLiquidity` require finalized** in this design, because those selectors do not exist until S10. Product D62 “LP needs no doors” still holds **after** finalize. A swap also still needs that directed door live. | Locked |
| S40 | **Superseded by S51.** Do **not** write production facet addresses into Repo. Finalize reads them from package immutables under delegatecall. | Locked |
| S41 | **Superseded by S52.** Leave `facetInterfaces()` as today’s six IDs. Factory registers them at deploy. Finalize does not register or unregister ERC165 IDs. | Locked |
| S45 | **Superseded by S59.** pairId event is void. | Void |
| S46 | Finalize Adds exactly `pkg.productionFacetCuts()`. Tests assert `pkg.facetCuts()` ≠ finalized loupe production set, and the proxy loupe Add set matches `pkg.productionFacetCuts()`. | Locked |

### 4.7 Package / diamond shape

| # | Decision | Status |
|---|----------|--------|
| S27 | **Superseded by S47.** `PkgInit` does **not** gain `initFacet`. Existing production + vault facet fields stay. Constructor still reverts `ZeroAddress()` if any of those is zero. | Locked |
| S28 | **Split package views.** `facetCuts()` / `diamondConfig.facetCuts` = **bootstrap only** (vault pair + `address(this)` / `SELF` as init) — what the factory applies at `initAccount`. New `productionFacetCuts()` on `IUniswapV4OrbitalSwapHookPackage` = the **Add** list finalize applies (hooks, liquidity, ERC20, ERC5267, ERC2612). `facetAddresses()` lists vault pair + five production + `address(this)`. `diamondConfig.interfaces` = `facetInterfaces()` unchanged (S52). | Locked |
| S29 | `calcSalt` still excludes all facet addresses (including the package address). | Locked |
| S30 | **Superseded by S47.** Do **not** CREATE3-deploy InitFacet. Do **not** add `FactoryService.deployInitFacet`. InitFacet is inherited source only. Production facets stay CREATE3 as today. **Never** `new`. | Locked |
| S31 | Pair keys stay in `UniswapV4OrbitalSwapHookPairPoolLib`. No second key builder. | Locked |
| S32 | **No** package-level `ensurePairPools`. After finalize, extra doors are raw `PoolManager.initialize` (Q31 / D65). | Locked |
| S34 | Product door PoolKeys unchanged vs today’s lib (dynamic fee, stored tick/sqrt, 0 → spacing 60 and tick-0 mid). | Locked |
| S36 | Creating a door does not mint LP, set \(R\), or move inventory. | Locked |

### 4.8 TestBase and scripts

| # | Decision | Status |
|---|----------|--------|
| S42 | Gold TestBase exposes `_ensureProductDoorsAndFinalize(hook)` and **calls it from `setUp`** after `deployVault`. The helper calls `deployPair` for each product unordered pair (`token0/1`, `token1/2`, `token0/2`) then `finalizeInitialization`. **Not** `PairPoolLib.ensureThreePairPools`. Existing swap/LP/fee/preview tests keep a ready instance. | Locked |
| S43 | At least one dedicated test (not only setUp): after `deployVault` **alone**, zero product doors are live, init selectors exist, production swap/LP selectors do **not**, `vaultConfig()` works, `isInitializationFinalized() == false`. Binding views (`token0`, `poolManager`, …) are unmatched. | Locked |
| S44 | Research fixture inherits TestBase `setUp` (already does) and therefore gets doors + finalize via S42. If it called `deployVault` itself, it must use the helper. | Locked |

### 4.9 Docs the later plan must patch

| Doc | Change |
|-----|--------|
| Refactor R30–R31 | Outcome = after staged flow + finalize, not after `postDeploy` |
| Product D8, D80, O6, Q51, §1 #8, factory user story | Staged doors + finalize; production ABI at finalize |
| TestBase / factory tests | S42–S43 |
| This family’s impl/test plan if it still says R31-A is done | Point here |

### 4.10 Engineering constraints

| # | Decision | Status |
|---|----------|--------|
| S37 | No `via_ir`. No `new` facets/DFPkg. Production-first tests; no mocks of hook, package, factory, PoolManager, fee oracle. | Locked |
| S38 | Default hermetic Foundry profile; fork = `FOUNDRY_PROFILE=fork`. No package-specific profile. Do not delete `out/` or `cache_forge/`. | Locked |

### 4.11 Q&A #3 locks (2026-08-17)

These supersede earlier rows where noted. Do not reopen without editing this PRD.

| # | Decision | Status |
|---|----------|--------|
| S47 | **Package is the init facet.** `UniswapV4OrbitalSwapHookDFPkg` **inherits** `UniswapV4OrbitalSwapHookInitFacet` (`InitTarget` + `IFacet`). Factory cuts `address(pkg)` / immutable `SELF`. InitFacet is **source only** — never CREATE3, never `PkgInit.initFacet`, never `FactoryService.deployInitFacet`. `InitTarget` does **not** inherit `UniswapV4OrbitalSwapHookTarget` (that would put production functions on the package bytecode). See S57 for the `facetInterfaces()` override. | Locked |
| S48 | **`facetCuts()` bootstrap set (exact order, confirmed).** `[0]` `MultiAssetBasicVaultFacet` Add + its `facetFuncs()`; `[1]` `MultiAssetStandardVaultFacet` Add + its `facetFuncs()`; `[2]` `address(this)` Add + `InitFacet.facetFuncs()`. The vault pair is **required** so `deployHookVault` can call `vaultConfig()` in the same tx (S3). Package-as-init is the only **init/product** facet in this list — not the only cut. “`facetCuts()` = package only” is an error and is **void**. Production hooks/liquidity/ERC20* are not in this list. Vault pair is **not** Removed at finalize. | Locked |
| S49 | **Superseded by S58.** Init selector set is the six shared functions. | Void |
| S50 | **No production-facet ABI edits.** Do not change `facetFuncs()` on hooks, liquidity, ERC20, ERC5267, ERC2612, or vault facets. Do not add door views to the hooks facet. Binding views appear only after finalize Adds the existing hooks facet. **Only allowed production-file edit:** extract today’s `beforeInitialize` body into a shared library; `HooksTarget.beforeInitialize` calls that library. Checks stay bit-identical to today (S35). | Locked |
| S51 | **Finalize cut construction.** Delegatecall runs package bytecode, so `HOOKS_FACET` etc. immutables are readable. Remove `address(SELF)` + `InitFacet.facetFuncs()`. Add `productionFacetCuts()`. Then `emit IDiamond.DiamondCut(cuts, address(0), "")` ( `_processFacetCuts` does **not** emit; factory `initAccount` emits after it — match that). Then `InitializationFinalized`. Then set `initializationFinalized`. No S40 Repo addresses. | Locked |
| S52 | **ERC165 as-built.** Leave `facetInterfaces()` as today’s `IERC20`, `IERC20Metadata`, `IERC20Permit`, `IERC5267`, `IBasicVault`, `IStandardVault`. Factory `initAccount` already does `ERC165Repo._registerInterfaces(config.interfaces)`. Do **not** register `IUniswapV4OrbitalSwapHookInit` or `IHooks` (Crane ERC165Repo cannot unregister). Finalize does **not** register or drop IDs. `IHooks` / `IUniswapV4OrbitalSwapHook` stay unregistered (current as-built). | Locked |
| S53 | **Door views die with package-as-init.** S17 “on both facets” is void. `IUniswapV4OrbitalSwapHookInit` declares the views; `IUniswapV4OrbitalSwapHook` does not. After finalize, reconstruct product keys via hooks-facet `token0/1/2` + `pairPoolTickSpacing` + `PairPoolLib.pairKey`. | Locked |
| S54 | **Errors / returns.** `finalizeInitialization` returns `true`. `InitializationAlreadyFinalized()`. `ProductDoorsNotLive()`. Do not reuse `NotLive`. `deployPair` skip-if-live returns the product `PoolKey` and emits nothing. | Locked |
| S55 | **Lib + layout.** Delete `PairPoolLib.ensureThreePairPools`. Keep `pairKey`, `initIfNeeded`, `isPoolLive`. §7 file names are **normative**. `PkgInit` field order **unchanged** (no new field). | Locked |
| S56 | Same as S12: `postDeploy(address) public returns (bool) { return true; }`. | Locked |
| S57 | **`facetInterfaces()` collision (confirmed).** `IFacet.facetInterfaces()` and `IDiamondFactoryPackage.facetInterfaces()` are the **same selector** (`0x2ea80826`). InitFacet **is** `IFacet`: `facetName()` = `type(UniswapV4OrbitalSwapHookInitFacet).name`; `facetFuncs()` = **S58** init-only list; InitFacet’s own `facetInterfaces()` **may** declare `IUniswapV4HookStagedPairInit` for the mixin. The **DFPkg overrides** `facetInterfaces()` to **today’s six IDs** (S52). `diamondConfig.interfaces` and `packageMetadata.interfaces` use the **override**. Do **not** diamond-cut `facetName` / `facetInterfaces` / `facetFuncs` / `facetMetadata` (already excluded by S58). Do **not** `Behavior_IFacet` the package as a CREATE3 facet; package declaration tests stay `Behavior_IDiamondFactoryPackage` plus an assert that `pkg.facetFuncs()` equals the S58 list. | Locked |
| S58 | **Shared door ABI (2026-08-17).** Every family Init implements `IUniswapV4HookStagedPairInit`: `deployPair(address,address)`, `finalizeInitialization`, `isPairPoolLive(address,address)`, `pairPoolKey(address,address)`, `isInitializationFinalized`, plus `IHooks.beforeInitialize` on the cut. Sort internally. No named `deployPairPool*`. No pairId. Init `facetFuncs()` is exactly those six selectors. | Locked |
| S59 | **Event.** `PairPoolDeployed(address indexed hook, address indexed currency0, address indexed currency1, bytes32 poolId)` with `currency0 < currency1`. Emit only on first init of that product key. | Locked |

**Factory behavior this lock depends on** (do not change the factory):

1. `initAccount` applies `factory.facetCuts()` then `pkg.diamondConfig().facetCuts`.
2. It registers `factory.facetInterfaces()` then `pkg.diamondConfig().interfaces`.
3. It `pkg._initAccount(pkgArgs)` (delegatecall adaptor — writes **proxy** storage).
4. `_deployAt` then calls `pkg.postDeploy(proxy)` (**direct** call on the package, not the proxy) then `IPostDeployAccountHook(proxy).postDeploy()` (freeze).
5. Registry then `vaultConfig()` on the proxy.

Package-as-init works because Solidity **immutables live in the package runtime bytecode**. A diamond delegatecall to the package still sees `HOOKS_FACET` / `SELF`. `address(this)` in that call is the **proxy**; Remove must use `address(SELF)`, not `address(this)`.

---

## 5. What this is not

1. A public `diamondCut` / owner upgrade window.  
2. A factory or registry rewrite (`deployHookVault` still needs `vaultConfig()` immediately).  
3. A salt / mineNonce / flags change.  
4. Deferring **vault** facets until finalize (registration would revert).  
4b. Putting **only** the package in `facetCuts()` and omitting `MultiAssetBasicVaultFacet` / `MultiAssetStandardVaultFacet` (S48 void).  
5. Deferring **`beforeInitialize`** until finalize (door `initialize` would revert).  
6. Staged init CODE for weighted / quad / SE Orbital.  
7. An implementation plan.  
8. A CREATE3-deployed InitFacet or a `PkgInit.initFacet` field.  
9. Editing production facet `facetFuncs()` or moving door views onto the hooks facet.

---

## 6. Security / abuse (later plan tests)

| Concern | Law |
|---------|-----|
| Caller-supplied cuts | Impossible — S22 |
| Double finalize | Revert — S21 |
| Finalize with missing doors | Revert — S20 |
| Swap / LP before finalize | Unmatched selector — S26 / S35b |
| V4 `modifyLiquidity` before finalize | Unmatched `beforeAddLiquidity` — revert |
| Init facet left forever | Allowed. Cannot add arbitrary facets (S9/S22). Instance has no swap/LP ABI until someone finalizes |
| Door via raw `PoolManager.initialize` | Counts for S20 if product PoolKey matches |
| Second init of a live door | Skip in `deployPair` — S58 |
| First-deployer-wins on unfinalized | Return existing — S25 |
| IERC20 claimed on ERC165 before finalize | Allowed — S52 (factory registers `facetInterfaces()` at deploy; IERC20 selectors still unmatched until finalize) |
| Stolen finalize | Anyone may finalize a fully-doored instance; they can only apply the hardcoded production cut — S19/S22 |

Adversarial: unmatched production selectors pre-finalize; Remove-then-Add `beforeInitialize` still validates after finalize; permissionless finalize race (one winner); J-surface after finalize (no leftover init selectors, no `diamondCut`).

---

## 7. Layout (normative — S55)

```text
contracts/hooks/uniswap/v4/orbital/
  interfaces/
    IUniswapV4OrbitalSwapHook.sol            # UNCHANGED (no door views)
    IUniswapV4OrbitalSwapHookInit.sol        # NEW — doors, finalize, door views, errors, events
    IUniswapV4OrbitalSwapHookPackage.sol     # + productionFacetCuts(); PkgInit UNCHANGED
  facets/
    UniswapV4OrbitalSwapHookInitFacet.sol    # NEW source — inherited by DFPkg; NOT CREATE3
    UniswapV4OrbitalSwapHookHooksFacet.sol   # production; facetFuncs UNCHANGED; added at finalize
    UniswapV4OrbitalSwapHookLiquidityFacet.sol
  UniswapV4OrbitalSwapHookInitTarget.sol     # NEW — doors, finalize, bootstrap beforeInitialize, views
  UniswapV4OrbitalSwapHookBeforeInitializeLib.sol  # NEW — shared checks; used by InitTarget + HooksTarget
  UniswapV4OrbitalSwapHookDFPkg.sol          # is InitFacet; facetCuts = vault pair + SELF
  UniswapV4OrbitalSwapHookPairPoolLib.sol    # delete ensureThreePairPools; keep pairKey/initIfNeeded/isPoolLive
  UniswapV4OrbitalSwapHookRepo.sol           # + initializationFinalized only (no facet addresses)
  UniswapV4OrbitalSwapHook_FactoryService.sol  # no deployInitFacet
  TestBase_UniswapV4OrbitalSwapHook.sol      # S42 helper uses public ABI
  THIS FILE
```

`UniswapV4OrbitalSwapHookDFPkg is UniswapV4OrbitalSwapHookInitFacet, IUniswapV4OrbitalSwapHookPackage`. `InitFacet.facetName()` **returns** `type(UniswapV4OrbitalSwapHookInitFacet).name`. `packageName()` stays `type(UniswapV4OrbitalSwapHookDFPkg).name`.

---

## 8. Target user story

```text
mineNonce = premine(requiredHookFlags())
hook = pkg.deployVault(args, mineNonce)
  → registered vault
  → vaultConfig() works
  → no product doors
  → no swap / addLiquidity / token0 / poolManager selectors
  → isInitializationFinalized() == false

IUniswapV4HookStagedPairInit(hook).deployPair(token0, token1)
IUniswapV4HookStagedPairInit(hook).deployPair(token1, token2)
IUniswapV4HookStagedPairInit(hook).deployPair(token0, token2)

IUniswapV4OrbitalSwapHookInit(hook).finalizeInitialization()
  → production ABI live (including token0 / poolManager)
  → init selectors unmatched (including isInitializationFinalized)
  → DiamondCut + InitializationFinalized

addLiquidity / V4 swap as product PRD
```

---

## 9. Supersession

| Old law | New law |
|---------|---------|
| R30: all three doors after deploy flow / `postDeploy` | Doors after three `deployPair` calls; production ABI after finalize |
| R31-A: `pkg.postDeploy` inits three pools | S12: `postDeploy` inits **zero** |
| D80 / Q51 / D8: same-tx all three | Staged instance calls; same PoolKeys |
| Implicit: full production ABI at CREATE2 | S7 / S10: production ABI at finalize |
| Product user story factory.deploy → init all three | §8 |
| v0.3 S27 / S30 CREATE3 InitFacet + `PkgInit.initFacet` | S47: package inherits InitFacet |
| v0.3 S17 / S33 door views on hooks + `IUniswapV4OrbitalSwapHook` | S53: Init interface only; gone after finalize |
| v0.3 S40 Repo facet addresses | S51: package immutables |
| v0.3 S41 withhold IERC20 ERC165 at deploy | S52: leave `facetInterfaces()` as-is |
| Q&A #3 draft: `facetCuts()` = package only | **Void.** S48: vault declaration pair + package-as-init |
| Naive InitFacet `facetInterfaces()` = Init ID only | S57: DFPkg overrides to today’s six IDs |

R32–R34 (tick/sqrt not in salt; idempotent skip; registry discovery) **stay**.

---

## 10. Open items

**None.** Q&A #4 locked S57 (`IFacet` inherit + package `facetInterfaces()` override). No further requirement questions.

Ready for an implementation plan when this v0.4.2 is accepted.

---

## 11. Definition of Done (later plan)

1. `deployVault` leaves a registered vault with `vaultConfig()`, package-as-init selectors, **no** product doors, **no** swap/LP/`token0` selectors. Loupe includes `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` + package-as-init. ERC165 matches today’s `facetInterfaces()` (IERC20 claimed, selectors unmatched).  
2. Each `deployPair` of a product pair creates that door (or skips if live); `beforeInitialize` on package-as-init enforces today’s checks via the shared library.  
3. Finalize reverts `ProductDoorsNotLive` if any product door is missing; succeeds once (`true`); Removes `address(SELF)` init selectors; Adds `productionFacetCuts()`; emits `DiamondCut` + `InitializationFinalized`; does **not** touch ERC165; `beforeInitialize` still correct on the hooks facet.  
4. After finalize, init-only selectors are unmatched; swap/LP/`token0` work per product PRD. Vault pair still on the diamond. Hooks/liquidity `facetFuncs()` unchanged vs today.  
4b. New door emits `PairPoolDeployed` once; skip-if-live emits nothing.  
5. No public `diamondCut` selector before or after finalize.  
6. TestBase `setUp` uses S42 public ABI; S43 has an explicit doorless-deploy test.  
7. Research fixture and any other in-repo caller of this package compile and follow the staged flow.  
8. Docs in §4.9 no longer claim same-tx all-three init or full ABI at CREATE2.  
9. No `via_ir`; no `new` facets/DFPkg; no CREATE3 InitFacet.

Fork DoD from the product PRD is unchanged and not expanded here.

---

## 12. Revision history

| Ver | Date | Notes |
|-----|------|--------|
| 0.1 | 2026-08-17 | First draft: production facets at CREATE2; finalize remove-only. |
| 0.2 | 2026-08-17 | Q&A: finalize **Adds** production facets; names `deployPairPool01/12/02`; finalize requires all three doors; TestBase helper in `setUp`; change set includes breaking in-repo callers. Vault facets + init `beforeInitialize` stay on the bootstrap diamond (registry + V4 flags). |
| 0.3 | 2026-08-17 | Q&A #2: `PairPoolDeployed` + `InitializationFinalized`; `facetCuts()` bootstrap vs `productionFacetCuts()`; grep-and-fix callers only. S21: flag after successful cut. |
| 0.4 | 2026-08-17 | Q&A #3: package **is** the init facet (inherit InitFacet, cut `SELF`); no CREATE3 InitFacet; no production-facet ABI edits; ERC165 left as factory-registered `facetInterfaces()`; door views die with package-as-init; `pairPoolKey*` always returns the product key; `ProductDoorsNotLive` / `InitializationAlreadyFinalized`; delete `ensureThreePairPools`. |
| 0.4.1 | 2026-08-17 | Confirmed S48: `facetCuts()` is vault declaration pair + package-as-init. “Package only” is void. Registry `vaultConfig()` still requires `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` on the bootstrap diamond; they survive finalize. |
| 0.4.2 | 2026-08-17 | Q&A #4: InitFacet is `IFacet`; DFPkg **overrides** `facetInterfaces()` to today’s six IDs (S57). Same selector as `IDiamondFactoryPackage.facetInterfaces` (`0x2ea80826`). |
| 0.5 | 2026-08-17 | Shared door ABI for all V4 hook families: `deployPair(address,address)`. S13/S14/S18/S33/S45/S49 void. S58/S59. Named `deployPairPool*` and pairId removed. CODE in this worktree must be amended. |
