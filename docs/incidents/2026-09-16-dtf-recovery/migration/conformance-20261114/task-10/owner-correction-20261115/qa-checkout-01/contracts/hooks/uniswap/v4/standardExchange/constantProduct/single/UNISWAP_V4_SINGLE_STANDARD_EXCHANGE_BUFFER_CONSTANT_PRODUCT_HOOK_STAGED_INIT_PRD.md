# PRD: Single SE Buffer CP Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4SingleStandardExchangeBufferConstantProductHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`  
**Package kind:** **Amend** `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg`.

**Authority:** this PRD on door timing and when the production ABI appears. Gold: [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Product: [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md).

---

## 0. Goal

One product door. `postDeploy` is already `return true` (`pure`). Stage the ABI: there is **no dedicated hooks facet**. Today `IHooks.beforeInitialize` is on **`SE_FACET`**. After finalize, that selector must live on `SE_FACET` again (Remove package-as-init, Add production including SE).

## 1. Family facts

| Fact | Value |
|------|--------|
| Product door | Address-sorted `(currency0, currency1)` from Repo (`rawToken` / `pairToken`). **`fee = 0`**. `hooks = proxy` |
| Door ABI | Shared **`deployPair(address,address)`**. Sort internally. Event is gold S59 |
| `postDeploy` | Keep `public pure returns (bool) { return true; }` |
| `productionFacetCuts()` | SE, DEPOSIT, WITHDRAW, ERC20, ERC5267, ERC2612 (today’s `facetCuts()` minus vault pair, same relative order) |
| `facetInterfaces()` (keep) | Today’s 9 IDs |
| `beforeInitialize` today | Target / SeTarget: PoolManager, exact currencies, `fee == 0`, sets `poolInitialized`, `AlreadyInitialized` on second init. Shared lib must stay bit-identical |
| Production owner of `beforeInitialize` | **`SE_FACET`**, not a hooks facet |

## 2. Locked

| # | Law |
|---|-----|
| P1 | This directory only. Grep `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg` + this package deploy helpers. Includes `scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/` if that grep hits it. **Do not** touch Dual or legacy Single Buffer. |
| P2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S47–S57. S35 = today’s Single CP checks (`fee == 0`, `poolInitialized`). |
| P3 | Do not reopen SE share LP, claim/pull, salt, flags, `PRODUCT_ID`, `PkgInit` field order. |
| P4 | Init selectors: gold S58 (exactly 6). |
| P5 | TestBase today calls `pm.initialize(poolKey, SQRT_PRICE_1_1)` after deploy. Replace with `_ensureProductDoorsAndFinalize` (`deployPair` then finalize). Do not double-initialize. |
| P6 | After finalize, loupe `facetAddress(beforeInitialize) == address(SE_FACET)` (use `hookPkg` / PkgInit immutable, not a magic literal). |

## 3. Files / tests / DoD

Init split + DFPkg inherit + Repo flag + TestBase helper. S43: no door, `vaultConfig` works, deposit / `transfer` unmatched, ERC165 still claims IERC20. J-surface: unmatched SE/deposit before finalize. Patch product PRD if it claims full ABI at CREATE2. No Dual edits.
