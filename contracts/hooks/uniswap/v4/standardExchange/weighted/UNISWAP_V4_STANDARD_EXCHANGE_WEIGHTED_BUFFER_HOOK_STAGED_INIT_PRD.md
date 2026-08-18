# PRD: SE Weighted Buffer Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4StandardExchangeWeightedBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/weighted/`  
**Package kind:** **Amend** `UniswapV4StandardExchangeWeightedBufferHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Door ABI peer: [raw Weighted staged PRD](../../weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_STAGED_INIT_PRD.md) (`deployPairPool(uint8)` + `C(n,2)`). Do not edit raw Weighted in this change set.

---

## 0. Goal

Same `deployPair` product set as raw Weighted (`n ∈ [2,8]`, `C(n,2)` pairs). Production Adds include **join / exit / SE** as well as hooks + ERC20 trio.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | Unordered pairs of bound `tokens[i<j]`. Address-sorted. Fee / tick / sqrt = **this lib’s** `ensureAllPairPools` policy (today `postDeploy` passes tickSpacing `0`) |
| Door ABI | Shared **`deployPair(address,address)`**. No pairId. No `pairCount()` on Init |
| Delete | `PairPoolLib.ensureAllPairPools` as a required path |
| `productionFacetCuts()` Add order | `[0]` HOOKS; `[1]` JOIN; `[2]` EXIT; `[3]` SE; `[4]` ERC20; `[5]` ERC5267; `[6]` ERC2612 |
| `facetInterfaces()` (keep) | IERC20, IERC20Metadata, IERC20Permit, IERC5267, IStandardExchangeIn, IStandardExchangeOut, IStandardExchangeMultiAssetLiquidity, IBasicVault, IStandardVault, HOOK_VAULT_TYPE |
| `beforeInitialize` | Today’s hooks-target checks, shared lib |

## 2. Locked

| # | Law |
|---|-----|
| SW1 | This directory only. Grep `UniswapV4StandardExchangeWeightedBufferHookDFPkg` + this package deploy helpers. **Do not** touch raw Weighted. |
| SW2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with this family’s type names. |
| SW3 | Do not reopen SE claim/pull, weights, n bounds, salt, flags, `PRODUCT_ID`. |
| SW4 | Init selectors: gold S58 (exactly 6). |
| SW5 | TestBase loops every `i<j` with `deployPair(tokens[i], tokens[j])` then finalize. Join/exit/SE unmatched until finalize. |
| SW6 | Unbound or same-token `deployPair` reverts. |

## 3. Files / tests / DoD

Init interface + lib + InitTarget/InitFacet, DFPkg inherit, Repo flag, delete bulk ensure, TestBase helper. Gold matrix + n=2 and n≥3 door counts. Existing product specs via helper. Patch product PRD if it claims `postDeploy` inits all pairs. No raw Weighted edits.
