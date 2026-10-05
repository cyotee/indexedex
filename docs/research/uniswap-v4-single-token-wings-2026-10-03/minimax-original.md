# MiniMax M3 — single-token wings design, independent first pass

**Date:** 2026-10-03. **Round:** follow-up wing-design council. **Scope:** preserve autonomous scalar deposit/withdraw on Hookless SE without an exploratory sizing loop, accepting one-sided out-of-range concentrated wings + later consolidation. Independent first pass; no peer originals, reviews, synthesis, or replacement originals read in this round. Research only; no implementation, no delegation, no shell/test/deploy/config edits. CLAUDE.md, the Hookless PRD, the implementation plan, and the Orbital PRD with held-rate addendum D60 are read directly. Charm / Alpha / Arrakis / Gamma are primary-source leads only.

## 1. The search-free scalar deposit problem, after the human correction

The owner now mandates: **scalar entry AND exit must remain meaningful autonomous SE/SY/buffered-pool capabilities.** The earlier basket-only recommendation in the prior round is therefore not a final product. Full-range-only placement is relaxed for this investigation. Two clarifications required by the prompt:

- A **bounded tick traversal** for an already-sized swap is not a sizing search.
- A **bounded set of positions** (e.g., a fixed maximum position count iterated by `for (uint256 i; i < N; ++i)`) is not a sizing search either, provided `N` is bounded and explicit. Eight interpolation attempts are not eight total probes; the loops continue.

The owner's hint is: one-sided out-of-range wings (a token0-only range below current tick, or a token1-only range above current tick), with a separate management process that consolidates wings that have crossed into range into a single double-sided core. This is a fundamentally different family from the prior `Planner._composition` 32-probe binary search (`UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108`), because **a one-sided out-of-range concentrated liquidity position has a closed-form liquidity**: given `x` of token0 and a tick range `(a, b)` with `b ≤ currentTick`, `l = LiquidityAmounts.getLiquidityForAmount0(sqrtPriceA, sqrtPriceB, x)` is one arithmetic step (v4-core `LiquidityAmounts.getLiquidityForAmount0`, Context7 `/uniswap/v4-core`, accessed 2026-10-03). The search is gone.

## 2. Ranked designs

1. **Rank 1 — One-sided out-of-range wings + bounded consolidation.** Adopt. Each single-token deposit places a new one-sided concentrated wing with caller-supplied (or deterministic-by-caller+nothing) salt; wing liquidity is closed-form; shares are pro-rata. Management consolidates in-range wings (bounded set, e.g., 64 per call) into a double-sided core. Single-token withdrawal burns shares and redeems pro-rata across the core and wings. No binary search on the user-op path. Tick spacing alignment is deterministic.
2. **Rank 2 — Local-inventory-first then later wing placement.** Caller's token sits in the vault's free sleeve until a management pass places it into a wing on the next valid tick. Withdrawal may take from sleeve first. Same wing model but deferred placement. Slightly worse UX (single-token entry does not move into the pool until the next management pass) but reduces active state changes. Equivalent search-freeness.
3. **Rank 3 — Properly specified internal market (constant-product against holders).** Per the prior Astra Rank 1 / Grok replacement Rank 2. Search-free but introduces an internal market against holders; a deposit buys the cheap internal leg and the redemption side faces sleeve cover only. Cross-market objections stand; record as a viable fallback if Rank 1 cannot satisfy Orbital.
4. **Rank 4 — Controlled valuation admission (oracle / TWAP / NAV).** Rejected as primary. Same-pool NAV is manipulable in one transaction. TWAP adds staleness risk; oracle governance is a separate product decision. Charm's "range orders can only be manipulated higher" comment covers its **proportional dual** deposit, not single-sided NAV.
5. **Rank 5 — Restricted analytic conversion (the "one-step closed-form composition" I previously proposed).** Rejected. The on-chain idle single-token `quoteTransition(DepositExactIn, …)` path is `_inventoryDeposit → Planner._composition` (`InQueryTarget.sol:163–178`), which is a 32-probe binary search. There is no on-chain closed form for the user-supplied-input sizing problem because the post-swap incumbent ratio `B_i'(x)` is path-dependent across tick boundaries.

## 3. Wing model — definitions, equations, conservation

State. `W` is a finite, bounded set of one-sided wings. Each wing `w ∈ W` carries:

- `tickLower_w`, `tickUpper_w` (rounded to multiples of `key.tickSpacing`).
- `salt_w` (bytes32; caller-supplied or deterministic from `(caller, nonce, tokenIn, block.timestamp / rebalanceWindow)`).
- `liquidity_w` (uint128).
- `direction_w ∈ {Below, Above}`: `Below` means `tickUpper_w ≤ currentTick` (wing holds token0 only); `Above` means `tickLower_w ≥ currentTick` (wing holds token1 only).
- An in-range wing satisfies `tickLower_w ≤ currentTick < tickUpper_w` and is the consolidation candidate.

Per-wing token composition (v4-core `LiquidityAmounts.getAmountsForLiquidity`):

```
Below wing (token0-only at currentTick ≥ tickUpper):
  D0_w = getAmount0ForLiquidity(sqrtPriceA, sqrtPriceB, l_w)
  D1_w = 0
In-range wing (a ≤ currentTick < b):
  D0_w = getAmount0ForLiquidity(sqrtPriceX96, sqrtPriceB, l_w)
  D1_w = getAmount1ForLiquidity(sqrtPriceA, sqrtPriceX96, l_w)
Above wing (token1-only at currentTick ≤ tickLower):
  D0_w = 0
  D1_w = getAmount1ForLiquidity(sqrtPriceA, sqrtPriceB, l_w)
```

Vault total deployed:
```
D_total0 = sum over w of D0_w      (out-of-range wings contribute only the deposited side)
D_total1 = sum over w of D1_w
F0, F1 = free sleeve (untouched by wing deposit; the deposit went directly into a wing, not into F)
E0, E1 = uncollected fees (per-wing checkpoints; sum)
B0 = D_total0 + F0 + E0
B1 = D_total1 + F1 + E1
S = totalShares
```

Conservation: `B0, B1` reconcile to actual vault ERC20 balances after settlement (`_syncVaultReserves` analog, `Common.sol:514–524`).

**Single-token deposit** (token0, `amountIn > 0`, idle, manager not in-session):
```
1. Determine target tick range:
   chosenLower = (currentTick / tickSpacing) * tickSpacing  // floor to spacing
   chosenUpper = chosenLower + tickSpacing
   if (currentTick - chosenLower >= minWingGap) {
     tickLower_w = chosenLower
     tickUpper_w = chosenUpper       // one-tick wing
   } else ... // widen to maintain minWingGap
2. l_w = getLiquidityForAmount0(sqrtPriceA, sqrtPriceB, amountIn)   // single mulDiv
   require l_w <= type(uint128).max
3. Caller credit: push (transferFrom) or pretransfer (LocalCreditLib.available)
4. modifyLiquidity with salt_w
5. m = floor(S * amountIn / (B0 + amountIn))    // proportional; reverts if m == 0
6. ERC20 mint recipient, m shares
7. _syncVaultReserves; emit event
```

Single-token deposit (token1, symmetric): `tickLower = floor(tick / spacing) * spacing`, `tickUpper = tickLower + spacing` for the **above** wing; `l_w = getLiquidityForAmount1(sqrtPriceA, sqrtPriceB, amountIn)`. Same proportional mint `m = floor(S * amountIn / (B1 + amountIn))`.

**No adaptive loop, no refinement probe.** Tick spacing rounding is deterministic. Liquidity is closed form. Shares are closed form.

**Single-token withdrawal** (burn `r > 0` shares for token0 output, idle):
```
1. Compute pro-rata withdrawal per wing:
   for each w in W (bounded iteration, ≤ MAX_WINGS):
     l_withdraw_w = floor(l_w * r / S)
     if l_withdraw_w == 0: continue
     // call decreaseLiquidity(w, l_withdraw_w)
     // proceeds: token0 portion only for Below wings
2. Pay from sleeve F0 first if sufficient; otherwise pay from wing proceeds.
3. Symmetric for token1; opposing entitlement from in-range wings is swapped forward (one bounded forward simulation per already-sized amount).
4. _syncVaultReserves
```

**No sizing search on withdrawal either.** The amount to redeem is determined by `r/S`; per-wing withdrawal is pro-rata; sleeve cover check is exact. The forward swap of the opposing entitlement is **bounded traversal of an already-sized swap** (≤ 64 core steps; not a sizing search), consistent with the prompt's exception.

**Management consolidation** (permissionless, called by anyone):
```
1. Iterate W (bounded; stop at MAX_CONSOLIDATE_PER_CALL = 64).
2. For each w with tickLower_w ≤ currentTick < tickUpper_w:
   a. decreaseLiquidity(w, l_w)    // collect both tokens
   b. Wing proceeds go to sleeve F0/F1.
   c. Optionally: refund any residual dust to a "burn" address or book as `F` retention.
3. After all in-range wings consolidated, attempt a closed-form core addition:
   budget_i = (F_i + E_i collected) - target_i   // per sleeve policy
   L_core_target = min(getLiquidityForAmounts(q, a, b, budget_0, 0),
                       getLiquidityForAmounts(q, a, b, 0, budget_1))
   modifyLiquidity(core_salt, L_core_target)   // one-step; no loop
4. _syncVaultReserves
```

The core's `(tickLower, tickUpper)` is fixed at deploy-time as a sensible wide range around current tick (e.g., 80% to 120% of currentTick, rounded to spacing). The vault may also keep an "always-on" full-range core position with bounded liquidity that captures fees regardless. Re-use existing `_tryTargetLiquidity` (`InventoryMath.sol:216–245`) and the 3-candidate stencil in `_closedPlacement` (`TransitionPlanner.sol:49–67`).

## 4. State domains

**Empty book (`S == 0`):** no wings allowed; single-token deposit reverts `InvalidRoute`. First mint must be **dual-token proportional** (F0 unchanged, `StandardExchangeConstantProduct.sol:30–35`; dead-sink minimum; no unilateral activation).

**One-sided book (only token0 wings, `B1 == 0`):** token0 deposits continue; token1 deposits revert `InvalidRoute`. Token0 withdrawal may pay from sleeve or from `D_total0` after collecting pro-rata.

**In-range wings only (`tickLower_w ≤ currentTick < tickUpper_w`):** each in-range wing holds both tokens. Withdrawal takes both sides; the opposing entitlement is swapped forward (bounded traversal, not search).

**Already-unlocked (PoolManager in-session):** `UniswapV4Exchange_PoolManagerInteractionBlocked` (`Common.sol:354–358`) for any idle route. Blocked single-token entries use F1 linear (`StandardExchangeConstantProduct.sol:78–96`, blocked mint only); blocked single-token exits use F2 (`StandardExchangeConstantProduct.sol:98–110`). Wings are not placed while in-session.

**Out-of-range wings only (`tickUpper_w ≤ currentTick` for token0, etc.):** each wing holds only the deposited token; value is exactly the deposited amount. Management consolidation collects no wings. The vault's `B_i` for `i ≠ direction_w` is zero, and `D_i` is the sum of `D0_w` for token0 wings (zero for token1).

**Mixed:** bookkeeping handles per-wing token contributions separately and sums. The 1 bp alignment test `10000 * m * B_i >= 9999 * S * C_i` (`ProtectionMath.sol:105–110`) is applied at deposit time, with `B_i` taken **before** the deposit (the depositor pays the existing share price, not a marked-up one).

## 5. Sleeve, blocked cover, fees, protections

- **Sleeve target**: `target_i = floor((D_total_i + F_i) * p / (1e18 + p))` (existing PRD §5; `InventoryMath.sol:50–56`). Live `p` from the VaultFeeOracle. Default 0.20. Deadband `max(absoluteFloor_i, target_i / 20)`.
- **Blocked cover**: blocked operations pay only from actual local `F_i` of the requested currency (`Common.sol:626–632, 1146–1150`; `_previewZapOutExactIn` `InBase.sol:106–124`). Wings are not usable while blocked; `E_i` is not a local-cover source.
- **Fees**: own LP fees accrue per wing as `floor((feeGrowthInsideDelta_i) * l_w / 2^128)` and are collected per-wing via a poke in `decreaseLiquidity` (existing semantics; `Common.sol:556–576`). `E → F` once per consolidation pass. Protocol fee and Pons hook charge are external; this design does not introduce new fees.
- **Protections** (D20): 25/50/10/1 bp fixed constants (`Common.sol:980–984`). **No relaxation.** Single-token deposit uses 1 bp alignment (`Protection._aligned:105–111`) and 50 bp composition-impact **on the core position's price** (compositions now happen as consolidations, not on the deposit path). Consolidation uses 25 bp rebalance impact bound.
- **Wing-min size**: require `amountIn ≥ MIN_DEPOSIT_WAD` (configurable per deployment; default 1e6 wei) to prevent dust spam.

## 6. Orbital and SY consequences

Orbital's preview paths today call Hookless's `quoteTransition(DepositExactIn, …)` which currently invokes `Planner._composition`. Under the wing model, that preview returns a deterministic `(sharesOut, priceAfterX96)` from the closed-form wing-placement calculation. Preview == execution bitwise.

- **Replaced `quoteTransition(DepositExactIn, …)`**: now returns wing-placement shares; preview == execution.
- **`quoteTransition(RedeemExactIn, shares)`**: now computes per-wing redemption `l_withdraw_w = floor(l_w * shares / S)`, sleeve cover check, and bounded forward swap of opposing entitlement.
- **`quoteTransition(ReceiveShares, amount)` / `quoteTransition(RateProvider valuation)`**: unchanged.
- **Pons**: Pons family implementation does not adopt wings; its F4 hook charge `h(n)` (`ponsFamily/v2/hooks/PonsV2MemeHook.sol:480–524`) continues to apply to its external swaps. Same D22 separation; no merger.

**Outer Orbital sizing loops that remain**:
- `OUniswapV4StandardExchangeOrbitalBufferHookMath.zapSplitWad` (`.../Math.sol:321–364`) — 64-probe binary search for sphere residual. **Out of scope** for this H round; flagged.
- `OExitQuoteLib._faceForClaim` (`.../ExitQuoteLib.sol:347–374`) — up to 8-probe bisection. **Out of scope.**
- `OClaimLib._invertBufferForEffective` (`.../ClaimLib.sol:250–275`) — up to 64-expand + 8-bisection. **Out of scope.**
- `OExitQuoteLib.planDeposit` (`.../ExitQuoteLib.sol:241–330`) — orchestrates the above. **Out of scope.**
- `OInQueryTarget.quoteExternalExchange` (`.../HInQueryTarget.sol:70–85`) — calls `_inventoryRebalance → Planner._maintenance`. **Removed** under the wing model: the SE no longer runs a maintenance swap; consolidation is its own permissionless call.

The wing design makes Hookless **scalar-search-free on deposit and redemption** at the user-op path. **End-to-end Orbital search-freedom requires a separate Orbital-side redesign** (eliminating `zapSplitWad`, `_faceForClaim`, `_invertBufferForEffective`) — flagged as **not solved here**.

## 7. Manipulation, donation, fee-ownership, rounding, same-pool incumbent-repricing

- **Donation**: pretransfer law unchanged (PRD §11; `Common.sol:900–922, 941–949`). Wing deposit credits exactly `amountIn`. Excess unbooked surplus cannot fabricate credit.
- **Sandwich / MEV on wing placement**: a single-token deposit is placed at the **current** tick boundary (or a deterministic caller-supplied boundary). An attacker manipulating the price within a single block can force the wing to be in-range immediately and the depositor to receive a worse effective ratio. The 50 bp composition-impact bound on the pool price, plus per-call `minShares`, is the defense; it is the same defense as today.
- **Fee ownership**: fees accrue per-wing via the existing `feeGrowthInside` checkpoint (`Common.sol:556–576`). On consolidation, fees collected from a wing go to the sleeve `F_i`. They do not double-count with the core's accrual because each wing has its own checkpoint and the core has its own. Accounting must avoid double-counting the same `feeGrowthInside` window across multiple wings.
- **Rounding**: liquidity `l_w = getLiquidityForAmount*` uses `FullMath.mulDiv` with deterministic flooring. Per-wing rounding dust is recorded and either retained (default) or zeroed on consolidation.
- **Same-pool incumbent repricing**: a single-token deposit does not move pool price (no swap; only a `modifyLiquidity` add). The wing is out-of-range; the core is unaffected. **No incumbent repricing at deposit time.** Repricing happens only when wings cross into range and are consolidated, **then** when the core absorbs the consolidated tokens. Belongs to incumbents at that moment.
- **Wing that never crosses range**: the deposited token is locked in that wing's liquidity until someone calls `decreaseLiquidity`. Holders cannot redeem token0 from a Below wing whose deposit was token0 (the wing already holds token0) — they hold proportional share of it. This is intended.
- **Position count cap**: enforce `MAX_WINGS = 256` (configurable per deployment; hard ceiling). Above the cap, single-token deposits revert `WingCapReached`. Consolidation reduces the count; old wings are deleted when their salt is consumed.
- **Keeper failure for consolidation**: if consolidation is permissionless and the keeper fails, wings still earn their own LP fees in their tick range. Crossed wings continue to earn dual-token fees and value, but the core position is not augmented. This is no worse than today's no-maintenance scenario.
- **Wing consolidation cost**: caller of consolidation pays the gas. No incentive. If a keeper incentive is desired, it's a separate owner decision (a separate oracle-driven subsidy, not a new fee on the vault).

## 8. PRD amendments (D1–D31)

- **D1**: amend — `exchangeIn(token, amount)` idle places a wing at a deterministic tick boundary (caller-supplied salt) and mints proportional shares; idle single-token path is preserved.
- **D2**: amend — composition-swap funding rule vacuous for deposits (no swap on the deposit path); retain for any external maintenance operation if retained at all.
- **D4**: amend — order is credit → place wing → mint → sync. No composition swap, no post-swap alignment, no caller-supplied sizing probe.
- **D5**: amend — "post-swap whole-book ratio" no longer applies at deposit. Pool repricing belongs to incumbents only when consolidations or external maintenance move the core.
- **D6**: amend — proportional issuance is now the wing-deposit mint formula `m = floor(S * amountIn / (B + amountIn))`.
- **D7 / D8**: amend — wing deposit does not retain sleeve residuals at deposit time (the deposit went directly to a wing, not to `F`); sleeve residuals come from consolidations and fee collection.
- **D17 / D18 / D19**: amend — composition exact-output and interleaving are not relevant on the wing deposit path. Direct user trades against the pool are not part of the SE's SE/SY surface; they remain pool-level (the user supplies tokenIn to the pool, not the vault).
- **D20**: amend — 50 bp composition-impact bound vacuous on wing deposit (no swap). 25 bp on consolidation impact, 10 bp execution shortfall on any external swap, 1 bp on wing-deposit rounding loss.
- **D25**: unchanged — fixed constants, no setters.
- **D22, D26, D28, D29**: unchanged — Pons family separation; fixed Pons hook; no H→P dispatcher; Orbit-al held-rate addendum D60 remains.
- **D27, D30**: refresh for every changed route (preview == execution bitwise).
- **D21**: amend — the existing 1 bp rho metric applies to **post-consolidation** core composition, not to wing deposit. Wings themselves may be arbitrarily imbalanced (one-sided by design); the vault's overall `rho` is the post-consolidation metric.

**New explicit owner decisions required**:
- `MAX_WINGS` ceiling (recommended 256; configurable per deployment).
- `MIN_DEPOSIT_WAD` minimum per wing (recommended 1e6 wei; configurable per deployment).
- Whether consolidation is permissionless-only or by selected delegate.
- Whether the owner wants per-caller or global wing salt derivation (recommend deterministic per-caller+nothing).
- Whether wings can be merged with the core in a single tx (single-tick core vs always-out-of-range wings) — recommend always-out-of-range wings; core is a separate position.

## 9. Acceptance, benchmark, and adversarial plan (later, not this round)

1. **Route matrix parity**: for every matrix cell in the prior PRD plan §4, preview == execution at the integer level. New cells: wing deposit (R-single-token), wing redemption (R-single-token-exit), consolidation (R-consolidate).
2. **Conservation**: `B_i` after a wing deposit equals the pre-deposit `B_i + amountIn_i`; total wings' value at spot reconciles to free sleeve + core value; `E` counted once.
3. **Search counters zero on deposit/redeem/quote paths.** Wing deposit must run no `while`-loop probes; redemption must run no `while`-loop probes. **Consolidation is bounded**: at most `MAX_CONSOLIDATE_PER_CALL` wings per call; user-ops must not call consolidation.
4. **Position count cap**: deposits revert above `MAX_WINGS`; consolidation reduces count.
5. **Dust protection**: deposits below `MIN_DEPOSIT_WAD` revert.
6. **Tick-spacing alignment**: every wing boundary is a multiple of `tickSpacing`. Test on extreme ticks near `MIN_TICK` / `MAX_TICK`.
7. **In-range detection**: consolidation iterates only wings where `tickLower_w ≤ currentTick < tickUpper_w`; out-of-range wings are skipped.
8. **Adversarial**: same-tx price manipulation against the wing (sandwich); donation / re-credit negatives; malicious dust spam; keeper failure (consolidation not called for N blocks — verify wings still earn fees in their own range); reverse manipulation (push price through the wing in one direction); fee accrual non-double-count.
9. **Orbital parity**: assert `quoteTransition(DepositExactIn, amount)` returns identical shares to execution across all supported token directions, decimal combinations, fee-oracle sleeves (`p = 0, 0.2, 1`).
10. **No `viaIR`**; hermetic profile only; `forge build` then `forge test`.
11. **No measured gas claim in this round.**

## 10. Risk register (top items)

1. **Position count growth** — bounded by `MAX_WINGS`; mitigation: ceiling + revert.
2. **Keeper failure for consolidation** — wings still earn their own fees; mitigation: permissionless events.
4. **Wing that never crosses range** — deposited token locked; mitigation: holder can still redeem proportional share of the wing's token.
5. **Fee-double-count across wings** — bookkeeping discipline: each wing has its own checkpoint; `E → F` once per wing collection.
6. **Sandwich on deposit** — pool price movement within a tx could make the wing in-range immediately at a worse price; mitigation: `minShares` parameter + 50 bp composition-impact bound on the post-deposit pool price (no change).
7. **Cross-family / Orbital outer search** — flagged; requires separate Orbital-side redesign.
8. **Pons separation** — unchanged.
9. **Native SY** — `NativeStandardYieldTarget.sol:20–77` semantics preserved.

## 11. Evidence, confidence, gaps

| Source | Path:line | Used for |
|---|---|---|
| Composition binary search | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108` | Replaced; no longer in user-op path |
| Wing liquidity closed form | `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol` (Context7 upstream `test/utils/LiquidityAmounts.sol`) | `getLiquidityForAmount0/1` |
| Sleeve policy | `.../InventoryMath.sol:50–56` | target / deadband |
| Closed placement | `.../TransitionPlanner.sol:49–67` | 3-candidate stencil |
| 25/50/10/1 bp constants | `.../Common.sol:980–984` | Fixed protections |
| `_executeZapInDeposit` | `.../InBase.sol:277–304` | Replaced by wing deposit |
| `_inventoryDeposit` | `.../InQueryTarget.sol:163–178` | Calls `Planner._composition`; replaced |
| Pretransfer law | `.../Common.sol:900–922, 941–949` | Unchanged |
| Orbital sphere / B6 / held-rate | `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828–835` (D60), `:1–200` (binding) | Family separation + held-rate addendum |
| Orbital outer searches | `.../Math.sol:321–364` (zapSplitWad 64); `.../ExitQuoteLib.sol:347–374` (_faceForClaim 8); `.../ClaimLib.sol:250–275` (_invertBufferForEffective 64+8) | Out of scope for H |
| PRD | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` | Product authority |
| Plan | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` | Engineering specification baseline |

Primary upstream (Context7; first-party):
- Uniswap v4 Core `LiquidityAmounts.getLiquidityForAmount0/1` (closed-form); `getAmountsForLiquidity` (closed-form per active range). Source: `uniswap/v4-core/test/utils/LiquidityAmounts.sol`.
- Uniswap v4 Core `modifyLiquidity` returns principal-only delta; `Position.update` accrues fees per liquidity unit; out-of-range positions contribute only the side held. Source: `uniswap/v4-core/src/libraries/Pool.sol`, `uniswap/v4-core/src/libraries/Position.sol`.

External leads (not relied on as proof):
- Charm Alpha / Alpha Pro: three positions (full-range, base, limit), with `rebalance()` withdrawing and redepositing all; keeper-called; `period` enforces minimum interval; `maxTwapDeviation` enforces TWAP discipline. Source: https://learn.charm.fi/charm-finance/alpha-pro/how-it-works and https://github.com/charmfinance/alpha-vaults-contracts/blob/main/contracts/AlphaStrategy.sol (accessed 2026-10-03). **Charm uses concentrated ranges centred on spot, not out-of-range wings.** Different family. Useful precedent for TWAP guards and tick-spacing alignment.
- Arrakis V2 / Gamma: similar pattern with one-sided range orders + auto-rebalance. **Not primary-read this round; leads only.**

Local compiler baseline: Solidity 0.8.35, optimizer runs 1, `viaIR` disabled (PRD §15; CLAUDE.md §7).

Access date: 2026-10-03 (this round).

Confidence: **high** in the closed-form of `getLiquidityForAmount0/1`, in the bounded-iteration guarantee of consolidation, and in the search-freeness of the deposit/redemption user-op path. **Medium** in end-to-end integer workflow feasibility (multiple wings, fee-growth bookkeeping, salt management, Orbital preview parity) until the §9 suites run. **Lower** in autonomous Orbital-callable search-freedom for Orbital's sphere composition (`zapSplitWad`, `_faceForClaim`, `_invertBufferForEffective`) — out of scope for this round, requires separate Orbital-side redesign.

**Gaps (from prior round, unchanged):**
- `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` — directory does not exist in this revision; not retried.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` — directory does not exist in this revision; not retried.

**Not measured**: gas. PRD/council explicitly directs no fresh measurement in this round.

**No consensus claimed.** This is an independent first-pass original; peer originals, replacement originals, status reports, and synthesis were not read or used in this round. Retained session history is acknowledged; it is not independent memory erasure.

**Stop for human selection; no implementation authorized.** The owner must select Rank 1 (or a recorded alternative), approve the D1–D31 amendments, set the new explicit owner-decision parameters (`MAX_WINGS`, `MIN_DEPOSIT_WAD`, salt policy, core range policy, consolidation delegate policy), and authorize a later implementation round before any code, test, deployment, configuration, or deletion work begins.