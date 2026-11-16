# Implementation & Test Plan: SE Weighted Buffer Hook Staged Init

**PRD:** [`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Door peer:** raw Weighted staged plan (`deployPair`, `C(n,2)`). Do not edit raw Weighted.  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`.

---

## 0. Goal

Amend `UniswapV4StandardExchangeWeightedBufferHookDFPkg`. Product pairs = all `i<j` on bound tokens. Production Adds include join / exit / SE.

## 1. Locked

Gold I1–I10, I15 with this family’s type names.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, JOIN, EXIT, SE, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` today’s 10 IDs |
| **F3** | `_isProductPair`: both in Repo `tokens`, distinct |
| **F4** | Product key = this lib’s pair policy (today `postDeploy` passes tickSpacing `0`) |
| **F5** | Delete `ensureAllPairPools`. `postDeploy` `return true` |
| **F6** | Do not edit `hooks/uniswap/v4/weighted/` |
| **F7** | TestBase: nested `i<j` `deployPair` + finalize. Join/exit/SE unmatched until finalize |

## 2. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag. New `*_StagedInit.t.sol`. Grep this package only. n=2 and n≥3. S58 / S43 / J-surface. No `via_ir`.
