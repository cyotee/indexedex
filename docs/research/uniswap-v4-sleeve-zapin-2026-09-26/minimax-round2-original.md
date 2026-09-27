# MiniMax-M3 — Round 2 original: SE proportional zap-in with sleeve = p · deployed

**Author:** minimax/MiniMax-M3 (independent)
**Date:** 2026-09-26
**Owner inputs (verbatim):** (1) fix the existing route; (2) swap only current-call inputs; (3) sleeve = 20% of *owned deployed reserve*, not total pool liquidity; (4) "swap input to proportional split → decide deposit or sleeve to meet oracle sleeve target → mint shares as pro-rata allocation of deployed + sleeve."
**Saved prior:** `minimax-original.md`, `minimax-cross-review.md` — preserved unchanged.
**Authoritative sources read this pass:** `CLAUDE.md`; `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` v1.6 D1–D31; `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` v1.2 D30–D52; `DETF_ALIGNMENT_PRD.md` D7/D8/D17/D22/D27/D28/D32/D59/§24; `DETF_INSTANCE_IO_ROUTING_PRD.md` §16; `UniswapV4StandardExchangeCommon.sol:685–713,315–379,605–668`; `UniswapV4StandardExchangeInBase.sol:185–377`; `UniswapV4StandardExchangeLiquidReserveTarget.sol`. **Code only**, no peer files, no moderator PRD (`UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` not present on disk — recorded as gap), no shell.

---

## 1. Owner items 1/2 — recorded as resolved per instruction

1. **Fix the existing route** = rework the live `exchangeIn` pool-token→shares path on the SE Standard Exchange, not a new optional facet surface (consistent with my round-1 "surface distinction" recommendation in `minimax-cross-review.md` §B).
2. **Swap only current-call inputs** = the bounded counter-token swap consumes only the **depositor's** pre-call excess; incumbent sleeve, donated balances, blocked-accumulated backlog are not swapped. Public `rebalanceLiquidReserve` (D10/D28) stays add/remove-only, idle-only, no swap. **Aligned with all peers.**

## 2. Owner item 3 — `F_i = p · D_i` literal interpretation

**Current D17** (`Common.sol:349–350`): `targetFree_i = total_i * liquidPct / 1e18` with `total_i = free_i + deployed_i` (vault-controlled). `D7` default `liquidPct = 0.20e18`. Endpoint p=1 ⇒ `F_i = T_i`, F = total ⇒ impossible (vacuous).

**Owner literal:** `F_i = p · D_i` where `D_i` is vault-**owned deployed principal** — not external pool total, not combined vault total. Close-form steady-state:

```text
T = D + F, F = p·D  ⇒  D = T/(1+p), F = p·T/(1+p)
F* = p/(1+p) · T
```

p=0 effective fallthrough ⇒ `F*=0` (whole book deployed). p=1 ⇒ `F*=0.5·T`. With D7 default p=0.2, **default sleeve becomes 16.67% of total** (down from 20%). Same number, new denominator. Stored 0 stays unset (D8 preserved).

**Fee-component treatment.** `D_i` is principal only; uncollected PM position fees sit on the **free** side via `_freeBalancesForShareMath` (`Common.sol:626–631`) and remain there. Donations and unsolicited transfer dust also stay free (D29). The owner formula naturally allocates by principal, consistent with V4 in-range LP economic unit-of-account.

**Deadband (D22).** `deviation > max(ABS_FLOOR, targetFree · 0.05)`. Because `targetFree` shrinks from p·T to p/(1+p)·T, **the implicit deadband band tightens** at the same `RELATIVE_TOL_WAD`: at default 0.2 the band becomes 5% of 16.67% of total ⇒ 0.833% of total per token (vs 1.0% of total today). Less thrash, **no new constant**. `ABS_FLOOR` unchanged.

**Oracle blast radius.** Same field name (`liquidReservePercentage`), same 3-tier cascade (vault → type default → global default), same storage 0 = unset. **No new oracle field.** Operationally: someone setting `liquidReservePercentageOfTypeId(v4Usage, 0.20e18)` today means "20% of total" and after acceptance will mean "20% of deployed (= 16.67% sleeve)." **Already-deployed test artifacts and any future mainnet deployments need an explicit owner ack** that the same percentage now denotes a different book ratio. Recommend: PRD §3 carries a "(a) is this the same vocabulary?" line item; implementation plan §5.5 supplies a one-shot `setDefaultLiquidReservePercentageOfTypeId` to the new target (e.g., keep 0.20 to mean 20% of deployed) or resets type default to 0.25 (=20% sleeve-of-total) if the operator prefers a constant sleeve fraction.

## 3. Owner item 4 — the `swap → allocate → mint last` shape

### 3.1 Two-token issuance formula (rigorous, no new NAV)

The two honest dual-asset issuance formulas already exist in `Common.sol:685–713`:

```text
// Fair min-ratio (both sides positive):
shares = min( mulDiv(amount0Added, supply, reserve0Before),
              mulDiv(amount1Added, supply, reserve1Before) )

// Invariant growth (sums side contributions):
K0  = sqrt(reserve0Before · reserve1Before)
K1  = sqrt((reserve0Before + amount0Added) · (reserve1Before + amount1Added))
shares = mulDiv(supply, K1 - K0, K0)
```

**Fair min-ratio** (constant-product, v3-style): each side measures its own dilutive contribution; the binding token wins. **Robust against incumbent skew** because, with skewed sleeve (e.g., `F0 ≫ F*`, `F1 ≪ F*`), the **post-allocate `D+F` book** is what `reserve_iBefore` reflects — once allocation lands at `F*=p/(1+p)·T`, `reserve_i` is balanced proportionally and min-ratio matches invariant-growth.

**Invariant growth** allows one-sided deposits without proportional counter-supply; for a vault with `F=F*` it collapses to the same number on equal contributions. Recommended for the **caller's book** here because (a) the caller supplied proportionally via swap, so both sides are typically positive, and (b) it has a closed form the operator can quote in plain arithmetic. Either is honest once the contribution is **book-aligned** (post-swap, post-allocate).

**No new NAV** is introduced. The new flow uses the existing `_sharesOutForDeposit(amount0Added, amount1Added, supply, reserve0Before, reserve1Before)` once and once only.

### 3.2 Snapshot attribution — separating incumbent from caller basket

Vault state pre-call: `(F0_pre, F1_pre, D0_pre, D1_pre, supply_pre)`. The fair-min-ratio or invariant-growth formula above reads `reserve_iBefore = F_i_pre + D_i_pre` (D9/D29 SoT). The new caller's contribution `(a0, a1)` lands **after** the swap step and **after** the allocate step (which moves free↔deployed). So the formula inputs are:

```text
reserve_iBefore  = F_i_pre  + D_i_pre              (immutable incumbent)
amount_iAdded    = a_i  =  deposited_i  +  swapped_i  -  sleeve_held_i
```

Where `deposited_i` is what `modifyLiquidity` consumes (net of self-LP fee), `swapped_i` is what the swap step produced on side `i`, and `sleeve_held_i` is what allocation leaves in free to land at `F*`. **The mint formula sees only the proportion change caused by this call** — incumbent snapshot and caller basket are separated cleanly.

**Self-LP fees.** When the vault swaps against its own pool during this call, the LP fee accrues to the **vault's own position** as fee growth (`StateLibrary.getFeeGrowthInside` in `_collectablePositionFees`, `Common.sol:633–644`). It is **not** counted in free until `_collectManagedFeesIfIdle` runs. The new flow must call `_collectManagedFeesIfIdle()` before reserve measurement (existing pattern at `InBase.sol:281` for the single-token path) so the swap fee paid to self is **not double-counted** as caller deposit. The `modifyLiquidity` delta already nets the self-LP fee.

**Fees collected during placement.** `_collectManagedFeesIfIdle` runs at `_executeZapInDeposit` start (line 281). Mirror that on the new path. The collection settle goes back into free (vault-controlled, D29) and updates the caller's mint math contribution.

**Donation / pretransfer.** D29 says free = `balanceOf(address(this))`; unsolicited donations inflate free and dilute existing share price (accepted). `LocalCreditLib.requirePretransferCaller` ensures pretransferred credit is deposited by an authorized caller — already counted as `amount_iAdded`. No new handling.

### 3.3 Numerical example (p=0.2, default sleeve = 16.67% of total)

Pre-call: `F0=20, D0=80, F1=10, D1=90, supply=100, T0=T1=100`.
Per owner formula `F*=p/(1+p)·T = 0.2/1.2·100 ≈ 16.67`. Targets: `F0*=16.67, F1*=16.67`.

Deposit 50 token0, idle. After pull, `F0=70, F1=10, D0=80, D1=90, T0=150, T1=100`.

**Swap step.** Solve for `x` of token0 swapped into token1 so post-allocate both free balances hit F*=16.67. With spot at the simple ratio (assume price=1 just for illustration), each `x` token0 yields `x` token1. Let swap split = `x`. Post-swap: `F0=70−x, F1=10+x`. Post-allocate (deploy excess above target): deploy `70−x − 16.67 = 53.33−x` of token0 and `10+x − 16.67 = x − 6.67` of token1 into LP. We need both non-negative ⇒ `x ≥ 6.67`. Pick `x = 20` (safety margin): deposit `33.33` token0 + `13.33` token1 in ratio ≈ 2.5:1 into full-range center (matches CL addLiquidity at binding-min under `getLiquidityForAmounts`).

**Allocate step.** Move `33.33` token0 from free to deployed: D0=80+33.33=113.33, F0=50. Move `13.33` token1 from free (after swap) to deployed: D1=90+13.33=103.33, F1=10+x−13.33=10+20−13.33=16.67. **Both hit F*=16.67. Total rebuild:** T0=F0+D0=50+113.33=163.33; T1=16.67+103.33=120. Balance token0 totals are inflated by the new deposit; F*/T check: 16.67/120≈0.139 wait — token1 is right; token0 50/163.33≈0.306 — no, F*=p/(1+p)*163.33=27.22 needs F0=27.22 not 50. The example shows: **after swap-and-deploy, free_i must equal `p/(1+p)·T_i`, not 16.67 absolutely.** Recheck: the rebalance invariant closed form is `D = T/(1+p)`, `F = p·T/(1+p)`. Post all moves T0 = F0_pre+D0_pre+net_deposit0 = 70+80+0 (after pull, swap back and forth keeps the totals summed) ... Actually net deposit is what `modifyLiquidity` consumes: `33.33 token0 + 13.33 token1`. New T0 = 50+113.33 = 163.33; new T1 = 16.67+103.33 = 120. Target F0 = 0.2/1.2·163.33 = 27.22; target F1 = 0.2/1.2·120 = 20. The actual F0=50 (overshoot by 22.78), F1=16.67 (undershoot by 3.33). My example is wrong because I didn't iterate properly. **Drop the iterative guess.** Real algorithm:

```text
allocate(Δ0, Δ1):                                 // caller contribution to LP
  D0' = D0_pre + Δ0;  D1' = D1_pre + Δ1
  T0' = D0' + F0_after_sweep;  T1' = D1' + F1_after_sweep
  F0* = p/(1+p) · T0';  F1* = p/(1+p) · T1'
  deploy Δ0, Δ1 into LP via one modifyLiquidity (full-range center or imported NFTs)
```

Where `(Δ0, Δ1)` are not free-balance-dependent; they're chosen so the **resulting sleeve fraction** of the *caller's contribution* matches the policy. If the user deposits token0-only 50, then `Δ0 + Δ0_swapped_out = 50`. Sized from `(Δ0, Δ1)` to satisfy both slot constraints (token0 slot ≤ 50, token1 slot ≤ `swapQuote`).

The exact closed-form for `(Δ0, Δ1)` requires **simultaneous** equations in `(x, y)` where `x·y` matches `getLiquidityForAmounts` at slot0 — closed-form exists for v3 (binding-token book) and is solvable by bisection off-chain to compute `x`. **Implementation plan may use a solver or a Newton-step; do not invent a closed-form here.** Conservative code path: bisection with a `maxSteps` cap (existing pattern in `OutBase.sol:85–97`).

### 3.4 Blocked path preservation (D2/D4/D18) — invariant

Blocked single-token deposits must continue sleeve-mint only with no swap, no `unlock`, `LocalDepositWhileBlocked` emitted. New path: when `!canOpenPoolManagerUnlock()`, **return the existing `_executeZapInDeposit`** (sleeve mint; counter-token stays missing; D32 leftover accepted). The new allocate/swap path only runs when idle.

## 4. Decisions to lock in the next PRD amendment

| # | Decision | Recommendation |
|---|---|---|
| R-3 | Sleeve formula | **F_i = p · D_i;** derived F* = p/(1+p) · T. Stored 0 stays unset. Same WAD fraction field, new denominator. |
| R-3a | Fee-component treatment | Uncollected PM fees sit on free side (existing `_freeBalancesForShareMath`); D_i is position **principal** only. |
| R-3b | Donation / pretransfer | D29 unchanged; pretransfer pulled into free before measurement. |
| R-3c | Deadband | D22 constants unchanged; implicit band tightens (16.67% × 5% = 0.83% of total per token at default). |
| R-3d | Operator reset | PRD must say whether the V4 SE type default stays `0.20e18` (=16.67% sleeve) or is re-anchored to `0.25e18` to preserve 20%-of-total sleeve. Owner choice. |
| R-4 | Sequencing | **swap → allocate → mint last.** Single `unlock` session; `_collectManagedFeesIfIdle` first; existing `_sharesOutForDeposit` last. |
| R-4a | Issuance formula | **Fair min-ratio** by default; **invariant-growth** as alternative when both sides non-zero. Both already implemented at `Common.sol:685–713`. |
| R-4b | Self-LP fees | Counted via `modifyLiquidity` delta; pre-collected (existing pattern). No double-count. |
| R-4c | Incumbent snapshot | `reserve_iBefore = F_i_pre + D_i_pre` (immutable); caller contribution `(a0, a1)` is post-swap and post-swap deploy differential; **no incumbent free or deployed is part of the swap input**. |
| R-4d | Surface | **Fix the existing `exchangeIn` pool-token→shares route.** No new facet; share counts and previews change. Closed-form fair-min-ratio or invariant-growth math unchanged. |
| R-4e | Blocked | **Existing `_executeZapInDeposit`** kept; sleeve mint + D32 leftover accepted. New swap/allocate path runs only idle. |

## 5. Remaining owner choices (precise; not invented here)

1. **Type default reset** (R-3d): keep `liquidPct = 0.20e18` (now 16.67% sleeve) or reset to `0.25e18` (preserves 20% sleeve-of-total).
2. **Issuance formula choice**: fair min-ratio (strict, robust to skew) vs invariant growth (smooth, assumes balanced deposit). Recommend fair min-ratio; bounded easy to reason about. Owner choice.
3. **Whether the swap step is bounded by `minCounterOut` only, or also an impact cap** (bps or absolute WAD).
4. **Public rebalance backlog** from blocked deposits: continue D28 (no swap) — backlog stays undeployed unless a later idle single-token zap-in composes it.

## 6. Preserved invariants (reaffirmed)

- D59 dual bootstrap (first-mint single returns 0).
- D30 full-range center / D34 imported NFTs at native ticks.
- D26 native out-of-scope; WETH face; `_erc20Face`/`_takeCurrency`/`_settleCurrency` unchanged.
- D2/D4/D18 blocked sleeve-only path; **new path runs idle only**.
- D10/D28 public rebalance add/remove-only, no swap.

## 7. Confidence and gaps

- **High** on F* = p/(1+p) · T algebraic derivation; on existing `_sharesOutForDeposit` applicability once contribution is book-aligned; on snapshot attribution splitting incumbent from caller basket; on D59/blocked/native preservation.
- **Medium** on `_quoteSwapIn` accuracy at hook-fee or projected-hook pools (Astra-flagged); on `_adjustHookSwap` coverage; on whether `getLiquidityForAmounts` is the most numerically stable target.
- **Low** on closed-form simultaneous `(Δ0, Δ1)` without solver; recommend bisection like `OutBase.sol:85–97`, with `maxSteps`.
- **Gaps**: moderator PRD `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` not on disk; no peer reads this pass; no Context7 external query beyond verification; no shell/tests.

Stopping here per assigned task. Originals preserved; this round-2 original saved at `minimax-round2-original.md`.
