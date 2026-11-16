# PRD: Single SE Buffer Hook (legacy) — Staged Pair-Door Initialization

**Name:** `UniswapV4SingleStandardExchangeBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/single/`  
**Package kind:** **Amend** `UniswapV4SingleStandardExchangeBufferHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Product: [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_HOOK_PRD.md). This is the **legacy** single-SE buffer (one `PRODUCT_FACET`, no ERC20Permit cuts). Do not conflate with Single SE **CP** under `constantProduct/single/`.

---

## 0. Goal

One product door. `postDeploy` is already `return true` (`pure`). Today `facetCuts()` is already vault pair + `PRODUCT_FACET`. Still stage it: bootstrap is vault pair + package-as-init (so `beforeInitialize` exists without the rest of the product ABI); finalize Adds **only** `PRODUCT_FACET`.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product door | The one wrap-aware pair already encoded in Repo (`_wrapZeroForOne`). **`fee = 0`**. `hooks = proxy` |
| Door ABI | Shared **`deployPair(address,address)`**. Sort internally. Only that wrap-aware pair (either order) is a product door. Event is gold S59 |
| `postDeploy` | Keep `public pure returns (bool) { return true; }` |
| `productionFacetCuts()` | `[0]` PRODUCT_FACET + its live `facetFuncs()` |
| `facetInterfaces()` (keep) | Today’s 5 IDs: IHooks, IUniswapV4SingleStandardExchangeBufferHook, IBasicVault, IStandardVault, HOOK_VAULT_TYPE. **No IERC20** (this package does not cut ERC20Permit) |
| `beforeInitialize` today | Target, `view`: PoolManager, wrap-aware pair, `fee == 0`. **No** `poolInitialized` write. Shared lib must stay bit-identical |

## 2. Locked

| # | Law |
|---|-----|
| L1 | This directory only. Grep `UniswapV4SingleStandardExchangeBufferHookDFPkg` + this package deploy helpers. **Do not** touch `constantProduct/single/`. |
| L2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S47–S57. S35 = today’s view-only checks. Do **not** add Dual/Single-CP `poolInitialized` here. |
| L3 | Do not reopen wrap direction, salt, flags, `PRODUCT_ID`, or add ERC20Permit cuts. |
| L4 | Init selectors: gold S58 (exactly 6). |
| L5 | After finalize, `beforeInitialize` lives on `PRODUCT_FACET`. Vault pair remains. |
| L6 | TestBase: `_ensureProductDoorsAndFinalize` after `deployHook` (`deployPair` + finalize). If setUp currently calls `pm.initialize`, that call is replaced by `deployPair`. |
| L7 | Leave ERC165 as today’s five IDs. Do not invent an IERC20 claim this package does not have. |

## 3. Files / tests / DoD

Init split + DFPkg inherit + Repo flag + TestBase helper. S43: `vaultConfig` works; product selectors unmatched; `supportsInterface(IHooks)` follows today’s as-built (claimed if factory registered it). Gold J-surface for unmatched product selectors before finalize. Patch this family’s product PRD if it claims full product ABI at CREATE2. No Single SE CP edits.
