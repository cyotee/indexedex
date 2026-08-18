# Implementation & Test Plan: Balancer Quad Stable Swap Hook Staged Init

**PRD:** [`UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Peer:** Curve quad staged plan (door set + fee=lpFeePips). Independent worktree.  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`. Do not edit Curve quad or SE Balancer.

---

## 0. Goal

Amend `UniswapV4BalancerQuadStableSwapHookDFPkg`. Six `deployPair` product pairs among t0..t3.

## 1. Locked

Gold I1–I10, I15 with Balancer quad type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, LIQUIDITY, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` today’s **7** IDs (keep `IStandardExchangeMultiAssetLiquidity`) |
| **F3** | `_isProductPair`: both in `{t0,t1,t2,t3}` and distinct |
| **F4** | Product key: sort, then existing `pairKey` (`fee = lpFeePips`, `Math.TICK_SPACING`) |
| **F5** | Delete `ensureSixPairPools` and package `ensurePairPools`. `postDeploy` `return true` |
| **F6** | `beforeInitialize` lib: today’s checks including fee == lpFeePips |
| **F7** | TestBase: six `deployPair` + finalize |

## 2. Files / phases / tests

Same split as Curve quad plan, Balancer type names. S58 / S43 / six-door finalize matrix. Patch this family’s product PRD if it claims same-tx all-six.
