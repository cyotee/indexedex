# Grok — Uni V4 SE sleeve zap-in composition (independent first pass)

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). **Status:** research only; not an implementation authorization.  
**Saved path:** `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/grok-original.md`

## Question

Repeated single-token deposits on the Uniswap V4 Standard Exchange stay undeployed because the sleeve lacks a proportional counter-token. The human proposes that idle zap-in swap into a proportional distribution and deploy, while keeping the policy liquidity sleeve for PoolManager-blocked operations. That proposal is a **change**. It is not current law.

## Authority

Current release law is DETF alignment **D57–D59 / §24.7.1** and funded-staking plan **§7.4** (`contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` lines 97–99, 1153–1161; plan lines 370–376). Those require full-range books, complete-book accounting (deployed + sleeve + fees once), **both tokens to activate**, and **subsequent single-token deposits plus funded sleeve ops while the pool cannot be modified**.

Package law that this proposal must explicitly supersede, where it conflicts:

| Rule | Location | What it locks |
|---|---|---|
| Buffer **D27** | local-buffer PRD §3; `InBase` 268–314 | Idle deposit mints first, then deploys excess only. No composition swap. |
| Buffer **D28** | local-buffer PRD D28; `Common` 731–732, 759–805 | Rebalance is add/remove only. No token0↔token1 swap. |
| Full-range **D32** | full-range PRD line 143 | In-range `getLiquidityForAmounts` binds on the scarce token. Leftover stays free. No swap to absorb it. |
| Full-range **D33** | full-range PRD line 144 | In-range L may stay 0 until the other currency arrives. |
| Buffer **D24** | local-buffer PRD D24; `InBase` 252–265 | Preview ignores rebalance. Safe only if rebalance does not change the user’s share math. |

**Do not supersede D59** with this request. Empty-supply one-sided activation still reverts (`Common._sharesOutForDeposit` 693–695; tests `test_FR5_*`). A swap-to-bootstrap would be a separate D59 carve-out. **Do not supersede D1/D2/D4/D18** (blocked path never unlocks; sleeve pay-or-revert). **Do not redefine D17**: `targetFree_i = total_i * liquidPct / 1e18` (`Common` 349–350), a fraction of **total** per token, not of deployed.

## Root cause (fact)

1. **Naming.** Uniswap idle = PoolManager **locked**. In-session = **unlocked**. Nested `unlock` reverts `AlreadyUnlocked`. Vendored port: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` 55–64 (`pragma 0.8.24`, comment “ported … 0.8.30”). Upstream `main` (fetched 2026-09-26) is the same control flow under Solidity 0.8.26: https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol . Product gate matches: `canOpenPoolManagerUnlock() := !isUnlocked` (`Common` 315–316). Docs: https://docs.uniswap.org/contracts/v4/concepts/PoolManager (access 2026-09-26). Context7 `/uniswap/v4-core`: `swap` and `modifyLiquidity` are legal only inside `unlockCallback`.
2. **Idle single zap-in does not swap.** `exchangeIn` pool-token→shares pulls then delegatecalls `executeZapInDeposit` (`InTarget` 63–67, 80–89). That mints against pre-deposit totals, then `_rebalanceLiquidReserveBestEffort` only if idle (`InBase` 273–314).
3. **Deploy cannot invent the other token.** `_deployExcessLiquidity` budgets excess free of each token and calls `LiquidityAmounts.getLiquidityForAmounts` (`Common` 822–844, 564–570). In range, liquidity is `min(L(amount0), L(amount1))` (vendored `LiquidityAmounts.sol` 66–73). Full-range ticks are `minUsableTick`/`maxUsableTick` (`Common` 1183–1186), so a tradable price is in range. Excess of one token and zero of the other yields **L = 0** and a no-op (`Common` 843–844).
4. **Repeated idle one-sided deposits therefore stack in the sleeve.** After a dual book at the oracle sleeve (type intent 20%): new deposit of token A raises `total_A` and `targetFree_A` by `pct * deposit`, so about `(1-pct)` of the deposit is excess A, while excess B stays ~0. That excess cannot be minted. **Inference, not a traced test:** `test_T1b` only asserts no refund (`LocalLiquidBuffer.t.sol` 153–162). `_assertFreeWithinDeadband` allows `total/4` and `total/2` slack (492–514), so it would not fail this skew.
5. **Blocked path is a different cause.** In-session deposit must not unlock (`InBase` 309–314; `test_T2` 165–179). It stays sleeve even if both tokens are present (`test_T12` 349–376). Later idle `rebalanceLiquidReserve` can deploy **only if both excesses already exist** (`test_T3` is dual; `test_T4f` 402–407 does not prove a one-sided donation deployed).

**Not the cause:** share math refusing single-token deposits after activation. Post-activation one-sided mint is required and implemented (`Common` 706–712; decimals `test_FR5` 208–211). The bug is **placement**, not issuance.

## Distinctions (normative for the PRD)

| Axis | Keep |
|---|---|
| PM idle (locked) vs in-session (unlocked) | Swap/deploy only when `canOpenPoolManagerUnlock()`. In-session: sleeve credit, mint, no unlock, no swap. |
| Sleeve fraction | Of **each token’s total** (free+deployed), live oracle read. Not “20% of deployed”, not a second knob. |
| Deposit composition vs public backlog rebalance | Compose **only the caller’s idle single-token zap-in excess**. Do not let permissionless `rebalanceLiquidReserve` swap incumbent sleeve, donations, or blocked backlog. |
| Bootstrap | Still dual-funded. One-sided `totalSupply==0` reverts and returns payment. |
| Single vs Multi | Fix single `IStandardExchangeIn` zap-in. Multi unbalanced join stays no-swap (full-range D45) unless a later decision supersedes it. |
| Native / WETH | Sleeve and share face stay WETH (`Common` 411–425, `_freeBalances` 332–334). Settlement may unwrap/wrap inside the callback (`_settleCurrency`/`_takeCurrency` 1096–1117). No native sleeve (buffer D26). PoolKey order, not numeric ERC-20 sort. |

## Safe product requirements (proposed)

**R1 — blocked unchanged.** In-session single and Multi deposits mint against the sleeve and emit `LocalDepositWhileBlocked`. Amount-out still sleeve-cover or `InsufficientLocalReserve`. Direct swap still reverts interaction-blocked.

**R2 — idle single zap-in composition, depositor pays.** After pull, if the managed/imported position is in range (or would be created in range) and excess of the deposited token cannot be consumed without the other token: swap **only incoming excess above the post-trade sleeve targets**, then mint shares on the **post-swap** book, then add liquidity with existing deploy math. Do not swap deployed inventory, the other token’s incumbent sleeve, or donations already on the diamond. `minSharesOut` binds the post-swap mint. If the quote cannot meet `minSharesOut` or a hard impact cap, **revert the zap-in**. Do not best-effort an unbounded swap (that would recreate the bug under sandwich and would socialize loss if mint-first).

**R3 — sleeve retained.** After composition, `targetFree_i` is still `total_i * livePct / 1e18`. Deploy only `free_i - targetFree_i` beyond the existing deadband. Do not sell the policy sleeve to buy the counter-token. Default type intent remains 20% WAD; vault override still wins. Stored 0 remains unset.

**R4 — no swap when one-sided mint already works.** If price is outside an imported range and `getLiquidityForAmounts` consumes the deposited token alone, deploy that excess without a swap.

**R5 — public rebalance stays D28.** `rebalanceLiquidReserve` remains add/remove, idle-only, no share mint. One-sided donations and blocked backlog may remain undeployed until a later **idle single zap-in of the short token** or an explicit future decision. That is intentional: a permissionless swap is a grief/sandwich on all holders.

**R6 — D59 bootstrap unchanged.** No swap-to-activate.

**R7 — accounting.** Composition changes token balances once. Fees collected into free on `modifyLiquidity` are not also counted as deployed. Share SoT remains free+deployed+uncollected fees (`_freeBalancesForShareMath` 626–630). No one-token NAV.

**R8 — native.** Composition uses the existing WETH unwrap/settle and take/wrap path. Previews and pulls use the ERC-20 face.

## Economics

- **Who pays.** Swap-before-mint charges LP fee, protocol fee, and price impact to the depositor’s share issuance. Existing holders keep their inventory and earn their share of the LP fee. **Inference:** mint-then-swap (current D27 order plus a new swap) would socialize that cost. Reject that order.
- **Self-trade.** The vault swaps against the same pool it LPs, including its own full-range L. Own-LP fee partially returns; protocol fee and external counterparties do not. If the vault is most of the pool, impact is large and a swap mostly rearranges its own position plus a protocol-fee leak. Cap impact; do not promise full deployment if the cap binds.
- **Ratio.** Target the **in-range mint ratio at the quoted post-swap price**, not vault `total_i` (that is Multi D44) and not a 50/50 value split. Sleeve targets are then applied per token on the new totals.
- **Not a rebalance of the book.** Incumbent skew is not corrected by someone else’s zap-in.

## Previews

D24 must be **narrowly superseded**. Preview of idle single zap-in must simulate the same composition quote and post-swap `_sharesOutForDeposit`, including hook fee adjustment (`UniswapV4QuoteService._adjustHookSwap`, already used on zap-out quotes, `Common` 1120–1134). It must **not** need to simulate the subsequent add, because add does not change shares. Blocked preview stays current (no swap). Execution and preview must agree on route: blocked = no swap; idle in-range shortfall = swap then mint; idle out-of-range consumable = mint then deploy, no swap.

## Security

- No nested `unlock`. Composition and deploy each open their own session or share one callback; either way a hook must not make this vault call `unlock`.
- `exchangeIn` is `nonReentrant` (`InTarget` 45). Acceptance must prove a hook `beforeSwap`/`afterSwap` callback into this vault reverts and does not mint mid-swap. Do not assume the Crane lock covers every facet until that test exists. **Gap:** lock slot sharing was not fully traced this pass.
- Current `_swapExactIn` uses `MIN/MAX` sqrt price (`Common` 669–670, 1015–1027). Composition **must not** copy that unbounded limit. Require a finite `sqrtPriceLimitX96` from the impact cap.
- Do not swap on donation-triggered public rebalance (donation already dilutes; `test_T4d`).
- FoT forbidden by repo token law. A fee-on-transfer pool token would desync swap settlement. Out of scope to support.
- Imported PositionManager path still cannot `unlock` while blocked (D15).

## Test acceptance (production-first; do not run in this pass)

Update tests that encode D28/D32 as “one-sided idle zap never deploys.” Keep blocked and bootstrap tests.

| ID | Required |
|---|---|
| A-Z1 | After dual activation, repeated idle single-token zap-ins of the same token increase deployed liquidity of **both** tokens, and each free balance stays within deadband of `total_i * pct` (tighter than today’s `total/4` slack). |
| A-Z2 | In-session repeated single deposits mint, do not unlock, do not swap, and stay in `localReserve`. |
| A-Z3 | Empty-supply one-sided zap still reverts `ZeroAmount` and returns payment. |
| A-Z4 | Preview == execution for idle composition and for blocked no-swap, including `minSharesOut` revert. |
| A-Z5 | Swap input ≤ caller’s excess above post-trade targets. Incumbent sleeve and deployed amounts are not the swap input. |
| A-Z6 | Public `rebalanceLiquidReserve` after a one-sided donation does not swap (pool price unchanged aside from unrelated fees). |
| A-Z7 | Native/WETH pool: sleeve is WETH `balanceOf`; composition settles native inside the callback; no residual ETH on the diamond. |
| A-Z8 | Imported out-of-range position deploys the consumable token with no swap. In-range import composes like managed full range. |
| A-Z9 | Hook reenter during composition reverts; no extra shares. Multi unbalanced join still does not swap. |
| A-Z10 | Impact cap: a manipulated spot that would exceed the cap reverts the zap-in rather than deploying at the manipulated ratio. |

Gold path remains `indexedexManager.deployUniswapV4StandardExchangeDFPkg` then `deployVault`. No mock PoolManager/vault/oracle as SUT.

## Unresolved (do not invent)

1. **Impact cap source:** spot bps vs bound TWAP vs user-supplied limit in addition to `minSharesOut`. Repo has a TWAP poke (`_pokeBoundPoolTwap`) but this pass did not verify it is manipulation-resistant enough to be the cap oracle.
2. **Backlog:** should a later idle op of *any* kind compose previously blocked one-sided deposits, or only a new idle zap-in of that same depositor? Recommendation: neither, until an explicit decision. Blocked deposits can sit above sleeve target indefinitely.
3. **Multi surplus and zap-out:** zap-out already swaps the other token (`InBase` 200–201). Extending composition to unbalanced Multi would supersede D45. Not requested.
4. **Same-unlock vs two unlocks** for swap then `modifyLiquidity`. Two unlocks are simpler and match current helpers; one unlock saves gas but widens the hook window. Either is acceptable if A-Z9 holds.
5. **Upstream pin.** Local PoolManager is a port, not a commit-pinned v4-core. Behavior relied on here (AlreadyUnlocked, in-range min liquidity) matches upstream `main` as fetched 2026-09-26, but a byte-level diff was not done.
6. **V3 / Slipstream.** D66 defers Slipstream. This PRD is V4 SE only. V3 has the same in-range binding math but a different locker; do not copy the requirement across.

## Recommendation

Accept the human change **only** as idle single-token zap-in composition: swap the caller’s excess to the in-range mint ratio, mint after the swap, deploy excess, keep the per-token total sleeve, and refuse the swap when PoolManager is in-session. Supersede buffer D27/D28/D24 and full-range D32/D33 **only on that path**. Leave D59, blocked sleeve law, public rebalance, and Multi no-swap in force.

## Confidence and gaps

**High** on the root cause (code path + `getLiquidityForAmounts` + D28/D32). **Medium** on the recommended swap-before-mint isolation (inference from share formulas; not executed). **Low** on TWAP-as-cap and on whether every facet shares one reentrancy slot.

Not done: forge tests, full reentrancy-slot trace, upstream commit diff, measurement of self-LP fee recycle. Context7 was used for v4-core unlock/swap/modifyLiquidity (`/uniswap/v4-core`) and Uniswap docs (`/uniswap/docs`); the docs query did not state the `min(L0,L1)` rule, so that rule is cited from vendored `LiquidityAmounts.sol` 66–73, which the vault actually calls.
