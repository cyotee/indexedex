# Implementation & Test Plan: Orbital Hook Staged Pair-Door Initialization

**PRD (normative):** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) (**v0.5**)  
**This plan (implementor SoT once accepted):** phases, file map, algorithms, exact cuts, exact tests.  
**v0.5 note:** Diamond shape from the already-landed CODE stays. Next CODE in this worktree is the shared `deployPair(address,address)` ABI (S58/S59). Named `deployPairPool*` and pairId are void.  
**Product PRD:** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_PRD.md) — sphere / LP / fees / Permit2. Door timing superseded by staged PRD.  
**Refactor PRD:** [`UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_ORBITAL_SWAP_HOOK_HOOK_FACTORY_REFACTOR_PRD.md) — CREATE2 / salt / flags. R30–R31 superseded.  
**Date:** 2026-08-17  
**Status:** **Draft** — no CODE until this plan is accepted.

**Authority**

| Layer | Role |
|-------|------|
| **Staged PRD v0.5** | Product law for bootstrap vs production cuts, doors, finalize, `postDeploy`, callers. **PRD wins** on conflict. S13/S14/S18/S33/S45/S49 void; S58/S59 locked |
| **This plan** | Implementor SoT for phases, files, function bodies, test names, cut order |
| Hook factory PRD | Unchanged. F33: no public `diamondCut`. Finalize uses `ERC2535Repo._processFacetCuts` only |
| Skills | `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages`, `indexedex-adversarial-testing` (J-surface) |

**Process rule:** Do not reopen PRD-locked decisions (S1–S57) without a PRD revision. After each phase: compile green and that phase’s tests green before the next. **No `via_ir`.** **No `new` facets/DFPkg.** Default hermetic `forge test` (S38) — **not** `FOUNDRY_PROFILE=orbital`. Fork = `FOUNDRY_PROFILE=fork`. Forge patience: first compile may take 20–40+ minutes; do not kill.

---

## 0. One-line goal

Keep the landed bootstrap / finalize diamond. Replace named `deployPairPool01/12/02` with shared `IUniswapV4HookStagedPairInit.deployPair(address,address)`. Product doors remain the three Orbital unordered pairs.

---

## 1. Locked implementor decisions

These are **not** open. They restate PRD S* as plan law.

| # | Law |
|---|-----|
| **I1** | Package **is** the init facet: `DFPkg is InitFacet is InitTarget, IFacet`. No CREATE3 InitFacet. No `PkgInit.initFacet`. No `FactoryService.deployInitFacet`. |
| **I2** | `InitTarget` does **not** inherit `UniswapV4OrbitalSwapHookTarget`. |
| **I3** | `facetCuts()` exact order: `[0]` MultiAssetBasicVaultFacet Add + its `facetFuncs()`; `[1]` MultiAssetStandardVaultFacet Add + its `facetFuncs()`; `[2]` `address(SELF)` Add + `facetFuncs()` (S58). |
| **I4** | `productionFacetCuts()` exact Add order: `[0]` hooks; `[1]` liquidity; `[2]` ERC20; `[3]` ERC5267; `[4]` ERC2612. Each uses that immutable + that facet’s live `facetFuncs()`. |
| **I5** | S58 selectors **only** on cut `[2]`. Never cut DFPkg functions, IFacet metadata, binding views, LP, or vault selectors onto the package-as-init cut. |
| **I6** | DFPkg **overrides** `facetInterfaces()` to today’s six IDs (S52 / S57). `diamondConfig.interfaces` = that override. |
| **I7** | `finalizeInitialization` **body lives on DFPkg** (needs `SELF` + immutables). InitTarget does not implement it. InitFacet still **lists** the selector. |
| **I8** | Finalize Remove uses `address(SELF)` + inherited `facetFuncs()` via **internal** call. Never `address(this)` as the Remove facet (proxy). Never `IFacet(address(this)).facetFuncs()` (selector not on the diamond). |
| **I9** | `postDeploy(address) public returns (bool) { return true; }`. Not `pure`. Delete `PairPoolLib.ensureThreePairPools`. |
| **I10** | Shared `UniswapV4OrbitalSwapHookBeforeInitializeLib` holds today’s checks only. HooksTarget `beforeInitialize` becomes a lib call. `facetFuncs()` of hooks/liquidity/ERC20/vault **unchanged**. |
| **I11** | Door views exist only on `IUniswapV4HookStagedPairInit` (Orbital Init may be a thin `is` alias). Not added to `IUniswapV4OrbitalSwapHook` or the hooks facet. |
| **I12** | TestBase `setUp` calls `_ensureProductDoorsAndFinalize(hook)` after `deployVault`. Helper calls `deployPair(token0,token1)`, `deployPair(token1,token2)`, `deployPair(token0,token2)`, then `finalizeInitialization`. |
| **I13** | Grep-and-fix this package’s `deployVault` / `deployVaultAutoMine` / `PkgFactory.deployHook` callers in-repo. **Do not** touch SE Orbital, frontend, or unrelated Anvil scripts unless that grep hits them. |
| **I14** | Do **not** `Behavior_IFacet` the package as a CREATE3 facet. Package declaration stays `Behavior_IDiamondFactoryPackage` + assert `pkg.facetFuncs()` == S58 list (6 selectors). |
| **I15** | Add `contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol`. Later families inherit it. Delete named `deployPairPool*` / numbered views from Orbital Init. Event is S59 (sorted currency0/currency1 + poolId). |

---

## 2. File map

### 2.1 New files

```text
contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol   # NEW shared (v0.5)
contracts/hooks/uniswap/v4/orbital/
  interfaces/IUniswapV4OrbitalSwapHookInit.sol   # thin `is IUniswapV4HookStagedPairInit` alias
  UniswapV4OrbitalSwapHookBeforeInitializeLib.sol
  UniswapV4OrbitalSwapHookInitTarget.sol
  facets/UniswapV4OrbitalSwapHookInitFacet.sol
  THIS FILE
```

### 2.2 Edit files

```text
contracts/hooks/uniswap/v4/orbital/
  interfaces/IUniswapV4OrbitalSwapHookPackage.sol   # + productionFacetCuts(); PkgInit UNCHANGED
  interfaces/IUniswapV4OrbitalSwapHook.sol          # UNCHANGED
  UniswapV4OrbitalSwapHookRepo.sol                  # + initializationFinalized at end of Layout
  UniswapV4OrbitalSwapHookPairPoolLib.sol           # delete ensureThreePairPools
  UniswapV4OrbitalSwapHookTarget.sol                # beforeInitialize → lib only
  UniswapV4OrbitalSwapHookDFPkg.sol                 # inherit InitFacet; bootstrap cuts; finalize body; postDeploy no-op
  UniswapV4OrbitalSwapHook_FactoryService.sol       # no deployInitFacet (no change unless comments)
  TestBase_UniswapV4OrbitalSwapHook.sol             # S42 helper
  facets/UniswapV4OrbitalSwapHookHooksFacet.sol     # facetFuncs UNCHANGED
  facets/UniswapV4OrbitalSwapHookLiquidityFacet.sol # UNCHANGED

test/foundry/spec/hooks/uniswap/v4/orbital/
  TestBase_UniswapV4OrbitalSwapHook.sol             # re-export only — no logic
  UniswapV4OrbitalSwapHook_Factory.t.sol            # F2 no longer means postDeploy inits doors
  UniswapV4OrbitalSwapHook_StagedInit.t.sol         # NEW — S43 + finalize matrix
  UniswapV4OrbitalSwapHook_Reentrancy.t.sol         # own deployHook must finalize
  UniswapV4OrbitalSwapHook_Adversarial.t.sol        # unmatched pre-finalize; J after finalize
  UniswapV4OrbitalSwapHook_Deploy.t.sol             # still valid after S42 finalize
```

### 2.3 Docs this change set must patch (PRD §4.9)

| Doc | Change |
|-----|--------|
| Refactor PRD R30–R31 | Outcome = after staged flow + finalize, not after `postDeploy` |
| Refactor impl plan “postDeploy ensures three doors” | Point at staged PRD + this plan |
| Product PRD D8, D80, O6, Q51, §1 #8, factory user story | Staged doors + finalize; production ABI at finalize |
| Product impl plan item 3 / factory always inits three | Point here |
| This family’s factory impl plan if it still says R31-A is done | Point here |

### 2.4 Known grep hits (S1b) — fix in this change set

| Path | What to do |
|------|------------|
| `TestBase_UniswapV4OrbitalSwapHook.sol` (co-located gold) | S42 helper after `deployHook` |
| `test/foundry/spec/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_Factory.t.sol` | Rewrite `test_F2_*` (see §7) |
| `test/foundry/spec/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_Reentrancy.t.sol` | After its own `deployHook`, call `_ensureProductDoorsAndFinalize` |
| `scripts/foundry/research/uniswapV4/hooks/orbital/ResearchFixture_OrbitalHook.sol` | Already calls gold `setUp()` via `bootstrapResearch()` — gets S42 for free. Confirm; do not re-implement doors. |
| Any additional `UniswapV4OrbitalSwapHookDFPkg` / this package `deployVault` / `deployVaultAutoMine` / `PkgFactory.deployHook` hit the implementor finds | Same rule: after deploy, either stay bootstrap (only if the test is about bootstrap) or call the helper before swap/LP/`token0` |

**Out of grep scope unless the grep hits them:** SE Orbital (`standardExchange/orbital/`), frontend, Anvil scripts, weighted / quad.

---

## 3. Exact ABIs

### 3.1 `IUniswapV4HookStagedPairInit` (shared, v0.5)

```solidity
interface IUniswapV4HookStagedPairInit {
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
}
```

`IUniswapV4OrbitalSwapHookInit` is a thin `is IUniswapV4HookStagedPairInit` alias (no extra functions).  
`currency0 < currency1`. `poolId` = `PoolId.unwrap(key.toId())`. `hook` topic = `address(this)` under delegatecall.  
Do **not** add these views to `IUniswapV4OrbitalSwapHook`.

### 3.2 `IUniswapV4OrbitalSwapHookPackage` additions

`PkgInit` / `PkgArgs` **unchanged** (field order unchanged).

Add:

```solidity
function productionFacetCuts() external view returns (IDiamond.FacetCut[] memory);
```

Import `IDiamond`. Existing `HOOKS_FACET()` / `LIQUIDITY_FACET()` stay. Do not add `INIT_FACET()` (the package is the init facet).

### 3.3 S58 selector set (InitFacet.`facetFuncs()`, exact order)

```text
[0]  IHooks.beforeInitialize
[1]  IUniswapV4HookStagedPairInit.deployPair
[2]  IUniswapV4HookStagedPairInit.finalizeInitialization
[3]  IUniswapV4HookStagedPairInit.isPairPoolLive
[4]  IUniswapV4HookStagedPairInit.pairPoolKey
[5]  IUniswapV4HookStagedPairInit.isInitializationFinalized
```

6 selectors. No more. No named `deployPairPool*`.

### 3.4 `facetAddresses()` exact order (8)

```text
[0] MULTI_ASSET_BASIC_VAULT_FACET
[1] MULTI_ASSET_STANDARD_VAULT_FACET
[2] address(SELF)          // package-as-init
[3] HOOKS_FACET
[4] LIQUIDITY_FACET
[5] ERC20_FACET
[6] ERC5267_FACET
[7] ERC2612_FACET
```

---

## 4. Algorithms (normative)

### 4.1 Product PoolKey (shared; no second builder)

Use `PairPoolLib.pairKey` + Repo process args (S34):

```text
spacing = layout.tickSpacing == 0 ? int24(60) : layout.tickSpacing
price    = layout.sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : layout.sqrtPriceX96

key01 = pairKey(token0, token1, spacing, IHooks(address(this)))
key12 = pairKey(token1, token2, spacing, IHooks(address(this)))
key02 = pairKey(token0, token2, spacing, IHooks(address(this)))
```

`pairPoolKey(a,b)` sorts, requires a product pair (any two distinct bound tokens), always returns that constructed key (even if not live).  
`isPairPoolLive(a,b)` = `PairPoolLib.isPoolLive` on that key.

### 4.2 `deployPair` (S58)

```text
if tokenA == 0 or tokenB == 0 or tokenA == tokenB: revert InvalidPoolToken
(c0, c1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA)
if not both bound: revert InvalidPoolToken
key = pairKey(c0, c1, spacing, IHooks(address(this)))
price = (same 0 → tick-0 mid rule as 4.1)
wasLive = PairPoolLib.isPoolLive(pm, key)
PairPoolLib.initIfNeeded(pm, key, price)
if (!wasLive) emit PairPoolDeployed(address(this), c0, c1, PoolId.unwrap(key.toId()))
return key
```

No bulk ensure. Permissionless. `(a,b)` and `(b,a)` are the same door.

### 4.3 `finalizeInitialization` (DFPkg body)

```text
nonReentrant
if (layout.initializationFinalized) revert InitializationAlreadyFinalized()
if (!live01 || !live12 || !live02) revert ProductDoorsNotLive()   // exact product keys

cuts = new FacetCut[](6)
cuts[0] = Remove { facetAddress: address(SELF), functionSelectors: facetFuncs() }  // internal call
adds    = productionFacetCuts()   // internal call; 5 Adds
cuts[1..5] = adds[0..4]

ERC2535Repo._processFacetCuts(cuts)          // does NOT emit
emit IDiamond.DiamondCut(cuts, address(0), "")
emit InitializationFinalized(address(this))
layout.initializationFinalized = true        // AFTER successful cut
return true
```

Do **not** call `ERC165Repo._registerInterfaces` (already done at deploy — S52).  
Do **not** Remove vault pair.  
Do **not** use `Replace`.

Second call: `InitializationAlreadyFinalized()` (flag already true; init selectors unmatched after first success, so a second call is unmatched unless something went wrong — still set the flag for the in-function reentry case; `nonReentrant` blocks mid-cut reentry).

### 4.4 `beforeInitialize` (shared lib)

Bit-identical to today’s Target body:

```text
if (msg.sender != Repo._layout().poolManager) revert Target.NotPoolManager()
a = unwrap(currency0); b = unwrap(currency1)
if (!_isBound(a) || !_isBound(b) || a == b) revert Target.InvalidPoolToken()
if (poolKey.fee != DYNAMIC_FEE_FLAG) revert Target.InvalidPoolFee()
return IHooks.beforeInitialize.selector
```

`_isBound` = token is `token0` or `token1` or `token2` in Repo.  
**Do not** add `hooks == address(this)`.  
Lib imports `UniswapV4OrbitalSwapHookTarget` **only** for those three error types — does **not** inherit Target.

`InitTarget.beforeInitialize` and `HooksTarget.beforeInitialize` both call the lib and return the selector.

### 4.5 Repo

Append **one** field at the **end** of `Layout` (after `reentrancyStatus`):

```solidity
bool initializationFinalized;
```

Do **not** insert in the middle (slot shift). Do **not** store facet addresses.  
`_initializeBindings` does not set the flag (defaults `false`).  
Getter: `Repo._layout().initializationFinalized`.

### 4.6 `nonReentrant` on InitTarget

Copy the existing Target modifier onto `InitTarget` (same `Repo.ENTERED` / `NOT_ENTERED` / `Reentrancy()` error). Declare `error Reentrancy()` on InitTarget **or** revert `UniswapV4OrbitalSwapHookTarget.Reentrancy()` — use **`UniswapV4OrbitalSwapHookTarget.Reentrancy()`** so the selector matches product LP/swap. DFPkg.`finalizeInitialization` applies this modifier.

### 4.7 Package views

| Function | Returns |
|----------|---------|
| `facetCuts()` | I3 (3 Adds) |
| `productionFacetCuts()` | I4 (5 Adds) |
| `facetInterfaces()` | **override** — `IERC20`, `IERC20Metadata`, `IERC20Permit`, `IERC5267`, `IBasicVault`, `IStandardVault` (same order as today) |
| `InitFacet.facetInterfaces()` | `type(IUniswapV4OrbitalSwapHookInit).interfaceId` only — **hidden by DFPkg override** |
| `facetName()` | `type(UniswapV4OrbitalSwapHookInitFacet).name` |
| `packageName()` | `type(UniswapV4OrbitalSwapHookDFPkg).name` |
| `diamondConfig()` | `{facetCuts: facetCuts(), interfaces: facetInterfaces()}` |
| `postDeploy(address)` | `return true` |
| `facetFuncs()` | S49 list (inherited) |

`calcSalt` / `processArgs` / `initAccount` storage writes / `deployVault` arity / `PRODUCT_ID` / `requiredHookFlags` / `isExpectedInstance` **unchanged**.

### 4.8 Inheritance

```text
UniswapV4OrbitalSwapHookInitTarget
  └── UniswapV4OrbitalSwapHookInitFacet is InitTarget, IFacet
        └── UniswapV4OrbitalSwapHookDFPkg is InitFacet, IUniswapV4OrbitalSwapHookPackage
```

`DFPkg` implements `finalizeInitialization` (I7).  
`DFPkg` overrides `facetInterfaces()` (I6).

---

## 5. Phases

Do not start phase N+1 until phase N compile + that phase’s tests are green.

### Phase A — Storage, lib, interfaces (no diamond shape change yet)

1. Append `initializationFinalized` to Repo `Layout`.  
2. Add `IUniswapV4OrbitalSwapHookInit`.  
3. Add `productionFacetCuts()` to the package interface (implement a temporary stub on DFPkg that still matches **today’s** seven production Adds if needed to compile — **or** implement the final I4 list immediately and land Phase C in the same compile). Prefer **A+B+C in one compile** if the package will not compile half-cut.  
4. Write `BeforeInitializeLib`.  
5. Point `HooksTarget.beforeInitialize` at the lib. Hooks `facetFuncs()` unchanged.

**Exit:** `forge build` green. Existing tests still pass if C is not landed yet. If A–C ship together, skip the stub.

### Phase B — InitTarget + InitFacet (source only)

1. `InitTarget`: doors (§4.2), views (§4.1), `beforeInitialize` → lib, `nonReentrant` modifier, **no** `finalizeInitialization` body.  
2. `InitFacet`: `facetName`, `facetInterfaces` (Init ID only), `facetFuncs` (S49), `facetMetadata`.  
3. Do **not** CREATE3-deploy InitFacet. Do **not** add FactoryService helper.

**Exit:** files exist; package does not inherit yet until C.

### Phase C — DFPkg shape + finalize

1. `contract UniswapV4OrbitalSwapHookDFPkg is UniswapV4OrbitalSwapHookInitFacet, IUniswapV4OrbitalSwapHookPackage`.  
2. Override `facetInterfaces()` to six IDs.  
3. Replace `facetCuts()` / `facetAddresses()` / `diamondConfig` per §3–§4.  
4. Implement `productionFacetCuts()` (I4).  
5. Implement `finalizeInitialization` on DFPkg (§4.3).  
6. `postDeploy` → `return true`.  
7. Delete `PairPoolLib.ensureThreePairPools`.  
8. Constructor / `PkgInit` / immutables **unchanged**.

**Exit:** package compiles. Existing TestBase will fail until Phase D (doors no longer appear in `deployVault`).

### Phase D — TestBase + grep-and-fix

1. Gold TestBase: after `deployHook`, call `_ensureProductDoorsAndFinalize(hook)`.  
2. Helper (exact name):

```solidity
function _ensureProductDoorsAndFinalize(address hook_) internal {
    IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
    init.deployPair(address(token0), address(token1));
    init.deployPair(address(token1), address(token2));
    init.deployPair(address(token0), address(token2));
    bool ok = init.finalizeInitialization();
    require(ok, "finalize");
}
```

3. Keep constructing `poolKey01/12/02` via `PairPoolLib.pairKey` (no `initialize`).  
4. Rename `_assertThreePoolsLiveFromPostDeploy` → `_assertThreeProductDoorsLive` (same body).  
5. Add `_deployBootstrapOnly(PkgArgs)` for S43 tests: `PkgFactory.deployHook` **without** the helper.  
6. Fix Reentrancy spec’s own `deployHook`.  
7. Confirm ResearchFixture `bootstrapResearch()` → gold `setUp()` (S42).  
8. Grep again; fix every additional hit (I13).

**Exit:** existing swap / LP / fee / preview / Permit2 / Deploy immutables tests pass via S42.

### Phase E — Staged + factory + adversarial tests

Add/rewrite tests in §7. **Exit:** that suite green on default profile.

### Phase F — Docs

Patch §2.3 docs so none claim same-tx all-three init or full ABI at CREATE2. Point R31-A at this plan.

---

## 6. TestBase law

Ladder unchanged: `CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → gold orbital TestBase.

`setUp` order after `deployHook`:

```text
hook = PkgFactory.deployHook(...)
_ensureProductDoorsAndFinalize(hook)
orbital = IUniswapV4OrbitalSwapHook(hook)
// then pairKey construction, router, mint, approve
```

Production-first: real package, real hook factory, real registry `deployHookVault`, real PoolManager. No mocks of those SUTs.

---

## 7. Tests (exact names)

Hermetic, default profile. New spec file unless noted.

### 7.1 Package declaration (extend existing Factory spec or new `UniswapV4OrbitalSwapHook_PackageDecl.t.sol`)

| Test | Assert |
|------|--------|
| `test_facetCuts_isBootstrapOnly` | `facetCuts().length == 3`; `[0]` basic vault; `[1]` standard vault; `[2]` `address(hookPkg)`; actions all Add; `[2].functionSelectors` == S49 list |
| `test_productionFacetCuts_fiveAdds` | length 5; addresses = hooks, liquidity, ERC20, ERC5267, ERC2612; each `functionSelectors` equals that facet’s `facetFuncs()` |
| `test_facetCuts_ne_productionFacetCuts` | not equal (S46) |
| `test_facetInterfaces_sixProductionIds` | exact today’s six IDs / order |
| `test_facetAddresses_eight` | §3.4 |
| `test_facetFuncs_isS49` | `hookPkg.facetFuncs()` == §3.3 |
| `test_facetName_isInitFacetType` | `type(UniswapV4OrbitalSwapHookInitFacet).name` |
| `test_packageName_unchanged` | `type(UniswapV4OrbitalSwapHookDFPkg).name` |
| `test_postDeploy_returnsTrue_noInit` | `hookPkg.postDeploy(address(0x1)) == true` (direct call; no PoolManager needed) |
| `test_calcSalt_unchanged` | keep F6 |

Use `Behavior_IDiamondFactoryPackage` for package metadata where the existing suite already does. **No** `Behavior_IFacet` against the package as a CREATE3 facet.

### 7.2 Bootstrap after `deployVault` alone (S43) — `UniswapV4OrbitalSwapHook_StagedInit.t.sol`

Use `_deployBootstrapOnly` (new tokens so it is not the setUp hook).

| Test | Assert |
|------|--------|
| `test_S43_deployAlone_noProductDoors` | `isPairPoolLive(t0,t1/t1,t2/t0,t2) == false`; `isInitializationFinalized() == false` |
| `test_S43_deployAlone_vaultConfigWorks` | `IStandardVault(h).vaultConfig()` succeeds; registry `isVault(h)` |
| `test_S43_deployAlone_initSelectorsExist` | loupe `facetAddress(deployPair) == address(hookPkg)`; same for finalize + `beforeInitialize` |
| `test_S43_deployAlone_productionSelectorsUnmatched` | loupe `facetAddress(addLiquidity) == 0`; `token0` == 0; `transfer` == 0; `beforeSwap` == 0 |
| `test_S43_deployAlone_erc165_claimsIERC20` | `supportsInterface(IERC20) == true` (S52) while `transfer` unmatched |
| `test_S43_pairPoolKey_alwaysConstructed` | `pairPoolKey(t0,t1)` equals `PairPoolLib.pairKey(...)` while not live; `pairPoolKey(t1,t0)` same key |
| `test_deployPair_emitsOnce` | `vm.expectEmit` `PairPoolDeployed(h, c0, c1, poolId)` sorted; live after |
| `test_deployPair_skipIfLive_noEvent` | second call (either arg order) returns same key; `recordLogs` has no `PairPoolDeployed` |
| `test_deployPair_orderIndependent` | open the three product pairs in any call order; all live |
| `test_finalize_revertsMissingDoors` | 0 doors and 2 doors → `ProductDoorsNotLive` |
| `test_finalize_success_returnsTrue` | after three doors; `true`; `InitializationFinalized`; `DiamondCut` |
| `test_finalize_removesInit_addsProduction` | after: `facetAddress(deployPair) == 0`; `facetAddress(finalizeInitialization) == 0`; `facetAddress(isInitializationFinalized) == 0`; `facetAddress(addLiquidity) == LIQUIDITY_FACET`; `facetAddress(token0) == HOOKS_FACET`; `facetAddress(beforeInitialize) == HOOKS_FACET`; vault pair still present |
| `test_finalize_secondCallUnmatchedOrAlreadyFinalized` | after success, `finalizeInitialization` unmatched (selector gone). Also unit-test the error by calling twice in one function **before** the cut would remove — not possible after success. Rely on unmatched + `nonReentrant` test. |
| `test_finalize_rawInitializeCounts` | `pm.initialize(productKey01/12/02)` then `finalize` succeeds; no `PairPoolDeployed` from raw path |
| `test_finalize_extraTickSpacingDoesNotCount` | initialize same pair different spacing; product door still not live; finalize reverts `ProductDoorsNotLive` |
| `test_permissionless_strangerMayDoorAndFinalize` | `vm.prank(stranger)` doors + finalize |
| `test_noDiamondCutSelector_beforeAndAfter` | keep F7 on bootstrap **and** finalized instances |
| `test_firstDeployerWins_unfinalized` | second `deployHook` same args returns same bootstrap address (S25) |

### 7.3 Factory spec rewrites

| Old | New |
|-----|-----|
| `test_F2_threePoolsInitialized` claims postDeploy | Keep `test_F2_setUpLeavesThreeDoorsAndFinalized`. Assert `_assertThreeProductDoorsLive()` **and** `facetAddress(addLiquidity) != 0` **and** `facetAddress(deployPair) == 0`. Comment: doors come from S42, not `postDeploy`. |
| F1, F3–F8 | Keep. F4/F5 extra `deployHook` instances stay bootstrap-only (they must **not** call `token0()`). |

### 7.4 Surface / adversarial (extend `UniswapV4OrbitalSwapHook_Adversarial.t.sol` or staged spec)

| Test | Assert |
|------|--------|
| `test_J_swapBeforeFinalize_unmatched` | bootstrap hook: `beforeSwap` loupe 0; router swap reverts |
| `test_J_addLiquidityBeforeFinalize_unmatched` | `addLiquidity` unmatched |
| `test_J_modifyLiquidityBeforeFinalize` | V4 `modifyLiquidity` unmatched `beforeAddLiquidity` |
| `test_J_afterFinalize_noInitSelectors` | S49 init-only selectors (except `beforeInitialize`) unmatched |
| `test_J_afterFinalize_noDiamondCut` | same as F7 |
| `test_beforeInitialize_sameChecks_afterFinalize` | bad fee / unbound pair still revert `InvalidPoolFee` / `InvalidPoolToken` on hooks facet |
| `test_permissionlessFinalizeRace` | two pranks; one succeeds; second unmatched |

Existing donation / reentrancy / Permit2 adversarial tests keep using setUp’s finalized instance.

### 7.5 Existing product tests

`*_Liquidity`, `*_Swap`, `*_Fees`, `*_Preview`, `*_Permit2`, `*_Decimals`, `*_Deploy` (`token0` / LP metadata): no logic change if S42 is in `setUp`. They must stay green.

### 7.6 Fork

Product-PRD fork DoD is **not** expanded. If a fork TestBase deploys this package, apply I13 (helper after deploy). Do not add new fork scenarios in this change set.

---

## 8. Anti-patterns (fail the review)

- CREATE3 or `new` InitFacet / DFPkg / production facets.  
- `PkgInit.initFacet` field.  
- `facetCuts()` = package only (omitting vault pair).  
- Putting `token0` / `addLiquidity` / DFPkg functions on the init cut.  
- Adding door views to the hooks facet or `IUniswapV4OrbitalSwapHook`.  
- Changing hooks/liquidity/ERC20/vault `facetFuncs()`.  
- Finalize using `address(this)` as the Remove facet address.  
- Setting `initializationFinalized` before the cut.  
- Re-registering or inventing ERC165 unregister.  
- Keeping `ensureThreePairPools`.  
- `postDeploy` still initializing pools.  
- TestBase setUp that uses `PairPoolLib.ensureThreePairPools` instead of the public ABI.  
- `Behavior_IFacet` on the package as if it were a CREATE3 facet.  
- `FOUNDRY_PROFILE=orbital` / `via_ir`.  
- Touching SE Orbital because it “looks similar.”  
- Mocking hook, package, factory, PoolManager, registry, or fee oracle.

---

## 9. Definition of Done (this plan)

Matches staged PRD §11, with plan-level extras:

1. `deployVault` → registered vault, `vaultConfig()` works, loupe = factory base (no PostDeploy) + vault pair + package-as-init, zero product doors, no swap/LP/`token0`, ERC165 still claims IERC20.  
2. Each `deployPair` of a product pair inits or skips; `PairPoolDeployed` only on new; `beforeInitialize` on package-as-init uses the lib.  
3. Finalize: `ProductDoorsNotLive` / success `true` / Remove SELF / Add `productionFacetCuts()` / `DiamondCut` + `InitializationFinalized` / no ERC165 mutation / vault pair remains.  
4. After finalize: init-only selectors unmatched; production ABI + `beforeInitialize` on hooks facet; hooks `facetFuncs()` unchanged vs HEAD before this change.  
5. No public `diamondCut` before or after.  
6. TestBase S42 + S43 spec + Reentrancy + ResearchFixture + grep-clean.  
7. §2.3 docs patched.  
8. No `via_ir`; no `new` facets/DFPkg; default hermetic profile.

---

## 10. Suggested implementor read order

1. Staged PRD §0–§2, §4.2 lifecycle, §4.11 (S47–S57), §8 user story.  
2. This plan §1, §3, §4.  
3. Factory `initAccount` / `_deployAt` (do not edit).  
4. Current `UniswapV4OrbitalSwapHookDFPkg.facetCuts` / `postDeploy` / `TestBase.setUp`.  
5. Phase A → F.

---

## 11. Revision history

| Ver | Date | Notes |
|-----|------|--------|
| 0.1 | 2026-08-17 | First plan for staged PRD v0.4.2. Package-as-init; vault pair stays; `facetInterfaces` override; finalize body on DFPkg. |
