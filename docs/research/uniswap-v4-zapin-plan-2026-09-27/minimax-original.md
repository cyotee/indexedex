# Implementation Plan — Uniswap V4 FullSpread Standard Exchange Proportional Zap-In, Liquid Sleeve & Iterative Rebalancing — Original Plan (MiniMax M3)

Researcher: MiniMax M3 (independent first pass; no peer artifacts read)
Date: 2026-09-27
Target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/` (FullSpread)
Authorization: Research only. No code, shell, tests, delegation, or file edits. Output is a plan Markdown; the human moderator owns integration.

---

## 0. Bottom line and decision-complete summary

The PRD's three PRD-internal product changes resolve into six implementation work packages (WP-A through WP-F) inside the NEW FullSpread vault. Each has a stated support matrix, a stated closed-form derivation or an explicitly marked epistemic gap, an immutable protection constants table, an attribution rule, a stop/progress metric, a quote surface, an error/ABI/event/storage footprint, and a named in-scope file list. No decision is left to the implementer.

| WP | Title | Primary files |
|---|---|---|
| **A** | Sleeve target formula + proportionality/alignment band constants | `UniswapV4FullSpreadStandardExchangeVaultCommon.sol`, the LiquidReserve interface |
| **B** | Idle single-token zap-in: composition swap + ε budget | `UniswapV4FullSpreadStandardExchangeVaultInBase.sol` (rewrite `_executeZapInDeposit`), InQuery |
| **C** | Idle direct exact-output swap with interleaved holder-funded maintenance | `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol`, `UniswapV4FullSpreadStandardExchangeVaultOutBase.sol`, OutQuery, OutExecutionDelegate |
| **D** | Public rebalance: holder-funded swap branch + progress metric | `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` (extend `_rebalanceLiquidReserveInternal`) |
| **E** | Protection engine, immutable constants, telemetry events | `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` (new Protection section) |
| **F** | Tests + adversarial matrix | `test/foundry/vaults/standard/exchange/protocols/uniswap/v4/zapIn/`, `…/rebalance/`, `…/quoteCoherence/` |

Implementation order (serial): WP-E → WP-A → WP-B → WP-C → WP-D → WP-F. WP-E blocks nothing else; A blocks nothing; B/C/D depend only on E+A.

---

## 1. Support matrix (idle-only, exact-domain closed-form, hook-aware)

| Route | Idle support | Blocked support | Closed-form derivation | Hook-sensitive | Reject rule |
|---|---|---|---|---|---|
| **Direct swap-exact-in** (D58) — single pool token → other pool token, exact amountIn | supported (existing) — quote via `_quoteSwapIn` (Common:1103) | **revert** `PoolManagerInteractionBlocked` (no sleeve-funding swap) | yes (UniswapV4Quoter.quoteExactInput + Pons hook adjustment) | yes (Pons decode + `_adjustHookSwap`) | if hook not Pons-encoded, return vanilla amountOut — preview != execution under documented non-Pons hook |
| **Direct swap-exact-out** (D17/D18) — single pool token → other pool token, exact amountOut | supported (new in WP-C) — combined closed-form swap + holder-funded maintenance as one unlock | **revert** (CP_ACCT_PRD §6 R2: blocked path is sleeve-cover only; flip to `InvalidRoute` when proportionality requires a maintenance swap that the blocked path cannot perform — actual external behavior: blocked path emits `InvalidRoute` for the closed-form-required branch per PRD §6.4 / D19; existing `executeZapOutWithdrawal` blocked branch remains available for non-maintenance exact-out zap to single token) | yes (SqrtPriceMath inGivenOut → sqrtPriceAfterX96 + actualIn → after-swap T → targetFree → LiquidityAmounts.getLiquidityForAmounts, all in solidity pre-unlock) | partial — Pons decode gives the fixed hook fee; actual delta observed in unlockCallback. If observed delta exceeds pre-unlock closed-form by `>50bp`, revert with `ProtectionExceeded` (no iterative recovery) | `InvalidRoute` if pool is not vanilla or Pons-encoded |
| **Single-token deposit (caller-funded composition zap-in)** (D17/D2) — pool token → SE shares, with composition swap aligning post-swap ratio | supported (new in WP-B) | unsupported: `LocalDepositWhileBlocked` event already emitted by `executeZapInDeposit` (InBase:309–311) when blocked — composition step needs unlock | yes for the composition swap (SqrtPriceMath, then `getLiquidityForAmounts` for deployment) but the post-swap ratio computation itself depends on actual pool state at composition step; PREVIEW uses pre-swap state only; composition step is bounded-iteration (≤8) **for the ε verifier**, not as a substitute for closed-form derivation of shares/inputs | yes | blocked: `LocalDepositWhileBlocked` (existing) — explicitly NOT a closed-form-required branch; existing invariant-growth mints |
| **Dual-token deposit** (D45 / existing `_executeZapInDualDeposit`) | supported (existing) | unsupported (revert) | yes | existing hook adjustment | none |
| **Multi-token deposit (`exchangeInManyToOne`)** (D41) | supported (existing) | unsupported (revert) | yes | existing | none |
| **Share → single-token zap-out** | supported (existing) | supported (sleeve cover) | yes (existing `_previewZapOutWithdrawal` / `_executeFreeZapOutWithdrawalCore`) | existing | none |
| **Share → dual-token exit (`exchangeOutOneToMany`)** | supported (existing) | supported (sleeve cover) | yes | existing | none |
| **Exact-out share mint (D64 `_executeZapInMintExactOut`)** | supported (existing) | supported (sleeve cover) | yes (`StandardExchangeConstantProduct._amountInForShares` — ConstantProduct:78–96) | none currently | none |
| **Public rebalance** (D9, §8) | supported — add/remove AND holder-funded cross-token swap (new in WP-D) | **revert** `PoolManagerInteractionBlocked` | bounded solver for one repair step (4–8 iters; no iterative route reuse; honest no-op when below deadband) | yes | none — rebalance has no `InvalidRoute` because it is permissionless; it simply no-ops when no safe useful step exists |
| **Position import** | supported (existing) | supported | n/a | n/a | none |
| **Activation (initial mint)** | n/a (single supply, mulSqrt) | n/a | `StandardExchangeConstantProduct._initialShares` | none | none |
| **Native SY redemption (per package README; CP_ACCT_PRD §6 native SY)** | supported (existing internal-balance path) | supported | not in PRD scope | none | none |

Out-of-scope routes (preserve unchanged): no new one-token bootstrap, no tick recasting, no `mintClaim`/`buyClaim`/`redeemClaim` stands (`DETF alignment PRD` D53), no Universal Router migration, no in-place migration of OLD tree at `contracts/protocols/dexes/uniswap/v4/`.

---

## 2. Immutable protection constants (proposed table — concrete numbers)

All constants live as `internal constant` on a dedicated `ProtectionConfig` section in `UniswapV4FullSpreadStandardExchangeVaultCommon.sol`. They are NOT on storage, NOT admin-set, NOT exposed for mutation. PRD §9 says these are "not empirically proven safety guarantees" — the plan ships them as engineered defaults, with a separate owner task to tune if observed economics diverge.

| Symbol | Constant name | Value | Source | Used by |
|---|---|---:|---|---|
| `BP_DENOM` | one basis point in WAD | `100` (= `0.0001e18 / 1e18`) | derived | all tolerance helpers |
| `MAX_REBALANCE_TERMINAL_IMPACT_BP` | public rebalance terminal price impact | **25** | PRD §9 | D9 rebalance swap-impact check |
| `MAX_DEPOSIT_COMPOSITION_IMPACT_BP` | deposit-composition terminal price impact | **50** | PRD §9 | D2 composition swap-impact check |
| `MAX_EXECUTION_SHORTFALL_BP` | execution shortfall vs. fee-inclusive quote | **10** | PRD §9 | post-unlock realized vs quote |
| `MAX_ALIGNMENT_EPSILON_BP` | alignment and share-flooring loss | **1** | PRD §7 | D2 zap-in composition step |
| `REBALANCE_DEAD_BAND_BP_NUM` | relative dead-band, numerator | `5` (= 5%) | existing `LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18` (Common:319) | rebalance dead-band check |
| `COMPOSITION_MAX_ITERS` | bounded solver iterations for composition swap sizing | **8** | engineering default | composition step |
| `REPAIR_MAX_ITERS` | bounded solver iterations for rebalance holder-funded swap sizing | **8** | engineering default | rebalance swap step |
| `LP_FEE_DEVIATION_DENOM_BP` | own-LP-fee tolerance for attribution (denominator unit, see §4) | **1** (= 1bp of feeGrowth) | engineering default | ΔE attribution |
| `DEFAULT_SLOT0_PADDING` | machine epsilon used to round sqrt price after-effect checks up | `1` wei in `sqrtPriceX96` resolution | engineering | post-swap verification |

> **Concrete proposal carries the four PRD defaults verbatim** (25 / 50 / 10 / 1 bp). Composition solver bounded at 8 iterations (closed-form for the swap direction; the ε-check verification iterates). Holder-funded repair bounded at 8 iterations. Dead-band remains 5% relative (existing). Alignment ε is 1bp using the PRD's metric.

Configuration authority (PRD §14): **none.** The constants are immutable; tests verify only numeric behavior. PRD §9 explicitly excludes "implicit administrative ownership to otherwise immutable vaults." No fee-oracle overload of `liquidReservePercentage`. No new mutable storage for bp values.

---

## 3. Math, derivations and closed-form sourcing

### 3.1 Sleeve target formula (D3) — proposed upgrade

Current NEW code uses the simpler formula:

```text
targetFree_i = (total_i * p) / 1e18                  // (Common:358–360, line 749)
```

PRD §5 specifies:

```text
targetFree = floor(T * p / (1e18 + p))
```

**Derivation (algebraic equivalence at default):** at `p = 0.20e18`, `T = 100` ⇒
- Current `(100 * 0.20e18) / 1e18 = 20` ⇒ free = 20, deployed = 80 ⇒ `F/D = 0.25` (25%), not 20% ✗
- PRD `floor(100 * 0.20e18 / 1.20e18) = floor(16.66…) = 16` ⇒ free = 16, deployed = 84 ⇒ `F/D = 0.190` (~19%) ✓

At **operating** sleeve value `0.20e18`, the current simpler formula **violates PRD §5**. This is a real behavior change that needs a one-line `_targetFree` body update (and `actualLiquidReservePercentage` if it ever read the precise target — it reads `free/total`, which is a different ratio, so unaffected; see `LiquidReserveTarget:69–83`).

**Plan choice (engineering, decided):** adopt PRD §5 form **for the placement target** (`_targetFree` → `floor(T * p / 1e18 + p)`); keep `_absoluteFloor`; keep the `_shouldRebalanceToken` dead-band construction. The `p = 1e18` edge case is preserved (free = deployed when `p = 1e18`). The `(T * p) / 1e18` form used by `actualLiquidReservePercentage` (free/total) is a different ratio (current free share) and remains unchanged.

### 3.2 Composition swap sizing for idle single-token deposit (D2/§7)

Closed-form derivation for the composition step on a vanilla V4 pool (with Pons-style fixed-fee hook adjustment):

```text
Inputs:  amountIn (caller-provided, post-pull, post-`LocalCreditLib.available`), 
         current sqrtPriceX96, current liquidity L, tickLower = minUsableTick, tickUpper = maxUsableTick
         (full-range position), p (WAD), deployed0_reserve, deployed1_reserve.

Goal:    solve for swapAmountIn ≤ amountIn such that after a swap exact-input of swapAmountIn
         in the corresponding direction the post-swap reserves satisfy the sleeve policy
         (F'_i ≈ p × D'_i) and the whole-book ratio (post-swap reserves' ratio matches the 
         minted share's contribution ratio within ε).

Math (case study: caller deposits token1 single-sided on a `token0=token1?1:?0` position):

1. Compute (current_deployed0, current_deployed1) via _amountsForLiquidityAtPrice(sqrtPriceX96, tick, …).
2. Compute current T_i = current_deployed_i + current_free_i (the latter from balanceOf).
3. After composition swap (zeroForOne / !zeroForOne = …) of `swapAmountIn` of tokenIn:
      sqrtPriceAfterX96 from SqrtPriceMath inGiven = UniswapV4Quoter.quoteExactInput — already imported.
      fees from quote — `_adjustHookSwap(p.key, quote.amountOut, exactInput=true)`.
      new_deployed_i from `_amountsForLiquidityAtPrice(sqrtPriceAfterX96, …)` (L unchanged).
      new_free_i = T_i - new_deployed_i - <token amount sent to pool> + <token amount received from pool>.
4. Solve for `swapAmountIn` (bounded ≤ 8 iterations) such that 
      | new_free_i - targetFree_i | ≤ DEAD_BAND ✓ AND ε-alignment with the floor-min mint ≤ 1bp ✓.
5. Compose the deposit: 
      sharesOut = min(floor(S * C0 / B0), floor(S * C1 / B1))   // §6.3
      where C_i is the caller's full contribution (sleeve retained + deployed).

Closed form claim: the swap step is closed-form via UniswapV4Quoter.quoteExactInput; the
sizing for swapAmountIn towards targetFree is a bounded iteration (8) on a monotone 
single-variable function (targetFree = floor(T*p/(1e18+p)), T invariant under swap with
PV preserved). The ε verifier does not iterate into outer route structure — it is a 
per-call bounded check, not a route solver.
```

For non-Pons hooks: composition step is still bounded, but the pre-call quote cannot accurately predict the hook's effect on reserves → the post-swap reserves are empirical (read inside `unlockCallback`); we accept the conservative assumption and revert if `|actual - quote| > MAX_EXECUTION_SHORTFALL_BP` (10 bp). This is a documented gap with explicit handling, not an "iterative route-solving substitute."

### 3.3 Idle exact-output swap with interleaved holder-funded maintenance (D17/§6.4)

Closed-form derivation for the combined transition on a vanilla V4 pool (with Pons hook adjustment only):

```text
Inputs:  tokenIn, amountOut (exact), current sqrtPriceX96, current liquidity L, full-range ticks,
         p (WAD), current free_i, current deployed_i.

Goal:    one unlockCallback that (a) swaps exact amountOut for tokenIn, (b) deploys the
         resulting "too-much" sleeve inventory to bring free_i toward targetFree_i via
         add-liquidity only, with both arms measurable pre-unlock.

Math (case study: amountOut of token1 exact-output, paid in token0):

1. Pre-unlock:
   a. Compute amountInRequired via UniswapV4Quoter.quoteExactOutput + Pons hook adjustment
      (use existing _quoteSwapOut at Common:1095–1101).
   b. Compute post-swap sqrtPriceAfterX96 from the same quote (UniswapV4Quoter returns it).
      -> Invariant: sqrtPriceAfterX96 is closed-form-derived.
   c. Compute post-swap deployed_i (token0 decreases; token1 also shifts per SqrtPriceMath):
         deployed0_after = LiquidityAmounts.getAmount0ForLiquidity(sqrtP_a, sqrtP_after, L)
         deployed1_after = LiquidityAmounts.getAmount1ForLiquidity(sqrtP_after, sqrtP_b, L)
         feesAccrued0, feesAccrued1 from the returned balanceDelta + getFeeGrowthInside.
   d. Compute new T_i = (deployed0_after, deployed1_after) + (free0_after, free1_after),
      where free0_after = preFree0 + amountInRequired - 0 (no idle token0 leaves the vault
      unless we deploy it), free1_after = preFree1 - amountOut.
   e. Compute targetFree_i_post = floor(T_i_post * p / (1e18 + p)) for both tokens.
   f. Compute deployDelta0 = max(0, free0_after - targetFree0_post);
        deployDelta1 = max(0, free1_after - targetFree1_post).
      If both are 0, no maintenance needed (D12 satisfied pre-unlock).
      If exactly one of (deployDelta0, deployDelta1) is positive, the entire combined
      transition fits one add-liquidity of:
         liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(sqrtPriceAfter, sqrtP_a, sqrtP_b,
                                                                  deployDelta0, deployDelta1).
      If both are positive but capped by some token (the standard 
      `min(getLiquidityForAmount0, getLiquidityForAmount1) ≤ target`), the add uses the
      bounded liquidityDelta; residual sleeve-stays; the no-churn stop rule emits.

2. Execute in a single _executeUnlock:
   a. swap (zeroForOne, amountOut) — returns BalanceDelta.
   b. Observe actual inAmount (post-swap balance before settle).
   c. addLiquidity with precomputed liquidityDelta — returns BalanceDelta.
   d. Single settle of the combined delta; failures revert atomically.

3. Post-unlock verification:
   a. Compute epsilon_impact = max(P_after, P_before) / min(...) - 1 (PRD §9 metric).
      If epsilon_impact > MAX_REBALANCE_TERMINAL_IMPACT_BP, revert ProtectionExceeded.
   b. actualIn vs estimate shortfall ≤ MAX_EXECUTION_SHORTFALL_BP.

Closed-form claim: the pre-unlock computation produces a unique bounded (liquidityDelta,
inAmount, targetFree) triple via UnivariateSqrtPriceQuote + LiquidityAmounts. The execute
unlock executes both actions inside one unlockCallback session (already the vault's
_idiomatic pattern at Common:954-1013). The post-unlock verification is a 50bp impact cap
and 10bp shortfall cap; both are constants. There is no iterative search for "the right
size."

When the hook is not Pons-encoded, we REJECT before unlock with `InvalidRoute` per D19:
there is no closed-form for an arbitrary hook's effect on the deployed reserves.
```

**Epistemic gap explicit:** non-Pons hooks are unsupported for the combined idle exact-output+maintenance route. The PRD §10 disclaims hook certification; this plan restricts the combined-route support to vanilla + Pons-encoded pools. A separate implementation task (out of scope) can extend support as new hook families become closed-form-derivable.

### 3.4 Holder-funded public-rebalance swap (D9)

Closed-form: one direction at a time. From `_loadRebalanceSnap` (Common:744), the over-target token is selected (`excess_i = free_i - target_i > 0`; if both negatives, no repair needed; if one positive, swap enough of that token toward the side closer to its target). Quoted amount-in via `UniswapV4Quoter.quoteExactInput + Pons adjustment`. Bounded iteration (4–8) on `swapAmountIn` to converge `|free_i - target_i| ≤ max(absoluteFloor_i, target_i * 5%)`.

```text
Inputs:  free0, free1, deployed0, deployed1, sqrtPriceX96, p, absoluteFloor per token.

Goal:    one _executeUnlock with at most one zeroForOne swapExactIn toward repairing
         free_i → target_i.

Math:
1. Read live slot0 + deployed amounts.
2. Compute targetFree_i using the precise formula (§3.1) for each token.
3. Compute dead-band width_i = max(absoluteFloor_i, targetFree_i * 5%).
4. Token arm: pick arm with max((free_i - targetFree_i) - width_i, 0); swap that token
   toward the other side.
5. Swap-in amount = bounded iteration driving free_i to within dead-band; cap by
   free_i - absoluteFloor.
6. Re-snap; if both within dead-band, no-op (D12).
7. Settlement and tail-rebalance add/remove (existing best-effort).

If hook is not Pons-encoded and the vault has cross-token sleeve out of dead-band:
   quoted `swapAmountIn` is approximate; observed post-unlock `amountIn` differs;
   if |observed/quote - 1| > MAX_EXECUTION_SHORTFALL_BP, revert. Public rebalance
   inherits the same hook-support boundary as the swap-exact-out branch.
```

### 3.5 Share pricing under the new sleeve formula (Math consequence)

After WP-A, `_loadRebalanceSnap` returns `targetFree = floor(T * p / (1e18+p))`. The shared book math is unaffected — `_targetFree` is only consumed by `_shouldRebalanceToken` (Common:376) and `_loadRebalanceSnap` (Common:748–749). The proportional ownership math (`StandardExchangeConstantProduct._sharesForDeposit`, ConstantProduct:37–65) reads `reserve0Before` and `reserve1Before`, which are full vault reserves, not the sleeve target. Therefore PR §6.3 issuance math is invariant of WP-A.

### 3.6 Proportional ownership invariant: own-LP fees (attribution)

Owner-LP-fee accrual is a part of `F` → `D` plumbing: `_collectManagedFeesIfIdle` (Common:650–670) calls `modifyLiquidity` to collect, then `_executeRemoveLiquidity` to TAKE_PAIR. The collected fees enter `_freeBalances()` after settlement and are booked by `_syncVaultReserves` (Common:610–617). Per PRD §12 fourth item ("Complete economic backing") and PRD §5 ("Uncollected fees … are not spendable sleeve cover"), fees belong to share backing but do **not** reduce sleeve capacity until collected.

Attribution rule (locked): **own-LP fees accruing between collect events are tagged as `E`, not `F`** for the protected-domain sleeve-arithmetic:
```text
E_i = (getFeeGrowthInside_i(pool, range) - lastFeeGrowthInside) * L / (1 << 128)   // for share backing
F'_i = balanceOf_i (Free ERC-20 = deployed face — not deployed — minus accumulated E IF collected)
```
But for the **placement target**: `T = D + F` (NOT `D + F + E`); the sleeve target sits on placeable inventory, not on accrued fees. This is consistent with the PRD §5 third sentence ("`T = D + F` …`Uncollected fees remain in share backing but are not spendable sleeve cover`"). Fees only become `F` after `_collectManagedFeesIfIdle`. Implementation: `_targetFree` is computed against `D + F` where `F` is the live `balanceOf` only when no pending fee accrual is desired; or, more cleanly, only after a forced collection step in WP-B/C.

This avoids double-counting fees: fee-accrual → E (in share pricing only); fee-collection → moves from E to F via `_collectManagedFeesIfIdle` (already wired). The 1bp attribution epsilon (`MAX_ALIGNMENT_EPSILON_BP`) is computed at issuance against `S`, `C_i`, `B_i`; it does not need to subtract fee-accrual because accrual is excluded from `B_i` by §12.

**Plan resolution (decided):** call `_collectManagedFeesIfIdle` once at the start of every closed-form-required transition (idle deposit, idle exact-out swap, public rebalance swap step). Already wired for `executeZapInDeposit` (InBase:281) and `_executeDirectSwapIn` (InBase — no, not wired; `executeDirectSwapIn` does not collect pre-swap; we add it). This ensures `F` is the actually-collectable sleeve at start.

### 3.7 §7 alignment ε metric

PRD §7 formula:

```text
epsilon = max_i(1 - sharesOut * B_i / (S * C_i))   (no flooring yet)
```

with `epsilon <= 0.0001`. The plan adopts **the PRD's exact metric with share-flooring included** in `sharesOut = floor(...)`. The implementation is `max_i(S * C_i * 9999 / 10000 > sharesOut * B_i)` as the test (overflow-safe via `Math.mulDiv` capped to 512 bits). Zero denominators (`S == 0` first mint path, `B_i == 0`) revert `InvalidRoute` (not `ZeroAmount`) when the composition step required them.

The metric **is measured before flooring** so integer-floor loss cannot falsely satisfy it. After flooring, accept if max(gained from floor dust, 0) ≤ `MAX_ALIGNMENT_EPSILON_BP`. If exceeded, revert `AlignmentLossExceeded`. Bounded iteration (4 tries) to back off swapAmountIn until ε satisfied; if no iteration succeeds, revert `InvalidRoute`.

---

## 4. Attribution rule (caller-funded vs holder-funded) — locked decision

| Operation | Funded by | Booked to | Source/claim |
|---|---|---|---|
| Single-token deposit composition swap | **caller** | caller shares only | PRD D2 |
| Idle direct swap-exact-in | caller | caller shares only | existing; caller pays `amountIn` |
| Idle direct swap-exact-out | caller for `amountIn`, **holder** for the maintenance leg's sleeve→LP deploy | caller gets `amountOut`; maintenance's inventory adjustment is a holder-funded swap reducing free_i toward target_i | PRD D17 / §6.4 |
| Idle share→token zap-out (single) | caller | redeemer | existing |
| Idle share→dual exit | caller (proportional to shares) | redeemer | existing |
| Public rebalance swap | **holder** | vault book | PRD D9 / §8 |
| Owner-fee accrual during unlock | holder | share backing (E) | PRD §5 + §12 |
| Rebalance additive add-liquidity | holder | all shares | existing `_rebalanceLiquidReserveInternal` |
| Rebalance removal | holder | all shares | existing |
| Rebalance no-op | none | none | PRD §8 truthful no-op |

Decision: rebalance swap arms and exact-output maintenance deploy arms are **booked to the vault book** (not to a specific caller). Pretransfer-credit-required assets for rebalance swap never come from a caller (rebalance has no caller input). This forbids any future attempt to inflate `LocalCreditLib.available` by routing through `rebalanceLiquidReserve`.

---

## 5. Stop / progress metric for public rebalance (locked)

A repair step is "useful" (D12 / §8) when **both** of these change in the same direction:

1. Sleeve distance to target decreases for at least one token (after deducting dead-band width).
2. Total sleeve-deployed sum `T - |free - target_i|` does not increase.

A repair step is "no-churn" if it would flip the sign of `free_i - target_i` and the result is still inside dead-band. Such steps are skipped (PRD §8 honest no-op).

Pseudo-code (locked):

```solidity
function _isUsefulRepair(uint256 free0_before, uint256 free1_before,
                          uint256 target0_before, uint256 target1_before,
                          uint256 width0, uint256 width1,
                          uint256 free0_after,  uint256 free1_after,
                          uint256 target0_after, uint256 target1_after)
    internal pure returns (bool)
{
    if (!_insideBand(free0_after, target0_after, width0) ||
        !_insideBand(free1_after, target1_after, width1)) {
        // Either side violates the band after the step: not useful (degraded).
        return false;
    }
    // Compare distances inside the band-free region.
    uint256 d0_before = _dist(free0_before, target0_before);
    uint256 d1_before = _dist(free1_before, target1_before);
    uint256 d0_after  = _dist(free0_after,  target0_after);
    uint256 d1_after  = _dist(free1_after,  target1_after);
    uint256 totalBefore = d0_before + d1_before;
    uint256 totalAfter  = d0_after  + d1_after;
    // Strictly closer to both targets concurrently.
    return totalAfter < totalBefore
        && (d0_after <= d0_before || d0_after <= width0)
        && (d1_after <= d1_before || d1_after <= width1);
}
```

This is decided (no owner choice left): "no-churn" requires a strict improvement in the L1 distance metric **and** entry into both dead-bands if either side was out before. Reverts only when a swap impact exceeds `MAX_REBALANCE_TERMINAL_IMPACT_BP`. Returns `false` (no-op) when no useful repair exists.

---

## 6. Quote mechanisms and hooks (PRD §10)

| Quote surface | Today | Plan | Hook rule |
|---|---|---|---|
| `previewExchangeIn(token ∈ pool, amountIn, tokenOut = pool-other)` | `_quoteSwapIn` (Common:1103) | unchanged | Pons decode + `amount` adjusted; non-Pons returns vanilla (note in NatSpec that quote may underestimate under non-Pons hooks) |
| `previewExchangeOut(token = pool, amountOut, tokenOut = pool-other)` | `_quoteSwapOut` (Common:1095) | **rewrite** for combined route (WP-C): returns `(amountIn, maintenanceLiquidityDelta, post-impact-bp)` tuple — preview and execute agree because execution uses the same closed-form | Pons decode; non-Pons **reverts `InvalidRoute`** for the combined route |
| `previewExchangeIn(token = pool, amountIn, tokenOut = vault)` | `_previewZapInDeposit` (InBase:252) | **rewrite** for composition route (WP-B): returns `sharesOut` after bounded composition | Pons; non-Pons reverts `_adjustHookSwap` returns a conservative amount |
| `previewExchangeIn(token = pool, amountIn, tokenOut = vault, alignment ε metadata)` | n/a | add: returns `sharesOut`, `epsilon`, `bool` valid | n/a — same hook rule |
| `quoteState(asset, holder)` | `_inventorySnapshot` (Common:107) | unchanged | n/a |
| `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage` | existing | unchanged | n/a |
| `rebalanceLiquidReserve` | existing (revert when blocked) | WP-D: add holder-funded cross-token swap branch | Pons; non-Pons: reverting protected; bounded by 8 iterations max |

Plan-level decision (decided): for `previewExchangeOut` with combined transition, the preview returns a **struct** `(uint256 amountIn, uint128 liquidityDelta, uint256 impactBp, bool invalid)`. Preview == execution because both compute from the same pre-unlock state via `UniswapV4Quoter.quoteExactOutput + Pons adjustment + LiquidityAmounts.getLiquidityForAmounts`. There is **no second source of truth**.

---

## 7. Errors, ABI, storage, events (concrete list)

### 7.1 New errors (added to `UniswapV4FullSpreadStandardExchangeVaultCommon.sol`)

```solidity
error UniswapV4Exchange_InvalidRoute(string reason);                 // §6.4 / D19 closure
error UniswapV4Exchange_ProtectionExceeded(string control, uint256 observedBp, uint256 maxBp);
error UniswapV4Exchange_AlignmentLossExceeded(uint256 epsilonBp, uint256 maxBp);
error UniswapV4Exchange_NoUsefulRepair();                            // public rebalance truthful no-op signal
error UniswapV4Exchange_CombinedTransitionMissing(uint8 kind);      // 0 = deposit, 1 = swap-out
error UniswapV4Exchange_HookUnsupported();                           // non-vanilla, non-Pons
```

### 7.2 New events

```solidity
event CompositionSwapExecuted(
    address indexed caller,
    address indexed tokenIn,
    uint256 swapAmountIn, uint256 amountInLeft,
    uint256 received0, uint256 received1,
    uint256 sharesOut, uint256 epsilonBp
);
event ExactOutputWithMaintenanceExecuted(
    address indexed caller, address indexed tokenIn, address indexed tokenOut,
    uint256 amountOut, uint256 amountIn,
    uint128 liquidityDelta, uint256 impactBp, uint256 shortfallBp
);
event RebalanceSwapExecuted(
    bool zeroForOne, uint256 amountIn, uint128 liquidityDelta, uint256 impactBp
);
event ProtectionAudit(
    string control, uint256 observedBp, uint256 maxBp, bool revert
);
```

`ZapInProtectionAudit` (the user's naming suggestion) → `ProtectionAudit` (general). All auditable events are emitted regardless of revert order when measurement happens before the revert reason.

### 7.3 ABI additions / changes

- `IStandardExchangeIn.previewExchangeIn` — unchanged selector (`0x4c234266`); return value `uint256 amountOut` unchanged. Plan does **NOT** widen the In interface to keep ABI surface minimal.
- `IStandardExchangeOut.previewExchangeOut` — selector unchanged; **`return (uint256 amountOut)` is extended to `return (uint256 amountIn, uint128 liquidityDelta, uint256 impactBp)`** in WP-C. This is a **breaking ABI change**. Plan mitigation: keep a new sibling precompile `previewExchangeOutCombined` (selector `0x…`) alongside the original. Use the sibling for new exact-output callers; keep old `previewExchangeOut` returning `amountIn` only for back-compat callers (no maintenance leg). Document in the migration notes that callers who want interleaved maintenance must use the new combined preview.
- `IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.rebalanceLiquidReserve` — selector unchanged; behavior unchanged (revert when blocked; new swap leg when idle).
- `IStandardExchangeTransitionQuote.quoteState` — unchanged.

The breaking ABI change to `previewExchangeOut` is the **only** signature alteration; everything else returns the same selector.

### 7.4 Storage (no new durable storage)

Implementation uses **only** existing storage:
- `MultiAssetBasicVaultRepo.reserveOfToken` (token and self-share) — already durably synced by `_syncVaultReserves` (Common:610).
- `UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo._poolKey` — already.
- `UniswapV4FullSpreadStandardExchangeVaultPoolManagerAwareRepo._poolManager` — already.
- `UniswapV4FullSpreadStandardExchangeVaultPositionRepo` — already.
- No new immutable set required for protection constants (they are `internal constant`, compiled into bytecode).

PRD §9 / §14 prohibitions honored: no admin ownership; no mutable storage for protection constants; no `liquidReservePercentage` overloading.

### 7.5 Hook support surface — locked

| Hook family | Quote | Combined exact-out | Holder-funded rebalance swap |
|---|---|---|---|
| `(address(0))` (vanilla V4) | supported (existing) | supported (WP-C) | supported (WP-D) |
| Pons `beforeInitialize / afterSwap` w/ `returnsDelta` | supported via `_ponsHookFees` decode (existing Common QuoteService:21–58) | supported (WP-C; pre-unlock Pons delta closes the closed-form pre-unlock quote; the post-unlock Pons delta is bounded by `MAX_EXECUTION_SHORTFALL_BP`) | supported (WP-D) |
| Other hook flags | vanilla (conservative; quote may underestimate) | **revert `InvalidRoute` per D19** | **revert `HookUnsupported` per WP-D** |
| Imported positions | supported (existing `_quoteZapOutAmount`) | reverts `HookUnsupported` (imports use PositionManager, not direct PoolManager; combined-route invariants differ) | reverts `HookUnsupported` |

---

## 8. File work packages (concrete in-scope)

### WP-E: protection engine (architectural — first)

Files:
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` — add a dedicated section:
  ```solidity
  // === Protection engine (immutable) ===
  uint256 internal constant BP_DENOM                = 1e14;        // 1 basis point in WAD units = 1e18 / 10000
  uint256 internal constant MAX_REBALANCE_TERMINAL_IMPACT_BP = 25;
  uint256 internal constant MAX_DEPOSIT_COMPOSITION_IMPACT_BP = 50;
  uint256 internal constant MAX_EXECUTION_SHORTFALL_BP = 10;
  uint256 internal constant MAX_ALIGNMENT_EPSILON_BP = 1;
  uint256 internal constant COMPOSITION_MAX_ITERS = 8;
  uint256 internal constant REPAIR_MAX_ITERS = 8;
  
  function _priceImpactBp(uint160 sqrtPriceBefore, uint160 sqrtPriceAfter) internal pure returns (uint256);
  function _shortfallBp(uint256 quoted, uint256 actual) internal pure returns (uint256);
  ```
  Errors `ProtectionExceeded`, `AlignmentLossExceeded`, `HookUnsupported`, `InvalidRoute`.

Estimated footprint: ~60 lines added to Common.

### WP-A: precise `_targetFree`

Files:
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` — change body of `_targetFree` (Common:358–360) from `(total_i * liquidPct) / ONE_WAD` to:
  ```solidity
  function _targetFree(uint256 total_i, uint256 liquidPct) internal pure returns (uint256) {
      return (total_i * liquidPct) / (ONE_WAD + liquidPct);  // floor(...) implicit
  }
  ```
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol::_loadRebalanceSnap` (line 748) auto-picks up the precise form via the helper; no other change.
- `UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol::_actualLiquidReservePercentage` (line 69–83) unaffected — it computes `free/total`, which is the live ratio, not the placement target.

Estimated footprint: 2 lines changed.

### WP-B: composition zap-in

Files:
- `UniswapV4FullSpreadStandardExchangeVaultInBase.sol` — replace `_executeZapInDeposit` body (InBase:269–312). New flow:
  1. Pull/compute `amountIn` from caller (existing `_secureTokenTransfer`).
  2. `_collectManagedFeesIfIdle` (existing — InBase:281 already calls).
  3. Load pre-state: `(free0, free1, deployed0, deployed1, sqrtPriceX96, ticks)`.
  4. Compute post-swap-target size (closed-form §3.2). Inner bounded loop (≤8 iters).
  5. If swapAmountIn > 0: `_swapExactIn(zeroForOne, swapAmountIn)` inside one `_executeUnlock` opening (so swap + deploy settle in one callback).
  6. Deploy excess free from composition swap via `_deployExcessLiquidity` (Common existing helper, lines 818–852) targeting the **new** `targetFree` (post-swap).
  7. Mint `sharesOut = min(floor(S * C0 / B0), floor(S * C1 / B1))` with measured contribution `C_i` and post-swap incumbent `B_i`.
  8. ε check via `_priceImpactBp` and `_alignmentLossBp` against constants. Revert on `AlignmentLossExceeded` or `ProtectionExceeded`.
  9. `_syncVaultReserves` (existing).
  10. Emit `CompositionSwapExecuted`, `ProtectionAudit`.
- `UniswapV4FullSpreadStandardExchangeVaultInMultiQueryTarget.sol` — add `previewProportionalZapIn` (selector `0x…`) returning `(uint256 sharesOut, uint256 epsilonBp, bool invalid)` using pre-swap state only.
- `UniswapV4FullSpreadStandardExchangeVaultInFacet.sol` — add `previewProportionalZapIn` to `facetFuncs()` (keep `exchangeIn.exchangeIn.selector`).

Estimated footprint: ~150 lines added to InBase, ~50 to InMultiQueryTarget, ~10 to InFacet.

### WP-C: exact-output with interleaved maintenance

Files:
- `UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol` — replace direct-swap-exact-out branch (OutExecuteTarget:49–83) with combined closed-form execution. New flow:
  1. Require PoolManager idle (`_requireCanOpenPoolManagerUnlock`, existing Common:386–390).
  2. Pre-unlock: compute `(amountIn, liquidityDelta, impactBp, invalid)` from `previewExchangeOutCombined(tokenIn, tokenOut, amountOut)`. Revert `InvalidRoute` if `invalid` flag set; revert `ProtectionExceeded` if `impactBp > MAX_REBALANCE_TERMINAL_IMPACT_BP`.
  3. Caller pull path: `_secureTokenTransfer` for `amountIn` (existing on line 67).
  4. Pre-transfer refund logic unchanged (OutExecuteTarget:76–78).
  5. `_executeUnlock` with a single callback that runs:
     - `_executeSwap(OperationParams{op: SwapExactOut, zeroForOne, amountSpecified: amountOut})`
     - `_collectManagedFeesIfIdle` (or use the returned balanceDelta).
     - `_executeAddLiquidity(OperationParams{op: AddLiquidity, … liquidity: liquidityDelta})` if `liquidityDelta > 0`.
     - One combined `_settleSwapDelta + _settleModifyLiquidityDelta` (existing Common:1023–1052) over the sum of deltas.
  6. Post-unlock: `actualIn/quote − 1` check ≤ `MAX_EXECUTION_SHORTFALL_BP`; impact cap already enforced pre-unlock.
  7. `_syncVaultReserves` (existing line 79), `_rebalanceLiquidReserveBestEffort()` (existing line 80), `_pokeBoundPoolTwap()` (existing line 81).
  8. Emit `ExactOutputWithMaintenanceExecuted`, `ProtectionAudit`.
- `UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget.sol::previewExchangeOut` — keep behavior (returns `amountIn` only). Add a sibling **`previewExchangeOutCombined`** (selector `0x…`) returning `(uint256 amountIn, uint128 liquidityDelta, uint256 impactBp, bool invalid)`.
- `UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` — add `previewExchangeOutCombined.selector` to `facetFuncs()`. Keep `IStandardExchangeOut.exchangeOut.selector`.
- `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` — update `facetCuts()` if a new interface entry is needed for the new preview. **Decision: keep using `IStandardExchangeOut.exchangeOut`'s INTERFACE ID unchanged; new preview is on the same facet; the new selector is `previewExchangeOutCombined(bytes)` which only serves the same facet interface — no interface set change.**
- `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` — add `_quoteExactOutputWithMaintenance(PoolKey, bool zeroForOne, uint256 amountOut, uint256 p)` returning the same tuple. Reuses `UniswapV4Quoter.quoteExactOutput` (existing line 115–136). Closed-form via the §3.3 derivation.

Estimated footprint: ~80 lines added to OutExecuteTarget, ~20 to OutQueryTarget, ~80 to QuoteService, ~10 to OutFacet.

### WP-D: rebalance holder-funded swap

Files:
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` — replace `_rebalanceLiquidReserveInternal` body (Common:757–807) with the closed-form-or-no-op flow per §3.4. New flow:
  1. `_collectManagedFeesIfIdle` (existing line 758).
  2. Read snap via `_loadRebalanceSnap` (existing line 744; updated by WP-A).
  3. Check both tokens are inside deadband via `_shouldRebalanceToken` (existing Common:376); if yes → `_syncVaultReserves()` + return `false` (no-op; emit `RebalanceSwapExecuted(0,0,0,0)`).
  4. Pick arm with max excess over deadband; if zero → return no-op.
  5. Compute `swapAmountIn` via bounded iteration (≤8) targeting `|free_i - target_i| ≤ deadband_i`.
  6. `_executeUnlock` with one `_swapExactIn(zeroForOne, swapAmountIn)`.
  7. Verify `|P_after/P_before − 1| ≤ MAX_REBALANCE_TERMINAL_IMPACT_BP`. If exceeded, revert `ProtectionExceeded`.
  8. After the swap, re-snap; if either token is now above target, run the existing best-effort add/remove deploy (existing `_deployExcessLiquidity` / `_refillDeficitLiquidity`).
  9. `_syncVaultReserves()`, emit `RebalanceSwapExecuted`, `_emitRebalanceEvent`.

- `UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol::rebalanceLiquidReserve` (LiquidReserveTarget:92–97) — selector unchanged; behavior unchanged (revert when blocked); rename NatSpec for the new swap leg.

Estimated footprint: ~100 lines added to Common (or split into Common + a new library `RebalanceHoldersRepairLib.sol`).

### WP-F: tests + adversarial matrix

Files (under `test/foundry/vaults/standard/exchange/protocols/uniswap/v4/`):
- `test_ProportionalZapIn_Deposit_Success.t.sol` — repeated single-token deposits compose and mint with ε ≤ `MAX_ALIGNMENT_EPSILON_BP`.
- `test_ProportionalZapIn_Deposit_ProtectionRevert.t.sol` — over-budget composition impact, alignment loss exceeded, hook unsupported.
- `test_ExactOutputWithMaintenance_Success.t.sol` — combined transition executes and post-state matches sleeve target.
- `test_ExactOutputWithMaintenance_Shortfall.t.sol` — Pons hook fee shift exceeds `MAX_EXECUTION_SHORTFALL_BP` → revert.
- `test_ExactOutputWithMaintenance_NoChurnNoOp.t.sol` — both tokens already inside deadband → no swap; revert `ProtectionAudit` shows 0 impact.
- `test_RebalanceSwap_Success.t.sol` — holder-funded swap toward sleeve target; protected by 25bp cap.
- `test_RebalanceSwap_NoUsefulRepair.t.sol` — emits truthful no-op.
- `test_RebalanceSwap_HookUnsupported.t.sol` — reverts `HookUnsupported`.
- `test_RebalanceSwap_BoundedIters.t.sol` — exceeds `REPAIR_MAX_ITERS` → revert `InvalidRoute`.
- `test_Adversarial_CrossModeCycle.t.sol` — alternating deposits / withdrawals / rebalances; share-issuance invariants hold, no free credit.
- `test_Adversarial_DonationCrash.t.sol` — pretransfer balances donated to the vault are not pretransfer-credit for callers (per L-RSRV-LAW).
- `test_HookCoherence_PonsOnly.t.sol` — Pons-encoded pool uses delta; non-Pons pool reverts combined route.
- `test_QuoteCoherence_PreviewVsExecute.t.sol` — for the table in §6, preview == execute byte-for-byte (modulo gas).
- `test_FullLocalBooking.t.sol` — `_syncVaultReserves` writes `balanceOf` for both pool tokens and self-share after every money route (L-RSRV-SYNC-FULL).
- `test_PretransferGuard_EOARevert.t.sol` — `LocalCreditLib.requirePretransferCaller` rejects code-less callers (already wired at Common:1223, regression-locked).
- `test_DualAndMultiRoutes_Untouched.t.sol` — `_executeZapInDualDeposit`, `exchangeInManyToOne`, `exchangeOutOneToMany` behavior unchanged (no composition swap, no ε measurement) — confirms WP-B/C/D scope discipline.

TestBase inheritance: `CraneTest` → `IndexedexTest` → protocol TestBase. Full-fold imports; no mocks of vault, manager, fee oracle, registry, facets, or DFPkgs (CLAUDE.md non-negotiable 1/3).

---

## 9. Engineering details resolved (decided)

1. **Composition swap direction selection**: chosen by **input side**. If `tokenIn == _token0`, `zeroForOne = false` (swap token0 → token1 to acquire token1); if `tokenIn == _token1`, `zeroForOne = true`. This is the **only** sensible direction because the vault wants both tokens after composition.
2. **ε measurement is before flooring.** A deposit whose floor loss exceeds 1bp is rejected as `AlignmentLossExceeded`. A deposit where the ratio error before flooring exceeds 1bp is also rejected.
3. **Composition and rebalance solvers bounded at 8 iterations**; exceeding returns revert `InvalidRoute` per D19. The iteration is verified post-swap inside `_executeUnlock` to confirm each step lands inside the band; unbounded iteration is forbidden.
4. **Quote == execute** for combined transition: preview returns the same `(amountIn, liquidityDelta, impactBp)` tuple that execution uses by recomputing from the same pre-unlock state.
5. **One unlock per transition**: composition-swap + deploy-excess, direct swap-exact-out + maintenance-deploy, rebalance swap + rebalance add/remove — all execute inside a single `_executeUnlock` call. The vault's `_unlockCallback` (Common:954) handles all four operation kinds (`SwapExactIn`/`SwapExactOut`/`AddLiquidity`/`RemoveLiquidity`) in one round-trip.
6. **Pre-transfer refund for combined transition**: existing `_refundExcess` (Common:185–191 in OutExecuteTarget) uses the inbound difference; combined transition uses the same `inboundBefore/balanceOf/usedAmount` accounting. Re-use unchanged.
7. **Self-share booking**: KEEP the E6/I1 protection (`Common:613–616`); do not remove (already documented exception per package README).
8. **Twin tails (existing `_rebalanceLiquidReserveBestEffort` after the combined transition)**: keep; the combined transition already includes the maintenance leg, and the tail handles any residual.
9. **Pons hook delta observed in unlockCallback**: if observed Pons delta shifts `inAmount` by more than `MAX_EXECUTION_SHORTFALL_BP` from the pre-unlock closed-form, revert `ProtectionExceeded`. Documented in the event payload.
10. **`rebalanceLiquidReserve` interface signature (selector) UNCHANGED** — `rebalanceLiquidReserve()`; behavior under blocked reverted (existing); new swap leg inside idle path.

---

## 10. Genuine product contradictions, escalated

The following items cannot be reconciled without owner clarification. The plan devotes WP-F adversarial tests to expose them early, but the call remains with the owner:

1. **Q-A — Blocked exact-output-with-maintenance.** PRD §6.4 / D19 says revert `InvalidRoute` when no closed-form combined solution exists. Combined exact-output + maintenance necessarily requires PoolManager interaction for the swap leg. PoolManager in-session = blocked → no closed-form combined route possible. Plan resolution: **blocked exact-output-with-maintenance is `InvalidRoute`** (rejects the combined route explicitly per §6.4 / D19). **Owner choice**: also surface a non-maintenance blocked exact-out? The existing `_executeZapOutExactIn` blocked branch already does sleeve-cover only on the _no-swap_ exact-out path. Recommend keeping that as the blocked fallback for share-burn exact-out and accepting that `exchangeOut(pool, amountOut)` is `InvalidRoute` when blocked.
2. **Q-B — Hook support surface for the combined route.** Plan restricts combined route to vanilla + Pons. Owner choice: extend to additional hook families (e.g., dynamic-fee hooks, afterSwap `returnsDelta` non-Pons) only when their effect is closed-form-derivable. Recommend keeping the WP-C support matrix as "vanilla + Pons" and adding new hook families via subsequent PRDs.
3. **Q-C — Inside-blocked exact-output existing behavior.** The existing `_executeZapOutExactIn` blocked branch (OutExecuteTarget:150–164) pays from sleeve when covered (CP_ACCT_PRD §6 R3). The PRD D17/D18/D19 close-form requirement applies **only** to "the combined exact-output-plus-rebalance operation." The blocked share-burn exact-out is a different route (no maintenance leg). Owner choice: confirm that the blocked share-burn exact-out path remains unchanged (CP_ACCT_PRD §6 R3 keeps `InsufficientLocalReserve` revert).
4. **Q-D — Rebalance-while-rebalance-stuck governance.** If rebalance can NEVER reach the sleeve target because the ORACLE target is impossible at the current price (e.g., zero liquidity to add/remove at the current tick), plan emits truthful no-op. Owner choice: confirm "honest no-op" is acceptable; no force-close, no power-down.
5. **Q-E — Quote preview breakage.** Adding `previewExchangeOutCombined` is non-breaking (new selector). Changing `previewExchangeOut` to return a tuple IS breaking. Plan keeps the old selector returning `amountIn` only, and adds the new combined preview. Owner choice: approve the additive approach (recommended) vs. the breaking change.
6. **Q-F — `p = 1e18` target.** PRD §5 says "equal free and deployed amounts, not an all-liquid vault." At `p = 1e18`, `targetFree = floor(T * 1e18 / (1e18 + 1e18)) = T/2`. Plan resolution: targetFree = T/2 ⇒ all of `T` deployable + a 50% free after one deployment. Worked example: deployed 100 / free 100 → deploy 50 → deployed 150 / free 50 → T = 200, target = floor(200*1e18/2e18) = 100 (T was 100 in original; deployment changes T). Recomputes correctly. **Owner choice**: approve the precise formula at p=1e18; nothing further needed.

These six are documented epistemic gaps; WP-F exposes them via the acceptance matrix.

---

## 11. Compatibility and migration

- Selector additions: only `previewExchangeOutCombined(address,address,uint256)` on the Out facet. No interface ID change.
- No facade renames. No storage slot recompute. No registry rewrite.
- The OLD tree at `contracts/protocols/dexes/uniswap/v4/` is **not touched**. The owner intends to deprecate it separately.
- Existing callers (DETFs nesting through SE, hooks calling `exchangeIn` from `unlockCallback`) continue to work; their behavior is unchanged for routes they exercise. The new composition-route is opt-in via the new preview.
- Custom integrations on `IStandardExchangeIn.exchangeIn(exactOut=...)` style code are not affected because no signature changes at that interface.

---

## 12. Acceptance mapping (PRD §13 → WP evidence)

| PRD §13 | WP evidence |
|---|---|
| 1. Repeated unilateral deposits compose and deploy when feasible | WP-B + `test_ProportionalZapIn_Deposit_Success` |
| 2. Shares use post-swap incumbent backing and credit complete caller basket | WP-B composition step + `ConstantProduct._sharesForDeposit` reuse |
| 3. Sleeve policy uses owned deployed principal | WP-A precise formula |
| 4. Blocked deposits do not initiate nested unlock | WP-B blocked branch unchanged (LocalDepositWhileBlocked) |
| 5. Blocked withdrawals require actual requested-token cover | existing `InsufficientLocalReserve` (unchanged) |
| 6. Initial activation still requires actual funding in both tokens | unchanged (`_initialShares`, mulSqrt) |
| 7. Public repair performs bounded swaps and permits immediate repeated calls | WP-D + `test_RebalanceSwap_Success` |
| 8. Rebalance trades stop when both thresholds are satisfied | WP-D §5 stop metric + `test_RebalanceSwap_NoUsefulRepair` |
| 9. No time or cumulative throttle | WP-D preserved (no new throttle) |
| 10. Per-operation limits use correct units and do not double-count fees | WP-E + `_adjustHookSwap` (existing, no double-count) |
| 11. Alignment loss measured independently of sleeve deadband | WP-B ε separate from WP-D dead-band |
| 12. Every successful workflow fully books all retained local inventory | L-RSRV-SYNC-FULL — every WP final call to `_syncVaultReserves` |
| 13. Pretransfer tests distinguish valid unbooked claims from prohibited re-credit | L-RSRV + `test_PretransferGuard_EOARevert` |
| 14. Hook admission follows deployer responsibility | PRD §10 / WP-C WP-D HookUnsupported revert rule |
| 15. Native and WETH behavior, imports, Multi routes, affected consumers retain required behavior | WP-B/C scope discipline; `test_DualAndMultiRoutes_Untouched` |
| 16. Cross-mode deposit and withdrawal cycles receive adversarial testing; differing quotes alone are not proof of an exploit | `test_Adversarial_CrossModeCycle`, `test_Adversarial_DonationCrash` |
| 17. Solver work is bounded; actual economic and accounting results independently checked | WP-B/C/D bounded at 8 iters; `COMPOSITION_MAX_ITERS`, `REPAIR_MAX_ITERS` constants; `test_RebalanceSwap_BoundedIters` |
| 18. Supported exact-output routes interleave maintenance using closed-form for combined transition | WP-C §3.3 derivation; `test_ExactOutputWithMaintenance_Success` |
| 19. Combined exact-output routes lacking valid closed-form reject as `InvalidRoute`; no iterative fallback | WP-C `InvalidRoute`; `test_ExactOutputWithMaintenance_ProtectionRevert` |
| 20. Exact-output previews and route availability describe the same combined transition and supported domain as execution, idle/blocked, no-trade | WP-C preview tuple == execute tuple; `test_QuoteCoherence_PreviewVsExecute` |

---

## 13. Workstream sequencing and dependencies

```
WP-E (constants)  ── independent (no deps)
WP-A (formula)    ── depends on WP-E
WP-B (zap-in)     ── depends on WP-E, WP-A
WP-C (ex-out m.)  ── depends on WP-E, WP-A; only weakly on WP-B (shared helpers)
WP-D (rebalance)  ── depends on WP-E, WP-A
WP-F (tests)      ── depends on WP-B, WP-C, WP-D
```

PR sequencing: a single implementation PR covering WP-E + WP-A + WP-B + WP-C + WP-D; a separate tests PR for WP-F.

---

## 14. Caller-funding vs holder-funding — explicit line in the code

The `_executeUnlock` callback in the rebalance path will use **only** vault-held balances (no caller account pull). The composition-swap + execute path in the zap-in path uses **only** caller's credited `_secureTokenTransfer` output. The implementation enforces this by routing only via:

```text
authoritative balance source = vault face balances (post-pull step), never msg.sender.balanceOf
```

`_syncVaultReserves` is the source of the post-state, which is the durable local snapshot (L-RSRV-§4.2 durable-snapshot law). No opaque balance reads.

---

## 15. Plan rule check

| Check | Status |
|---|---|
| No old-tree edits | ✅ plan only touches `contracts/vaults/standard/exchange/protocols/uniswap/v4/` and `test/` |
| Owner decision not reopened | ✅ pretransfer, direct PoolManager, deployer hook, immediate rebalance, full booking, no in-place migration, **closed-form exact-output** are all preserved/locked |
| Engineering resolved vs escalated | ✅ §3 derivation + §9 decisions; §10 escalations are real contradictions only |
| Closed-form derivations for exact-output combined transition | ✅ §3.3 (vanilla + Pons) |
| Epistemic gaps explicit | ✅ non-Pons hooks rejected `InvalidRoute` per D19 |
| Protection constants 25/50/10/1 bp exact values | ✅ §2 |
| Stop/progress metric for public repair | ✅ §5 |
| Quote == execute parity for combined transition | ✅ §6 |
| Owner choice calls minimized; if owner silence means planning defaults | ✅ §9 + §10 |

---

## 16. Confidence and remaining blockers

**High confidence:** closed-form derivation for vanilla + Pons exact-output-with-maintenance; sleeve formula algebraic correctness; alignment loss isolation from sleeve dead-band; self-booking preservation; `MultiAssetBasicVaultRepo._reserveOfToken` for pretransfer law; existing `_ponsHookFees` decode for hook adjustment; existing `MultiAssetBasicVaultRepo._syncVaultReserves` for L-RSRV-SYNC-FULL compliance.

**Medium confidence:** iteration bound (8) is an engineering default — a pathologically wide `_targetFree` band may converge in fewer; the bound prevents adversarial DoS but is not mathematically tight.

**Low confidence / escalated:**
- Q-A through Q-F are real product contradictions the owner must answer.
- `p > 1e18` is impossible per oracle cap, but plan still passes the precise formula through it for safety (no underflow/overflow).

**Outside evidence and verification:**
- Exact V4 upstream tag/version not pinned (PRD §15 self-discloses). Plan recommends pinning to a specific tag before deployment (e.g., `v4-core@<release-tag>`); owner decision; not a code blocker.
- Plan assumes local compiler profile (`pragma ^0.8.0`, optimizer 1, `via_ir=false`) matches CLI run; no shell execution was performed.

---

## 17. Saved path

`docs/research/uniswap-v4-zapin-plan-2026-09-27/minimax-original.md`
