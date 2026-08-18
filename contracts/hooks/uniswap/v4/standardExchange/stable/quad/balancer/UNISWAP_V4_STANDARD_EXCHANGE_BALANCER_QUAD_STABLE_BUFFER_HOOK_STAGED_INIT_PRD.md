# PRD: SE Balancer Quad Stable Buffer Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4StandardExchangeBalancerQuadStableBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`  
**Package kind:** **Amend** `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Door ABI peer: [raw Balancer quad staged PRD](../../../../stable/quad/balancer/UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md). Do not edit raw Balancer quad or SE Curve quad here.

---

## 0. Goal

Six product pairs via `deployPair`, then finalize. `postDeploy` today calls `PairPoolLib.ensureAllPairPools`.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | All six unordered pairs among t0..t3 |
| Door ABI | Shared **`deployPair(address,address)`**. No named 01/02/… functions. No pairId |
| Delete | `ensureAllPairPools` as a required path |
| `productionFacetCuts()` | HOOKS, LIQUIDITY, SE, ERC20, ERC5267, ERC2612 (today’s `facetCuts()` minus vault pair, same relative order) |
| `facetInterfaces()` (keep) | Today’s 10 IDs |
| `beforeInitialize` | Today’s hooks-target checks, shared lib |

## 2. Locked

| # | Law |
|---|-----|
| SB1 | This directory only. Grep `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg` + this package deploy helpers. |
| SB2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with this family’s type names. |
| SB3 | Do not reopen Balancer StableSwap math, amp, SE claim/pull, salt, flags, `PRODUCT_ID`. |
| SB4 | Init selectors: gold S58 (exactly 6). |
| SB5 | TestBase: `deployPair` × 6 product pairs + finalize. |

## 3. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag + TestBase helper. Gold matrix with six doors. Patch this family’s product PRD if it claims same-tx all-six. No raw Balancer or SE Curve edits.
