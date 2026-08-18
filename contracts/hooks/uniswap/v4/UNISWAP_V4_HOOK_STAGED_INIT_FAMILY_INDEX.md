# Uniswap V4 hook staged init — family index

**Date:** 2026-08-17  
**Status:** Router for per-family staged-init PRDs. Not a product PRD.  
**Gold diamond shape:** [`orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](./orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2 (bootstrap / finalize / package-as-init).  
**Shared door ABI (2026-08-17 lock):** `deployPair(address,address)` on every family, **including Orbital**. Named `deployPairPool01/12/02` and pairId are **void**. Orbital CODE in this worktree must be amended to match (v0.5 in the gold staged PRD).

Do not reopen gold S2, S9, S12, S21–S26, S35, S47–S57 except where v0.5 replaces S13 / S14 / S18 / S33 / S45 / S49. Each family PRD only changes **which unordered pairs are product doors**, **`productionFacetCuts()`**, **today’s `facetInterfaces()`**, **`beforeInitialize` checks as they exist today**, and **grep-and-fix callers**.

## Why another family

`deployVault` still does, on every unfinished family, some mix of:

1. Cutting the full production ABI in `pkg.facetCuts()` (hooks / LP / SE / join / exit).
2. Running `PoolManager.initialize` from `pkg.postDeploy` (multi-door families).

That is the same public-network gas cliff Orbital staged. One-pool families already no-op `postDeploy`; they still cut the full ABI at CREATE2. They still need bootstrap + one door + finalize so `beforeInitialize` exists before the door and swap/LP selectors do not.

## Families (implement one worktree at a time)

| Order | Family | Package | Product pairs (`deployPair`) | `postDeploy` today | Production Adds (after vault pair) | PRD |
|------:|--------|---------|------------------------------|--------------------|-------------------------------------|-----|
| 0 | Orbital (gold shape; **ABI amend**) | `UniswapV4OrbitalSwapHookDFPkg` | 3: (t0,t1) (t1,t2) (t0,t2) | `return true` | hooks, liquidity, ERC20, ERC5267, ERC2612 | [staged PRD v0.5](./orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) |
| 1 | SE Orbital | `UniswapV4StandardExchangeOrbitalBufferHookDFPkg` | 3: (t0,t1) (t1,t2) (t0,t2) | `ensureThreePairPools` | hooks, deposit, withdraw, SE, ERC20, ERC5267, ERC2612 | [PRD](./standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_STAGED_INIT_PRD.md) |
| 2 | Weighted | `UniswapV4WeightedSwapHookDFPkg` | `C(n,2)`, `n ∈ [2,8]` | `ensureAllPairPools` | hooks, liquidity, ERC20, ERC5267, ERC2612 | [PRD](./weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md) |
| 3 | Curve quad | `UniswapV4CurveQuadStableSwapHookDFPkg` | 6: all `i<j` among t0..t3 | `ensureSixPairPools` + package `ensurePairPools` | hooks, liquidity, ERC20, ERC5267, ERC2612 | [PRD](./stable/quad/curve/UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md) |
| 4 | Balancer quad | `UniswapV4BalancerQuadStableSwapHookDFPkg` | 6: all `i<j` among t0..t3 | `ensureSixPairPools` + package `ensurePairPools` | hooks, liquidity, ERC20, ERC5267, ERC2612 | [PRD](./stable/quad/balancer/UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md) |
| 5 | SE Weighted | `UniswapV4StandardExchangeWeightedBufferHookDFPkg` | `C(n,2)`, `n ∈ [2,8]` | `ensureAllPairPools` | hooks, join, exit, SE, ERC20, ERC5267, ERC2612 | [PRD](./standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_STAGED_INIT_PRD.md) |
| 6 | SE Curve quad | `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg` | 6: all `i<j` among t0..t3 | `ensureAllPairPools` | today’s `facetCuts()` minus vault pair | [PRD](./standardExchange/stable/quad/curve/UNISWAP_V4_STANDARD_EXCHANGE_CURVE_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md) |
| 7 | SE Balancer quad | `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg` | 6: all `i<j` among t0..t3 | `ensureAllPairPools` | hooks, liquidity, SE, ERC20, ERC5267, ERC2612 | [PRD](./standardExchange/stable/quad/balancer/UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md) |
| 8 | Dual SE CP | `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg` | 1: (currency0, currency1) | already `return true` (`pure`) | hooks, deposit, withdraw, SE, ERC20, ERC5267, ERC2612 | [PRD](./standardExchange/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md) |
| 9 | Single SE CP | `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg` | 1: (currency0, currency1) | already `return true` (`pure`) | SE, deposit, withdraw, ERC20, ERC5267, ERC2612 (`beforeInitialize` on **SE facet**) | [PRD](./standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md) |
| 10 | Single SE Buffer (legacy) | `UniswapV4SingleStandardExchangeBufferHookDFPkg` | 1: wrap-aware product pair | already `return true` (`pure`) | `PRODUCT_FACET` only | [PRD](./standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_STAGED_INIT_PRD.md) |

`factory/` is not a product hook. Do not write a staged-init PRD or plan for the hook factory. F33 and `_deployAt` stay.

**Implementation plans** (co-located with each PRD; gold plan also holds the v0.5 `deployPair` ABI amend):

| Order | Plan |
|------:|------|
| 0 | [`orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](./orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) (v0.5 ABI amend + diamond SoT) |
| 1 | [`standardExchange/orbital/..._STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](./standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 2 | [`weighted/..._STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](./weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 3 | [`stable/quad/curve/...`](./stable/quad/curve/UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 4 | [`stable/quad/balancer/...`](./stable/quad/balancer/UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 5 | [`standardExchange/weighted/...`](./standardExchange/weighted/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 6 | [`standardExchange/stable/quad/curve/...`](./standardExchange/stable/quad/curve/UNISWAP_V4_STANDARD_EXCHANGE_CURVE_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 7 | [`standardExchange/stable/quad/balancer/...`](./standardExchange/stable/quad/balancer/UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 8 | [`standardExchange/dual/...`](./standardExchange/dual/UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 9 | [`standardExchange/constantProduct/single/...`](./standardExchange/constantProduct/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |
| 10 | [`standardExchange/single/...`](./standardExchange/single/UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) |

## Shared gold law (every family PRD restates this)

Copy Orbital v0.4.2. Do not invent a second diamond shape.

| Law | Value |
|-----|--------|
| Package is the init facet | DFPkg inherits `*InitFacet` (`InitTarget` + `IFacet`). Cut `address(SELF)`. Never CREATE3 InitFacet. Never `PkgInit.initFacet`. Never `FactoryService.deployInitFacet`. |
| Bootstrap `facetCuts()` | `[0]` MultiAssetBasicVaultFacet Add; `[1]` MultiAssetStandardVaultFacet Add; `[2]` `address(SELF)` Add + init-only selectors. Vault pair **required** (`deployHookVault` calls `vaultConfig()`). |
| Production ABI | Absent until `finalizeInitialization`. `productionFacetCuts()` is the Add list. `facetCuts()` ≠ that list. |
| `postDeploy` | `return true`. Zero `PoolManager.initialize`. Delete family `ensure*PairPools` / package `ensurePairPools`. Keep the existing mutability (`public` vs `public pure`) that the family already has. |
| Finalize | `nonReentrant`. Revert `ProductDoorsNotLive` unless **all product doors** for that instance are live. Remove `address(SELF)` + inherited `facetFuncs()`. Add `productionFacetCuts()`. Emit `IDiamond.DiamondCut` then `InitializationFinalized`. Set `initializationFinalized` **after** the cut. No ERC165 mutation. No public `diamondCut`. |
| `beforeInitialize` | Shared lib used by InitTarget and the production facet that owns the selector today. Checks stay **bit-identical** to that family’s current Target. Do not add `hooks == address(this)`. |
| Shared door ABI | Every Init facet implements **`IUniswapV4HookStagedPairInit`** (new file under `hooks/uniswap/v4/interfaces/`). Call is `deployPair(address tokenA, address tokenB)`. Sort internally (`currency0 < currency1`). `(a,b)` and `(b,a)` are the same door. Same token or a pair that is not a **product** door reverts. Product PoolKey uses that family’s existing fee / tick / sqrt policy. Idempotent skip-if-live. **No** `deployPairPool01`, **no** `deployPairPool(uint8)`, **no** pairId. |
| Event | `PairPoolDeployed(address indexed hook, address indexed currency0, address indexed currency1, bytes32 poolId)` with sorted currencies. Emit only on first init of that product key. |
| Door views | Only on the Init surface: `isPairPoolLive(address,address)`, `pairPoolKey(address,address)`, `isInitializationFinalized()`. Both address orders resolve to the same product key. Unbound / non-product pair reverts. Not on the product hook interface. Unmatched after finalize. |
| Init selectors (all families) | `IHooks.beforeInitialize`, `deployPair`, `finalizeInitialization`, `isPairPoolLive`, `pairPoolKey`, `isInitializationFinalized` (exactly 6). |
| `facetInterfaces()` | DFPkg **overrides** to **today’s** IDs for that package (same selector as IFacet). Do not unregister IERC20. Do not register the Init ID. |
| Tests | Gold TestBase `setUp` calls `_ensureProductDoorsAndFinalize` after `deployHook`: one `deployPair` per product unordered pair, then `finalizeInitialization`. Dedicated S43-style bootstrap-only spec. Grep-and-fix **this package only**. Default hermetic profile. No `via_ir`. No mocks of hook / package / factory / PoolManager / registry / fee oracle. |
| Factory | Do not edit `_deployAt` / `initAccount` control flow. |

## Suggested agent cadence

0. **First:** amend Orbital Init to `IUniswapV4HookStagedPairInit` (delete named `deployPairPool*`, new event, address-pair views). That shared interface is what later families inherit.
1. New git worktree from the last green parent (this worktree after the Orbital ABI amend, or `main` after a fast-forward).
2. Seed `cache_forge/` + `out/` from the warm checkout (Claude.md worktree compile seed).
3. Open **this index** + **one** family PRD + **that family’s implementation plan**. Then CODE. Do not start from a blank plan.
4. Do not start family N+1 in the same worktree.
5. After green default-profile tests for that family, rebase/fast-forward as you planned.

## Out of this index

- Product math, fees, Permit2, salt, flags, `PRODUCT_ID`, `PkgInit` field order.
- Frontend and unrelated Anvil scripts unless the family grep hits them.
- Implementing more than one family in one change set.
