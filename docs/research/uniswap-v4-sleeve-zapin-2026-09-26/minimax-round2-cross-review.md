# MiniMax-M3 — Round 2 cross-review

**Author:** minimax/MiniMax-M3 (independent) — round 2 cross-review
**Date:** 2026-09-26
**Original preserved:** `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-round2-original.md`, plus round-1 originals/cross-review — all unchanged.
**Peers reviewed (verbatim, untrusted model evidence):** `astra-round2-original.md`, `grok-round2-original.md`, `kimi-round2-original.md`.
**Moderator PRD (directly readable this pass):** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` — §4 still encodes the **old** `targetFree_i = total_i * p / 1e18`; supersession is required because the owner explicitly chose `F_i = p · D_i` (literal). Cross-references preserved.

Re-read this pass to settle fact: `Common.sol:685–713` (issuance formulas), `:619–624,626–643` (free/deployed SoT), `:1183–1187` (full-range always-in-range), `:669–670` (sqrtPriceLimit endpoints); `InBase.sol:281–314` (existing single-token deposit pre-call snapshot pattern); `Common.sol:1270–1289` (`_secureTokenTransfer` delta accounting, FoT-safe). No peers read this pass beyond round-2 originals; no cross-review artifacts; no moderator-PRD-normative citations.

---

## A. High-confidence agreements (all three round-2 peers)

1. **Owner literal `F_i = p · D_i`** ⇒ steady state `F* = p/(1+p) · T`. Compute `F*` once **after** the swap step; do not chase `p · D_pre` (would self-chase the denominator). Closed-form verified by E1 below and Astra §2.
2. **Idle route only changes the existing `exchangeIn`**; blocked path stays sleeve-mint with no swap, no `unlock`, `LocalDepositWhileBlocked` emitted (D2/D4/D18).
3. **Caller-only composition**; incumbent sleeve/donations/blocked backlog are not the swap input; public `rebalanceLiquidReserve` stays add/remove-only.
4. **Uncollected fees `E` are not deployed principal.** They sit on the **free** side via `_freeBalancesForShareMath` (`Common.sol:626–631`); collect preexisting E before measurement, bucket to F once, never to D (Astra/Grok/Kimi).
5. **Self-LP fee** paid to self during this call accrues to vault position as fee growth, netted into `modifyLiquidity` deltas, **not** part of caller basket C.
6. **Issuance formula is existing dual min-ratio**, `Common.sol:700–704`: `m = min(c0·S/R0, c1·S/R1)`. **Exact proportional** when caller basket `c` is in ratio `R0:R1` of the issuance denominator. No new NAV, no new oracle, no new formula, no new field.
7. **Composition target = book-aligned** (T_pre ratio), **not CL-aligned**. CL-aligned alignment donates surplus to incumbents via the binding-min token. Book-aligned can leave material residue that is **not dust but intended policy residue** under D32.
8. **Donation / pretransfer** belong to incumbent free (D29). `_secureTokenTransfer` delta-accounting (`Common.sol:1274–1289`) is FoT-safe and returns the pull delta only — caller basket is the secure-pull amount plus the PoolManager swap delta of that amount, not arbitrary balance growth. **Caveat (Astra §5):** the helper credits `unbooked balance`, not independently proven transfer provenance; pretransfer replay is a real attack surface requiring explicit ZA-10 evidence.
9. **Dual bootstrap preserved** (D59); imports convert to managed full range; native/WETH face preserved; no payable ETH deposit.
10. **Endpoints:** `p=0` ⇒ `F*=0` (deploy everything); stored `0` = unset/fallthrough (D8). `p=1` ⇒ `F* = T/2`; **100% sleeve is inexpressible** — `liquidPct ∈ [0, 1e18]` so the vault can never be all-liquid. No sentinel value proposed.

## B. Specific corrections to my round-2 original

| Claim in `minimax-round2-original.md` | After peer review | Evidence |
|---|---|---|
| **R-3d "raise to `0.25e18` to preserve 20%-of-total sleeve"** | **Withdraw.** Owner input explicitly: "Owner explicitly chose 20% deployed: do not reopen 25% to preserve older policy as recommendation." Lock at literal `0.20e18` (= 16.67% sleeve of total). | Round-2 directive text; all three peers apply literal. |
| **R-3a "fees are on free side"** | **Confirmed** by all peers; recommend collecting preexisting E before placement so D58 counts them once into F. | `Common.sol:626–631`, `:648–667`. |
| **R-4a "fair min-ratio"** | **Confirmed** by all peers; existing branch reuses verbatim. | `Common.sol:700–704`. |
| **R-4c "incumbent snapshot = `F_i_pre + D_i_pre`"** | **Sharpen.** Existing code does `reserve_iBefore = total_i_post - amount_iAdded` (`InBase.sol:287–290`); the **issuance denominator** is therefore pre-call. The **placement ratio** should still use the post-swap incumbent book `B` (because the swap moves D via price impact). Two distinct snapshots: `R_pre` for issuance, `B_post_swap` for placement sizing. | Existing code pattern; Grok/Astra §3 step 3. |
| **Numerical example §3.3** | **Withdraw.** My walk-through was internally inconsistent (iterative guess didn't terminate). Canonical E1 (Kimi §3): `B=(160,100), S, deposit=10 token0`. Solve `(10-x)/160 = x/100` ⇒ `x=1000/260 ≈ 3.846` ⇒ `c=(6.154, 3.846)`. `m = min(6.154·S/160, 3.846·S/100) = 0.0385·S` on both — exact proportional because c is book-aligned. | Kimi §3 E1; cross-checked arithmetic. |
| **R-4d "fix existing route"** | **Confirmed by moderator PRD ZR-1** and all peers (resolved owner item 1). | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` ZR-1. |
| **R-4e "blocked unchanged"** | **Confirmed** by all peers and ZR-3. | Moderator PRD ZR-3. |

## C. Evidence that changes my view

1. **Pre-swap vs post-swap incumbent book with endogenous LP price/fees** — my round-2 default was pre-call snapshot everywhere; peers converge on `R_pre` for issuance but `B_post_swap` for placement sizing. The placement math `getLiquidityForAmounts(sqrtP_post, lower, upper, Δ0, Δ1)` consumes the post-swap book price; the issuance math `min(c0·S/R_pre0, c1·S/R_pre1)` consumes the pre-call denominator. **Astra/Grok/Kimi cleaner framing:** define book-aligned ratio as **post-swap** incumbent owned-book ratio `(F0_pre+swap_output_0):(F1_pre+swap_output_1)` at the post-swap price — same number line as `R_pre` if no fees/impact; differs by pool fee + price impact otherwise.
2. **Self-LP fee is a charge on the caller, not a gift to incumbents**, when the post-swap snapshot is used. With pre-call snapshot, the same fee "appears" as incumbent loss and the caller is over-credited. **Side with Grok/Astra: post-swap.** Caller pays own-LP fee through slightly less counter-token received.
3. **LP-aligned skew can donate surplus via min-ratio binding-min token; book-aligned skew leaves material residue that is NOT dust.** All three peers exposed the trade-off. My round-2 did not. **Decisive position:** book-aligned is the safe default; CL-aligned is a separate opt-in needing a different formula (e.g., invariant growth) and explicit owner approval.
4. **Pre-swap pretransfer replay** is a real attack surface flagged by Astra §5 — not addressed in my round-2.
5. **100% sleeve inexpressible** under `p ∈ [0, 1e18]` closed form `F* = T/2` at p=1 — caps the maximum expressible sleeve and forbids a sentinel.

## D. Converged answers (concrete)

### D.1 Closed-form allocation (book-aligned, canonical algorithm)

```text
// pre-call snapshot
(T0_pre, T1_pre, S_pre)                              // incumbent, immutable

// step 1: collect preexisting fees (E_pre → F_pre if not already there)
F_pre = _freeBalancesForShareMath()                   // includes E_pre
D_pre = _deployedAmounts()                            // excludes E

// step 2: pull caller tranche `a` (FoT-safe delta accounting; pretransferred U-check)
amount0_in = (tokenIn == token0) ? a : 0
amount1_in = (tokenIn == token1) ? a : 0

// step 3: solve swap size x such that caller basket c lands at the policy ratio of T_post
//   c0 = amount0_in - x,  c1 = quoteSwap(x) + amount1_in
//   T0_post = T0_pre + amount0_in,  T1_post = T1_pre + amount1_in
//   p/(1+p) * T0_post = F*_0,  p/(1+p) * T1_post = F*_1
//   c0 / (T0_post + c0) = c1 / (T1_post + c1)   -- book-aligned
//   ⇒ closed-form in x with monotone quoteSwap; bisection (≤8 probes + bisection per _inventorySharesIn, Common.sol:182–200)

// step 4: inside ONE unlock
_poolManager.unlock(...)
  _swapExactIn(swap leg, sqrtPriceLimit_user)        // bounded by user's minCounterOut
  _addLiquidity(lower, upper, ΔL)                     // deploy excess of c above F*_i
//   ΔL = getLiquidityForAmounts(sqrtP_post, lower, upper, excess0, excess1)
//   any non-deployable residue stays free (D32, intentional policy residue not dust)
//   if excess0 == 0 || excess1 == 0 ⇒ revert InvalidRoute (matches existing D33)

// step 5: settle all deltas (single callback; transparent fee/impact at step 3)

// step 6: mint LAST on existing branch
m = _sharesOutForDeposit(c0, c1, S_pre, T0_pre, T1_pre)  // exact proportional iff book-aligned
require(m >= minSharesOut) else revert MinAmountNotMet
ERC20Repo._mint(recipient, m)
```

### D.2 Conservation + snapshot conditions

| Condition | Honored by | Notes |
|---|---|---|
| **Pre-call total `T_pre` immutable** | Existing pre-pull back-out at `InBase.sol:287–290` | Caller basket `c` is post-swap; denominator is pre-call. |
| **Caller basket `c` separates incumbent vs caller** | `_secureTokenTransfer` returns pull delta only; PoolManager swap returns measured output | `c` is the secure-pull amount plus the swap's measured PoolManager delta of that amount, **not** arbitrary balance growth. |
| **Self-LP swap fee accrues to incumbent** | Post-swap snapshot; fee growth is collected, not double-counted | Conservative: incumbent gains the fee; caller pays for it. |
| **No caller sleeve subtraction** | `c` is the post-swap basket above pre-call; sleeve `F*` set against `T_post + c`, not `T_pre + c` | `m` credits only pro-rata of the (already-attributed) caller addition. |
| **Uncollected E → F exactly once** | `_collectManagedFeesIfIdle` at idle entry; existing helper at `Common.sol:648–667` | Once collected, E is F; re-deployment uses D-F rules already. |
| **Material residue ≠ dust** | D32 narrative; placement may not deploy 100% of c | Document in ZA-1 strict-deadband test that `free_i` may exceed `F*_i + deadband` after CL-skewed placement. |
| **Donation / pretransfer to incumbent** | `_secureTokenTransfer` is FoT-safe but does not prove provenance; ZA-10 mandatory | Replay defense via measured-delta only. |

### D.3 Infeasibility constraints (truly honest)

1. **First-mint single-token activation reverts** (D59); zap-in only applies to *subsequent* deposits.
2. **Book-aligned composition cannot deploy all of `c` when CL book is skewed.** Residual stays free per D32; this is **policy residue, not a defect**. Document in ZA-1.
3. **100% sleeve is inexpressible**: `p ∈ [0,1]` ⇒ `F*/T ∈ [0,1/2]`. The old `p*total` knob allowed `F/T ∈ [0,1]`. **Semantic compresses** under the new denominator.
4. **Stored `0` = unset/fallthrough** (D8); resolved zero yields `F*=0` and bypasses blocked amount-out sleeve cover.

## E. Decisions to lock

| # | Decision | Recommended |
|---|---|---|
| D-1 | Sleeve formula | `F_i = p · D_i`; closed-form `F* = p/(1+p) · T`. Stored 0 = unset; resolved 0 ⇒ `F*=0`. Same oracle field, new denominator. |
| D-2 | Fee component | Uncollected E → sleeve via `_freeBalancesForShareMath`; collect pre-measurement; once-only into F; never D. |
| D-3 | Issuance formula | Existing dual min-ratio `m = min(c0·S/R0, c1·S/R1)`; book-aligned composition guarantees exact proportional. |
| D-4 | Snapshot attribution | `R_pre` for issuance denominator; `B_post_swap` for placement sizing. Caller basket `c` = secure-pull delta + measured swap delta. |
| D-5 | Composition target | **Book-aligned** (T_pre ratio adjusted for swap output). CL-aligned (LP ratio) is a separate opt-in requiring a different formula — **out of this release**. |
| D-6 | Sequencing | **swap → placement → mint last**, single PoolManager `unlock` session, atomic revert on bound/slippage failure. |
| D-7 | Blocked + first-mint | Existing behavior; new path runs idle only; D59 enforced. |
| D-8 | Public rebalance | Unchanged (D10/D28); blocked-accumulated one-sided backlog stays undeployed unless a later user-side idle single-token zap-in composes it. |
| D-9 | Surface | Modify existing idle `exchangeIn`; selector preserved; blocked branch unchanged. (Consistent with all peers + moderator ZR-1.) |

## F. Truly remaining owner choices (NOT 25%)

| # | Choice | Recommendation |
|---|---|---|
| **O1** | Default `liquidPct` literal `0.20e18` (= 16.67% sleeve of total) | **Lock at `0.20e18`** (owner directive, no reopen). |
| **O2** | Uncollected fees = sleeve | **Yes** (peer consensus; `_freeBalancesForShareMath` already). |
| **O3** | Composition target book-aligned vs CL-aligned | **Book-aligned** (fair issuance; documented residue). |
| **O4** | Snapshot at **post-swap** vs **call-start** | **Post-swap** (honest about self-LP fee + price impact). Owner confirm. |
| **O5** | Bound source | User `minCounterOut` + `minSharesOut` + finite `sqrtPriceLimitX96`. **No oracle mandate**. (Moderator ZR-7/G5.) |
| **O6** | Hook support / fail-closed | Verify `_adjustHookSwap` and `UniswapV4QuoteService` cover new path; **fail-closed** for non-projectable hooks (Astra-flagged). |
| **O7** | Always-compose vs skip-when-deposit-improves-book (Kimi E2) | **Always-compose** for predictable deployability + uniform previews. Document the scarce-side CP-reward trade-off in ZA-7. |
| **O8** | Blocked-backlog auto-composition | **No** (D28 carve-out unchanged; backlog stays imbalanced; option O4 of moderator). |

## G. Confidence and gaps

- **High** `F* = p/(1+p) · T` derivation; existing dual min-ratio branch sufficiency when book-aligned; pre-call snapshot at `InBase.sol:287–290`; snapshot attribution separating incumbent from caller basket; D59/blocked/native preservation; necessary supersession of moderator PRD §4 (still encodes `F* = T·p`).
- **High** numerical E1 (Kimi): `(160,100), a=10, x≈3.846, c=(6.154, 3.846), m=0.0385·S`.
- **Medium** hook-aware quote coverage for the new path (Astra-flagged); solver convergence bounds under manipulated quotes (Kimi-flagged, owner O5).
- **Low** pretransfer replay defense (Astra §5); full reentrancy slot trace across the new facet (Grok-flagged).
- **Gaps**: `apply_patch` tool unavailable — `write` used. Moderator PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` §4/G3 not yet superseded; recording. No peer reads beyond originals; no Context7 re-query; no shell/tests.

Stopping here per assigned task. Cross-review is research-only; no PRD edits, no code, no shell, no delegation. Originals preserved.
