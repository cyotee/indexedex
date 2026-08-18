# PRD: SE Curve Quad Stable Buffer Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4StandardExchangeCurveQuadStableBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Package kind:** **Amend** `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Door ABI peer: [raw Curve quad staged PRD](../../../../stable/quad/curve/UNISWAP_V4_CURVE_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md). Do not edit raw Curve quad in this change set.

---

## 0. Goal

Six product pairs via `deployPair`, then finalize. `postDeploy` today calls `PairPoolLib.ensureAllPairPools`.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | All six unordered pairs among t0..t3 (same set as raw quad) |
| Door ABI | Shared **`deployPair(address,address)`**. No named 01/02/… functions. No pairId |
| Delete | `ensureAllPairPools` as a required path |
| `productionFacetCuts()` | **Exactly today’s `facetCuts()` minus the two vault Adds**, in today’s relative order: HOOKS, LIQUIDITY, EXIT, SE, ERC20, ERC5267, ERC2612. Do **not** add a Join facet that is not already in `facetCuts()` |
| `facetInterfaces()` (keep) | Today’s 10 IDs (ERC20* + SE In/Out/MultiAssetLiquidity + vault + HOOK_VAULT_TYPE) |
| `beforeInitialize` | Today’s hooks-target checks, shared lib |

## 2. Locked

| # | Law |
|---|-----|
| SC1 | This directory only. Grep `UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg` + this package deploy helpers. |
| SC2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with this family’s type names. |
| SC3 | Do not reopen Curve StableSwap math, amp, SE claim/pull, salt, flags, `PRODUCT_ID`. |
| SC4 | Init selectors: gold S58 (exactly 6). |
| SC5 | TestBase: `deployPair` × 6 product pairs + finalize. Extra tick/fee pools do not satisfy finalize. |

## 3. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag + TestBase helper. Gold matrix with six doors. Patch this family’s product/impl PRD if it claims same-tx all-six. No raw Curve or SE Balancer edits.
