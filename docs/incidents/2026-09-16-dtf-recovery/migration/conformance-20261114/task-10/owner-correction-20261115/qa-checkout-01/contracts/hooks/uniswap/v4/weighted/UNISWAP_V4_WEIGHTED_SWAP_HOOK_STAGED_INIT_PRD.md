# PRD: Weighted Swap Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4WeightedSwapHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/weighted/`  
**Package kind:** **Amend** `UniswapV4WeightedSwapHookDFPkg`.

**Authority:** this PRD (door timing) > product PRD on same-tx all-pairs init. Gold: [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Index: [`../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md). Hook factory F33 unchanged.

---

## 0. Goal

Bootstrap diamond at `deployVault`, then `deployPair(a,b)` once per **unordered binding pair**, then `finalizeInitialization`. `n` is instance-specific (`Math.MIN_N=2` … `Math.MAX_N=8`). Product door count is `C(n,2)` (1 pair at n=2, 28 pairs at n=8).

## 1. Why

Today `facetCuts()` is 7 production Adds and `postDeploy` runs `PairPoolLib.ensureAllPairPools` (every `i<j` initialize in the deploy tx). That is the worst-case gas cliff in this tree.

## 2. Family facts

| Fact | Value |
|------|--------|
| Product door | Every unordered pair of bound `tokens[i]`, `tokens[j]` (`i<j`). Address-sorted currencies. `fee = DYNAMIC_FEE_FLAG`. `hooks = proxy`. Tick/sqrt from Repo (0 → `Math.TICK_SPACING` / tick-0 mid) |
| Door ABI | Shared **`deployPair(address,address)`**. Sort internally. A pair that is not two distinct bound tokens reverts. **No** pairId. **No** `pairCount()` on Init |
| Views | `isPairPoolLive(address,address)`, `pairPoolKey(address,address)`, `isInitializationFinalized()` |
| Event | Gold S59: `PairPoolDeployed(hook, currency0, currency1, poolId)` sorted, first init only |
| `productionFacetCuts()` Add order | `[0]` HOOKS_FACET; `[1]` LIQUIDITY_FACET; `[2]` ERC20_FACET; `[3]` ERC5267_FACET; `[4]` ERC2612_FACET |
| `facetInterfaces()` (keep) | IERC20, IERC20Metadata, IERC20Permit, IERC5267, IBasicVault, IStandardVault |
| Bulk ensure to delete | `PairPoolLib.ensureAllPairPools` |
| Repo | Append `initializationFinalized` at end of `Layout` |

`pairPoolKey(pairId)` always returns the constructed product key even if not live. Finalize requires **every** `pairId ∈ [1, pairCount()]` live. Extra tick-spacing pools do not count.

## 3. Locked

| # | Law |
|---|-----|
| W1 | This directory only. Grep `UniswapV4WeightedSwapHookDFPkg` and this package `deployVault` / `deployVaultAutoMine` / `PkgFactory.deployHook`. **Do not** touch SE Weighted unless that grep hits it. |
| W2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 apply (`UniswapV4WeightedSwapHook*` names). |
| W3 | Do not reopen weights, rate providers, n bounds, salt, flags, `PRODUCT_ID`, `PkgInit` field order, LP math. |
| W4 | Init selectors: gold S58 (exactly 6). |
| W5 | TestBase helper loops every `i<j` on `tokens()` and calls `deployPair(tokens[i], tokens[j])`, then `finalizeInitialization`. Hermetic setUp that uses a fixed n must still open **that instance’s** full product set. |
| W6 | `beforeInitialize` lib: today’s hooks-target checks only (bound pair, distinct, `DYNAMIC_FEE_FLAG`, caller is PoolManager). |

## 4. Files

```text
weighted/
  interfaces/IUniswapV4WeightedSwapHookInit.sol          # NEW
  UniswapV4WeightedSwapHookBeforeInitializeLib.sol
  UniswapV4WeightedSwapHookInitTarget.sol
  facets/UniswapV4WeightedSwapHookInitFacet.sol
  UniswapV4WeightedSwapHookDFPkg.sol
  UniswapV4WeightedSwapHookPairPoolLib.sol               # keep pairKey / initIfNeeded / isPoolLive
  UniswapV4WeightedSwapHookRepo.sol
  UniswapV4WeightedSwapHookHooksTarget.sol               # or Target: beforeInitialize → lib
  TestBase_UniswapV4WeightedSwapHook.sol
  interfaces/IUniswapV4WeightedSwapHook.sol              # UNCHANGED
  interfaces/IUniswapV4WeightedSwapHookPackage.sol       # + productionFacetCuts()
```

## 5. Tests

Gold §7 matrix plus:

- `deployPair` of an unbound or same-token pair reverts.
- `(a,b)` and `(b,a)` open the same door (one event).
- Finalize with all-but-one product pairs live reverts `ProductDoorsNotLive`.
- At least one test uses n=2 (one pair) and one uses n≥3. Do not require an n=8 inits suite in hermetic DoD.

Existing `*_Liquidity` / `*_Swap` / `*_Factory` stay green via the helper.

## 6. Docs to patch

Product PRD / impl plan / diamond-package remediation text that says `postDeploy` or factory deploy initializes all pairs. Point here.

## 7. DoD

Gold §11 with indexed doors and 5 production Adds. No `via_ir`. No SE Weighted edits.
