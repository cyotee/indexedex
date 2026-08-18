# Implementation & Test Plan: Single SE Buffer CP Hook Staged Init

**PRD:** [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`. Do not edit Dual or legacy Single Buffer.

---

## 0. Goal

Amend `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg`. One product pair. No dedicated hooks facet: after finalize, `beforeInitialize` lives on **`SE_FACET`**.

## 1. Locked

Gold I1–I8, I15. I9: keep `postDeploy` **`public pure` `return true`**.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: SE, DEPOSIT, WITHDRAW, ERC20, ERC5267, ERC2612 (today’s cuts minus vault pair) |
| **F2** | `facetInterfaces()` today’s 9 IDs |
| **F3** | `_isProductPair`: sorted args equal Repo `(currency0, currency1)` |
| **F4** | Product key: those currencies, **`fee = 0`** |
| **F5** | `beforeInitialize` lib: today’s `poolInitialized` / `AlreadyInitialized` / `fee == 0`. Shared by InitTarget **and** SeTarget |
| **F6** | After finalize, loupe `beforeInitialize` == `SE_FACET` (from package immutable, not a magic literal) |
| **F7** | TestBase: replace `pm.initialize(poolKey, SQRT_PRICE_1_1)` with `deployPair` + finalize. Grep research fixture under `scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/` if it deploys this package |

## 2. Files / tests / DoD

Init split + DFPkg inherit + Repo flag at end (do not move `poolInitialized`). New staged spec. S43 + one-door finalize + J unmatched deposit/SE before finalize. Existing product specs via helper.
