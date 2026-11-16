# PRD: Dual SE Buffer CP Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4DualStandardExchangeBufferConstantProductHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/dual/`  
**Package kind:** **Amend** `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg`.

**Authority:** this PRD on door timing and when the production ABI appears. Gold: [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Product: [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md).

---

## 0. Goal

One product pair. `postDeploy` is **already** `return true` (`pure`). The remaining cliff is **full production ABI at CREATE2**. Stage it: bootstrap (vault pair + package-as-init) → `deployPair(currency0, currency1)` → `finalizeInitialization`.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product door | The single address-sorted pair `(currency0, currency1)` already stored in Repo. **`fee = 0`** (today’s Target). `hooks = proxy` |
| Door ABI | Shared **`deployPair(address,address)`**. Sort internally. The only legal pair is that product pair (either order). Event is gold S59 (no pairId) |
| Views | `isPairPoolLive(address,address)`, `pairPoolKey(address,address)`, `isInitializationFinalized()` |
| `postDeploy` | Keep **`public pure returns (bool) { return true; }`** (already). Do not change to non-pure |
| `productionFacetCuts()` | HOOKS, DEPOSIT, WITHDRAW, SE, ERC20, ERC5267, ERC2612 |
| `facetInterfaces()` (keep) | Today’s 9 IDs |
| `beforeInitialize` today | Hooks target: PoolManager, exact `(currency0,currency1)`, `fee == 0`, sets `Repo.poolInitialized`, reverts `AlreadyInitialized` on a second init. **Keep bit-identical.** Extra Q31-style second PoolKeys are **not** a product door and must still hit `AlreadyInitialized` if that is today’s behavior |

Gold “extra tick-spacing counts as not the product door” still applies: a different spacing/fee key is not `pairPoolKey()` and does not satisfy finalize.

## 2. Locked

| # | Law |
|---|-----|
| D1 | This directory only. Grep `UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg` + this package deploy helpers. |
| D2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S47–S57 with this family’s type names. S35 = **today’s Dual checks**, including `poolInitialized` / `AlreadyInitialized` / `fee == 0`. |
| D3 | Do not reopen dual SE claim, wrap direction, salt, flags, `PRODUCT_ID`. |
| D4 | Init selectors: gold S58 (exactly 6). |
| D5 | TestBase today calls `pm.initialize` after `deployHook`. Replace that with `_ensureProductDoorsAndFinalize` (`deployPair` then finalize). Do not double-initialize. |
| D6 | Finalize reverts `ProductDoorsNotLive` if the one product key is not live. |

## 3. Files / tests / DoD

Init interface + lib (must write `poolInitialized` the same way Target does) + InitTarget/InitFacet + DFPkg inherit + Repo flag at end + TestBase helper. S43: deploy alone has no live door and no deposit/`token0`/`transfer`. After one door + finalize, today’s product specs stay green. Patch product/factory-refactor PRD if it claims full ABI at CREATE2. No Single SE CP edits.
