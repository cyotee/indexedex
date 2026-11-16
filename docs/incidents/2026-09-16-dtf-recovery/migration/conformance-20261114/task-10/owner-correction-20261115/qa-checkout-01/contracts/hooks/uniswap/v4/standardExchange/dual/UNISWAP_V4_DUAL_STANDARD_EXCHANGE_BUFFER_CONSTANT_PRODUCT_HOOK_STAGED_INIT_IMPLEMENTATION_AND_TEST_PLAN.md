# Implementation & Test Plan: Dual SE Buffer CP Hook Staged Init

**PRD:** [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`. Do not edit Single SE CP.

---

## 0. Goal

Amend `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg`. One product pair. `postDeploy` already returns true (`pure`); keep that. Stage the ABI.

## 1. Locked

Gold I1–I8, I15 with Dual type names. I9: keep **`public pure returns (bool) { return true; }`**.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: HOOKS, DEPOSIT, WITHDRAW, SE, ERC20, ERC5267, ERC2612 |
| **F2** | `facetInterfaces()` today’s 9 IDs |
| **F3** | `_isProductPair`: sorted `(tokenA,tokenB)` equals Repo `(currency0,currency1)` |
| **F4** | Product key: those currencies, **`fee = 0`**, this family’s tick/hooks. `deployPair` still sorts |
| **F5** | `beforeInitialize` lib **must** keep `poolInitialized` / `AlreadyInitialized` / `fee == 0` bit-identical |
| **F6** | TestBase: replace `pm.initialize` with `_ensureProductDoorsAndFinalize` (`deployPair` once + finalize). Do not double-init |
| **F7** | Finalize reverts `ProductDoorsNotLive` if that one product key is not live |

## 2. Files / tests / DoD

Init split + DFPkg inherit + Repo flag (append `initializationFinalized` at **end**; do not move `poolInitialized`). New staged spec. S43: no live door; deposit/`transfer` unmatched. After one `deployPair` + finalize, existing product specs stay green. J: unmatched beforeSwap / deposit before finalize.
