# Implementation & Test Plan: Curve Quad Stable Swap Hook Staged Init

**PRD:** [`UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Index:** [`../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md)  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`. Do not edit Balancer quad or SE Curve in this worktree.

---

## 0. Goal

Amend `UniswapV4CurveQuadStableSwapHookDFPkg`. Six product pairs: all `i<j` among t0..t3. `deployPair` only.

## 1. Locked

Gold I1–I10, I15 with Curve quad type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, LIQUIDITY, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` today’s 6 IDs |
| **F3** | `_isProductPair`: both tokens in `{t0,t1,t2,t3}` and distinct |
| **F4** | Product key: sort args, then existing `pairKey` (`fee = lpFeePips`, `tickSpacing = Math.TICK_SPACING`, tick-0 mid). Do **not** switch to DYNAMIC_FEE |
| **F5** | Delete `ensureSixPairPools` and package `ensurePairPools`. Keep `computeKeys` / `pairKey` / `isPoolLive`. `postDeploy` `return true` |
| **F6** | `beforeInitialize` lib: today’s checks including **fee == stored lpFeePips** |
| **F7** | TestBase: `deployPair` for each of the six pairs + finalize |

## 2. Files / phases / tests

Standard Init split + DFPkg inherit + Repo flag + TestBase. New `*_StagedInit.t.sol`. Grep this package only.  
Tests: S58; S43; finalize 0 and 5 doors revert; extra fee/tick does not count; stranger may door+finalize. Patch product/refactor docs that claim `ensurePairPools` / `postDeploy` inits all six.
