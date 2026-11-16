# PRD: Balancer Quad Stable Swap Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4BalancerQuadStableSwapHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/stable/quad/balancer/`  
**Package kind:** **Amend** `UniswapV4BalancerQuadStableSwapHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Index: [`../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md). Product: [`UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_PRD.md`](./UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_PRD.md). Sibling Curve quad staged PRD is the door-ABI peer, not a shared package.

---

## 0. Goal

Same six `deployPair` product pairs and finalize as Curve quad raw. Independent change set. Do not edit `stable/quad/curve/` or SE Balancer quad in this work.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | All six unordered pairs among t0..t3 (same set as today’s `computeKeys`) |
| PoolKey | `fee = lpFeePips` (not dynamic). `tickSpacing = Math.TICK_SPACING`. `hooks = proxy`. tick-0 mid |
| Door ABI | Shared **`deployPair(address,address)`**. No named 01/02/… functions. No pairId |
| Delete | `ensureSixPairPools`; package `ensurePairPools` as a required path |
| `productionFacetCuts()` | HOOKS, LIQUIDITY, ERC20, ERC5267, ERC2612 |
| `facetInterfaces()` (keep) | IERC20, IERC20Metadata, IERC20Permit, IERC5267, IBasicVault, IStandardVault, **IStandardExchangeMultiAssetLiquidity** (today’s 7 IDs, including that extra ID) |
| `beforeInitialize` | Today’s hooks-target checks, including **fee == stored lpFeePips**. Shared lib |

## 2. Locked

| # | Law |
|---|-----|
| B1 | This directory only. Grep `UniswapV4BalancerQuadStableSwapHookDFPkg` + this package deploy helpers. |
| B2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with `UniswapV4BalancerQuadStableSwapHook*` names. |
| B3 | Do not reopen Balancer StableSwap math, amp, lpFeePips, salt, flags, `PRODUCT_ID`. |
| B4 | Init selectors: gold S58 (exactly 6). |
| B5 | TestBase: `deployPair` × 6 product pairs + finalize. `_deployBootstrapOnly` for S43. |
| B6 | Leave `facetInterfaces()` as today’s **seven** IDs (do not drop `IStandardExchangeMultiAssetLiquidity`). |

## 3. Files / tests / DoD

Same split as the Curve quad staged PRD, with Balancer type names. Gold test matrix with six doors. Patch this family’s product PRD if it claims same-tx all-six init. No Curve-quad or SE-Balancer edits.
