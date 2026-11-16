# Implementation & Test Plan: Single SE Buffer Hook (legacy) Staged Init

**PRD:** [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_STAGED_INIT_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_STAGED_INIT_PRD.md)  
**Gold:** [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_IMPLEMENTATION_AND_TEST_PLAN.md) v0.5  
**Date:** 2026-08-17  
**Status:** Draft. Prerequisite: `IUniswapV4HookStagedPairInit`. Do **not** edit `constantProduct/single/`.

---

## 0. Goal

Amend `UniswapV4SingleStandardExchangeBufferHookDFPkg`. One wrap-aware product pair. Production Add is **`PRODUCT_FACET` only**. No ERC20Permit cuts. Do not invent IERC20 ERC165.

## 1. Locked

Gold I1–I8, I15. I9: keep `postDeploy` **`public pure` `return true`**.

| # | This family |
|---|-------------|
| **F1** | `productionFacetCuts()`: `[0]` PRODUCT_FACET + its `facetFuncs()` |
| **F2** | `facetInterfaces()` today’s **5** IDs (IHooks, product interface, vault pair, HOOK_VAULT_TYPE). Do not add IERC20 |
| **F3** | `_isProductPair`: sorted args match the wrap-aware Repo pair |
| **F4** | Product key: that pair, **`fee = 0`** |
| **F5** | `beforeInitialize` lib: today’s **view** checks (no `poolInitialized` write). Do not copy Dual/Single-CP AlreadyInitialized |
| **F6** | After finalize, `beforeInitialize` on PRODUCT_FACET |
| **F7** | TestBase: `deployPair` + finalize instead of any `pm.initialize` |

## 2. Files / tests / DoD

Init split + DFPkg inherit + Repo flag at end. Bootstrap `facetCuts` still 3 (vault pair + package-as-init). New staged spec. S43: `vaultConfig` works; product selectors unmatched. ERC165 matches today’s five IDs. Grep this package only.
