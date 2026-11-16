# Implementation & Test Plan: SE Curve Quad Stable Buffer Hook Staged Init

**PRD:** [`UNISWAP_V4_STANDARD_EXCHANGE_CURVE_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_CURVE_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Door peer:** raw Curve quad staged plan. Do not edit raw Curve or SE Balancer.  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`.

---

## 0. Goal

Amend `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg`. Six `deployPair` product pairs among t0..t3.

## 1. Locked

Gold I1–I10, I15 with this family’s type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()` = **today’s `facetCuts()` minus vault pair**, same relative order: HOOKS, LIQUIDITY, EXIT, SE, ERC20, ERC5267, ERC2612. Do **not** add a Join facet that is not already cut |
| **F2** | `facetInterfaces()` today’s 10 IDs |
| **F3** | `_isProductPair`: both in the four bound tokens, distinct |
| **F4** | Product key from this PairPoolLib after sorting args |
| **F5** | Delete `ensureAllPairPools`. `postDeploy` `return true` |
| **F6** | TestBase: six `deployPair` + finalize |

## 2. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag. New staged spec. Grep this package only. Finalize 0 and 5 doors revert. Patch family product/impl docs if they claim same-tx all-six.
