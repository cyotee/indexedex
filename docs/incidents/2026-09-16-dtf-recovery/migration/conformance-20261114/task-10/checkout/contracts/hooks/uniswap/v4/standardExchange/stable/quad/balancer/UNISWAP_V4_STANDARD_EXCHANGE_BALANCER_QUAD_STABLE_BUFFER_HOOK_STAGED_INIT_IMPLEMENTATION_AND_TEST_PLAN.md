# Implementation & Test Plan: SE Balancer Quad Stable Buffer Hook Staged Init

**PRD:** [`UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_BALANCER_QUAD_STABLE_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Door peer:** raw Balancer quad staged plan. Do not edit raw Balancer or SE Curve.  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`.

**Amended 2026-09-06:** the [2–5 token correction PRD](UNISWAP_V4_SE_BALANCER_STABLE_BUFFER_HOOK_TOKEN_COUNT_FIX_PRD.md) supersedes fixed-four/six-pair assumptions in this plan. Its ABI, storage, math, and compatibility requirements must be incorporated into the follow-on implementation plan.

---

## 0. Goal

Amend `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg`. Enumerate `n * (n - 1) / 2` product pairs through `deployPair` for each supported `n` from 2 through 5.

## 1. Locked

Gold I1–I10, I15 with this family’s type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, LIQUIDITY, SE, ERC20, ERC5267, ERC2612 (today’s cuts minus vault pair) |
| **F2** | `facetInterfaces()` today’s 10 IDs |
| **F3** | Product pair membership: both in the `n` active bound tokens, distinct; include the fifth token when n=5 |
| **F4** | Product key from this PairPoolLib after sorting args |
| **F5** | Delete `ensureAllPairPools`. `postDeploy` `return true` |
| **F6** | TestBase: 1/3/6/10 `deployPair` calls + finalize for n=2/3/4/5; missing-pair and repeated-finalize negatives |

## 2. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag. Update the staged spec and this package's direct consumers for variable-count binding. Validate the full 1/3/6/10-door matrix with shared-book behavior and correct pre-/post-finalization selectors. Keep the family product PRD consistent with the correction.
