# Implementation & Test Plan: Weighted Swap Hook Staged Init

**PRD:** [`UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Index:** [`../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md)  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit` exists (Orbital v0.5). One family per worktree.

---

## 0. Goal

Amend `UniswapV4WeightedSwapHookDFPkg`. Product doors = every unordered pair of bound `tokens` (`n ∈ [2,8]`, `C(n,2)`). Door call is `deployPair(a,b)`, not pairId.

## 1. Locked

Gold I1–I10, I15 with `UniswapV4WeightedSwapHook*` names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, LIQUIDITY, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` today’s 6 IDs |
| **F3** | `_isProductPair`: both addresses appear in Repo `tokens` and are distinct |
| **F4** | Product key: existing `PairPoolLib.pairKey` (DYNAMIC_FEE, 0 → `Math.TICK_SPACING` / tick-0 mid) |
| **F5** | Delete `ensureAllPairPools`. `postDeploy` `return true` |
| **F6** | Do not edit SE Weighted |
| **F7** | TestBase helper: nested `i<j` `deployPair(tokens[i], tokens[j])` then finalize. At least one spec with n=2 and one with n≥3 |

## 2. Files

Init alias + BeforeInitializeLib + InitTarget + InitFacet; DFPkg inherit; Repo flag; PairPoolLib keep `pairKey` / `initIfNeeded` / `isPoolLive`; HooksTarget → lib; TestBase helper; package `+ productionFacetCuts()`. New `test/.../weighted/UniswapV4WeightedSwapHook_StagedInit.t.sol`. Grep-fix Factory / product specs.

## 3. Phases / tests / DoD

A+B+C one compile. D helper + grep. E staged + J. F docs.  
Tests: S58 `facetFuncs`; S43; `deployPair` reverse-args; unbound revert; finalize missing one pair of `C(n,2)`; extra tick-spacing does not count. No n=8 hermetic requirement. No `via_ir`.
