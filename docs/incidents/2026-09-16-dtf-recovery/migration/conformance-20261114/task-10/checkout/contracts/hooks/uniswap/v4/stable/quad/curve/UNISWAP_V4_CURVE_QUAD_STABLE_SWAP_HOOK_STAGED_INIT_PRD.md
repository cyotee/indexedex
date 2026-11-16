# PRD: Curve Quad Stable Swap Hook — Staged Pair-Door Initialization

**Name:** `UniswapV4CurveQuadStableSwapHook` staged init  
**Date:** 2026-08-17  
**Status:** **Draft v0.1** — copy Orbital gold v0.4.2. No CODE until accepted.  
**Package path:** `contracts/hooks/uniswap/v4/stable/quad/curve/`  
**Package kind:** **Amend** `UniswapV4CurveQuadStableSwapHookDFPkg`.

**Authority:** this PRD on door timing. Gold: [`../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md`](../../../orbital/UNISWAP_V4_ORBITAL_SWAP_HOOK_STAGED_INIT_PRD.md) v0.4.2. Index: [`../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../../UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md). Product: [`UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md`](./UNISWAP_V4_QUAD_STABLE_SWAP_HOOK_PRD.md). Factory F33 unchanged.

---

## 0. Goal

Four bound tokens, **six** product pairs via `deployPair`, then finalize. Do not run `ensureSixPairPools` or package `ensurePairPools` in the deploy tx.

## 1. Family facts

| Fact | Value |
|------|--------|
| Product doors | All six unordered pairs among t0..t3 (same set as today’s `computeKeys`) |
| PoolKey | `fee = lpFeePips` (**not** `DYNAMIC_FEE_FLAG`). `tickSpacing = Math.TICK_SPACING`. `hooks = proxy`. Init sqrt = tick-0 mid. `deployPair` sorts addresses before building the key |
| Door ABI | Shared **`deployPair(address,address)`**. No named 01/02/… functions. No pairId |
| Delete | `PairPoolLib.ensureSixPairPools`; package `ensurePairPools(address)` and `PairPoolsEnsured` as a **required** product path. Keep `computeKeys` / `pairKey` / `isPoolLive` / `initIfNeeded` (or equivalent) |
| `productionFacetCuts()` | `[0]` HOOKS; `[1]` LIQUIDITY; `[2]` ERC20; `[3]` ERC5267; `[4]` ERC2612 |
| `facetInterfaces()` (keep) | IERC20, IERC20Metadata, IERC20Permit, IERC5267, IBasicVault, IStandardVault |
| `beforeInitialize` | Today’s hooks-target checks (PoolManager, bound pair, **fee == stored lpFeePips**). Shared lib. Do not switch this family to `DYNAMIC_FEE_FLAG` |

## 2. Locked

| # | Law |
|---|-----|
| C1 | This directory only. Grep `UniswapV4CurveQuadStableSwapHookDFPkg` and this package deploy helpers. **Do not** touch Balancer quad or SE Curve quad unless that grep hits them. |
| C2 | Gold S2 / S9 / S12 / S19 / S21–S26 / S35 / S47–S57 with `UniswapV4CurveQuadStableSwapHook*` names. |
| C3 | Do not reopen amp, lpFeePips, rate providers, 4-token binding, salt, flags, `PRODUCT_ID`. |
| C4 | Init selectors: gold S58 (exactly 6). |
| C5 | Finalize requires all six **product** keys live. Extra fee/tick variants do not count. |
| C6 | TestBase: `deployPair` for each of the six product pairs + finalize after `deployHook`. `_deployBootstrapOnly` for doorless deploy tests. |

## 3. Files

`IUniswapV4CurveQuadStableSwapHookInit.sol`, BeforeInitializeLib, InitTarget, InitFacet, DFPkg inherit, Repo flag at end, PairPoolLib without bulk ensure, HooksTarget → lib, TestBase helper, package interface `+ productionFacetCuts()`. Product hook interface unchanged.

## 4. Tests / docs / DoD

Gold matrix with six doors and `ProductDoorsNotLive` on 0 and 5 doors. Existing product specs via S42 helper. Patch product/refactor PRD text that says deploy/`postDeploy`/`ensurePairPools` always inits all six. No `via_ir`. No SE Curve edits.
