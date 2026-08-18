# Implementation & Test Plan: SE Balancer Quad Stable Buffer Hook Staged Init

**PRD:** [`UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Door peer:** raw Balancer quad staged plan. Do not edit raw Balancer or SE Curve.  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`.

---

## 0. Goal

Amend `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg`. Six `deployPair` product pairs.

## 1. Locked

Gold I1–I10, I15 with this family’s type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, LIQUIDITY, SE, ERC20, ERC5267, ERC2612 (today’s cuts minus vault pair) |
| **F2** | `facetInterfaces()` today’s 10 IDs |
| **F3** | `_isProductPair`: both in the four bound tokens, distinct |
| **F4** | Product key from this PairPoolLib after sorting args |
| **F5** | Delete `ensureAllPairPools`. `postDeploy` `return true` |
| **F6** | TestBase: six `deployPair` + finalize |

## 2. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag. New staged spec. Grep this package only. Six-door finalize matrix. Patch family product PRD if it claims same-tx all-six.
