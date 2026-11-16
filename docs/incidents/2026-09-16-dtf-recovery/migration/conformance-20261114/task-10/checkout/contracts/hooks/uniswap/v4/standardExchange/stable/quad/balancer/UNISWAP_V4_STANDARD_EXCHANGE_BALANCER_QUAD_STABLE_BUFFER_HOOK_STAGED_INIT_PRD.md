# PRD: SE Balancer Quad Stable Buffer Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4StandardExchangeBalancerQuadStableBufferHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/`  
**Package kind:** **Amend** `UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg`.

**Token-count amendment (2026-09-06):** apply the [2–5 token correction PRD](UNISWAP_V4_SE_BALANCER_STABLE_BUFFER_HOOK_TOKEN_COUNT_FIX_PRD.md). Its variable-count requirements supersede historical four-token/six-pair restrictions. Pair-creation timing, permissionless access, and one-time finalization remain required.

**Authority:** this PRD on door timing. Gold: [`../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Door ABI peer: [raw Balancer quad staged PRD](../../../../stable/quad/balancer/UNISWAP_V4_BALANCER_QUAD_STABLE_SWAP_HOOK_STAGED_INIT_PRD.md). Do not edit raw Balancer quad or SE Curve quad here.

---

## 0. Goal

All `n * (n - 1) / 2` product pairs via `deployPair`, then finalize, for `2 <= n <= 5`. `postDeploy` remains a no-op; the historical bulk `ensureAllPairPools` path is not the required behavior.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | All unordered pairs among the `n` active currencies: 1/3/6/10 for n=2/3/4/5 |
| Door ABI | Shared **`deployPair(address,address)`**. No named 01/02/… functions. No pairId |
| Delete | `ensureAllPairPools` as a required path |
| `productionFacetCuts()` | HOOKS, LIQUIDITY, SE, ERC20, ERC5267, ERC2612 (today’s `facetCuts()` minus vault pair, same relative order) |
| `facetInterfaces()` (keep) | Today’s 10 IDs |
| `beforeInitialize` | Today’s hooks-target checks, shared lib |

## 2. Locked

| # | Law |
|---|-----|
| SB1 | This package and directly affected deployment/ABI/test consumers. Search the complete production type name and this package's deploy helpers. |
| SB2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with this family’s type names. |
| SB3 | Preserve Balancer math identity, SE behavior, and hook flags. The token-count correction governs necessary count-dependent math, binding, ABI/storage, and salt-compatibility work; the former blanket freeze must not block that correction. |
| SB4 | Init selectors: gold S58 (exactly 6). |
| SB5 | TestBase: enumerate every active product pair and finalize for n=2/3/4/5; prove rejection with any required pair missing. |

## 3. Files / tests / DoD

Standard Init split + DFPkg inherit + Repo flag + TestBase helper. Gold matrix with 1/3/6/10 doors, including last-index membership and final-pair checks at n=5. Keep this family's product PRD consistent with staged variable-count initialization. No raw Balancer or SE Curve edits.
