# MiniMax — independent first pass: do actual entry and proportional-slice exit swaps eliminate APEX-012?

**Member:** minimax (fresh, independent) · **Run:** `v4-swaps-independent-redo-20261026-01a17791` · **Date:** 2026-10-26
**Model source:** `members/minimax/model.py` (this run's member directory, standalone integer arithmetic)

---

## 0. Method, sources, and what this pass did not do

**Primary sources read (no prior-council material, no peers, no handoff conclusions):**

- `CLAUDE.md`; the AGENTS/copilot router rules (only as navigation).
- Wings family source under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`:
  `Money`, `Accounting`, `LiquidationQuote`, `Inventory`, `Harvest`, `Geometry`, `Common`, `ExecutionDelegate`, `Repo`, `Projection`, `QuoteBase`, `EconomicTarget`, `Types`, `InTarget`/`InFacet`, and the production `TestBase`.
- PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.4 + O1–O7, V1–V6, §7A, SEC-01…SEC-16).
- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`: APEX-2026-011, **APEX-2026-012**, APEX-2026-024, APEX-2026-025, APEX-2026-026, APEX-2026-040, APEX-2026-050, and the PoC sources under `docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/` (read, **not executed**).
- Oracle: `contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleTarget.sol` and `libraries/UniswapV4TruncatedTwapOracleLib.sol`.
- The vendored v4-core math the vault itself uses, read and used as the model's fidelity reference:
  `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol` and `.../SqrtPriceMath.sol`
  (`computeSwapStep`, `getAmount0Delta`, `getAmount1Delta`, `getNextSqrtPriceFromInput`).
  The model's swap step was checked against them formula by formula, and two rounding details were
  aligned to the vendored code: `getAmount0Delta`'s round-up path rounds the outer division up as well,
  and `computeSwapStep` takes the unspent remainder of an exact input **as fee** when the price target
  is not reached (so the gross consumed input is the full `amountRemaining`).

**Explicitly not read:** the prior council REPORT, `docs/research/SESSION_HANDOFF_v4-wings_20261026.md`, `docs/research/v4-wings-complete-design-20261025-01a171a0/**` (member originals), this run's `coordinator/source-notes.md`, and this run's `research/exact_ledger.py` / `research/EXECUTED.md`. I also did not read the other members' directories. No peer output exists yet.

**Execution boundary respected:** no `forge build/test/script`, no shell, no installs, no deployment, no git, no delegation. The only execution was my own standalone arithmetic model (`members/minimax/model.py`) run in a resident Python kernel — not an EVM test and not a production fix test. Tooling note: `apply_patch` is **not exposed** in this session's tool catalog (searched; no match), so the two files I own were written with the session's file writer. Both are complete and untruncated; the model source is in this run's member directory and is reproduced verbatim by that file.

---

## 1. Verdict

**No — actual entry and proportional-slice exit swaps do not eliminate APEX-012 as a class. They change which quantity the attacker manipulates, and they close one specific channel (phantom depth) while leaving the two channels that actually produced the money.**

1. **APEX-012 is not really about "temporary depth".** It is a *reference mismatch* between the deposit and the redemption. The attacker profits exactly
   `profit = D · (V_r − V_d − D) / (V_d + D)`,
   where `V_d` is whatever reference prices the deposit and `V_r` is whatever reference prices the redemption. JIT depth, an in-session price move, a donation, or a quote-cap freeze are all just ways of making `V_d ≠ V_r`. This identity is proved below and verified to the wei in the model.
2. **Executed settlement kills the phantom-depth channel specifically.** A swap's proceeds are bounded by liquidity that actually exists and actually gets paid for. JIT liquidity added inside an attacker's own unlock is either consumed by the vault's trade (so the attacker paid for it) or is absent (so the vault's trade does not see it). There is no third option, and that is exactly the option the hypothetical quote had.
3. **But the money moves to the vault's own trade.** Every design that has the vault trade is exposed to a sandwich of the *vault's* order, and under the current `_swapDeficit` shape that order is the vault's **entire opposing balance at a `MIN/MAX±1` price limit** (no slippage bound at all). My witness measures a searcher profit of **173,037,339,374 raw token0** on a 66.7 % exit with a 0 % sleeve; the audit measured **+1.428e16** for the same shape (APEX-2026-024). A price limit collapses this to **145,047,743** (1193×), at the price of some exits becoming unfundable.
4. **The mint rule decides whether dilution survives.** A mint that reads a manipulable mark (today's liquidation quote; the brief's executed price `A_T + p_exec·A_O`; a same-pool TWAP) can still be moved by an attacker who front-runs the vault's own swap. A mint that reads only **quantities** (price-free proportional vector mint) cannot be moved by the price path at all; the residual is the conversion's own impact and fee, which the depositor bears rather than the incumbents.
5. **The same-pool TWAP is not a safe reference.** The actual oracle implementation (`UniswapV4TruncatedTwapOracleLib`) credits an entire idle gap with the live spot tick at write time, clamps it to ±9116 ticks, and is permissionlessly updatable: a single push-poke-restore inside one unlock skews the whole window by **9116 ticks = 2.488× price** (audit APEX-2026-050; reproduced arithmetically in the model).

So the honest summary is: **swaps relocate APEX-012's extraction from "the attacker moves the reference" to "the attacker sandwiches the vault's order"; they only remove the dilution channel if the mint is quantity-based; and they leave a separate, currently unbounded, sandwich exposure on the vault's own conversion that the current code makes worse by selling everything at an extreme price limit.**

---

## 2. What APEX-012 actually is, from primary code

### 2.1 The pricing path (current HEAD)

`Money._deposit`: `_pull(assets_)` → `_harvest()` →

```
uint256 value = supply == 0 ? 0 : Quote.quote(Common.quoteRequest()).value;
shares_ = Accounting.issue(supply, value, assets_);
```

`Accounting.issue`: `shares_ = supply_ == 0 ? credit_ : FullMath.mulDiv(supply_, credit_, value_)` → `m = ⌊S·D/V⌋`.
`Money._redeem`: `value = Quote.quote(...).value;` then `assets_ = Accounting.entitlement(supply, value, shares_)` → `⌊s·V/S⌋`.

`LiquidationQuote._quote` computes `V` as: own liquidity removed (`_removeOwned`), then `_sell` simulates selling **the entire opposing inventory** through the remaining external liquidity, starting from the live `slot0`, walking the live tick bitmap (`_next` → `manager.getTickBitmap`, `manager.getTickLiquidity`). `result_.value = target_total + result_.proceeds`.

Consequences that matter:

- The quote is **hypothetical**: no swap happens, so it can "sell into" liquidity that the attacker can add and remove in the same unlock (`modifyLiquidity` updates the tick/bitmap state before deltas settle).
- The quote is a **mark**, so any in-session price move re-prices the whole book.
- The quote is **not a function of the caller's contribution**, so `V_d` and `V_r` can differ.

### 2.2 The unified identity (the core of this pass)

Let `V_d` = the reference used at the deposit, `V_r` = the reference used at the redemption, `D` = the deposit, `S` = the incumbent supply.

```
m      = ⌊S·D / V_d⌋                          (mint)
S'     = S + m
payout = ⌊m·V_r / S'⌋                        (redemption)
m/(S+m) = (S·D/V_d) / (S + S·D/V_d) = D/(V_d + D)
payout  = D·V_r / (V_d + D)
profit  = payout − D = D·(V_r − V_d − D) / (V_d + D)
```

Checks (model §S2b, all exact to ≤1 wei of flooring):

| S | D | V_d | V_r | profit | identity | ok |
|---|---|---|---|---|---|---|
| 1 000 000 | 250 000 | 1 000 000 | 1 400 000 | 30 000 | 30 000 | ✓ |
| 10¹² | 10¹¹ | 10¹² | 10¹² | −9 090 909 091 | −9 090 909 091 | ✓ |
| 10¹² | 10¹¹ | 10¹² | 900 000 000 000 | −18 181 818 182 | −18 181 818 182 | ✓ |

**Corollary 1 (the safety invariant).** If the deposit reference and the redemption reference are the *same function of the same state*, `V_r = V_d` and `profit = −D` — i.e. the depositor gets exactly their deposit back and nobody extracts. Any design that lets the two references differ is exploitable, and the profit scales linearly in `D` and in the reference gap.

**Corollary 2 (the channel map).** The attacker's choice of `V_d ≠ V_r` is free: `V_d` too low (JIT depth inflating the quote at the *deposit* is the wrong sign; the audit's JIT variant inflates `V_r`, the redemption-side quote) or `V_r` too high. In my witness (model §S1) the audit's JIT shape gives `V_d = 1 974 155 616 710`, `V_r = 3 098 499 999 973`, `U = V_r − V_d − D = 124 344 383 263`, and `profit = 41 808 297 643` raw token0 = **4.18 % of the deposit**, against the audit's measured **70 634 405 953 = 7.1 %** on the production fixture. Same mechanism, same order of magnitude, different book shape — the witness reproduces the mechanism, not the PoC's absolute figures.

### 2.3 Why the JIT depth specifically cannot survive executed settlement

Under the quote, the attacker's JIT liquidity is *counted* by `_sell` and never paid for: the quote simulates a sale into depth the attacker will remove before the transaction ends, and the redemption is paid out of the vault's local target sleeve (`Money._redeem` in blocked mode pays from `_localTarget()` and reverts with `InsufficientLocalTarget` if the sleeve is short). The attacker's flash credit is repaid out of the vault's own inflated payout — that is why the audit reports the PoC as "zero capital".

Under an executed swap the same liquidity is *either* consumed by the vault's trade (the attacker must then settle it) *or* removed before the trade (the trade does not see it). There is no state in which the vault receives proceeds that the attacker keeps. **This is the part of APEX-012 that genuinely dies, and it is the part that produced the "7.1 % of TVL with zero capital" headline.**

---

## 3. Design-by-design: exact mint equation, fee, inventory cutoff, execution rules

Notation: target currency `T` (currency0 in the production fixture), opposing currency `O` (currency1). `A_T`, `A_O` = the vault's target/opposing quantities; `S` = share supply; `D` = deposit; `f` = pool fee (3000 pips = 0.30 % in the fixture); `p` = target per opposing.

---

### Design 1 — current: whole-book liquidation quote (mint **and** payout)

```
V(state)  = target_total(state) + proceeds(state)          // LiquidationQuote._quote
m         = ⌊S·D / V_d⌋                                      // Accounting.issue
payout    = ⌊s·V_r / S'⌋                                    // Accounting.entitlement
```
*Fee:* the fee enters `V` twice (the simulated sale pays `f`, and the redemption re-prices the book after the book changed). *Cutoff:* none — `V` is the whole book. *Execution rules:* none — nothing executes.
**Verdict: vulnerable.** `profit = D·(V_r − V_d − D)/(V_d + D)`; `V_d` and `V_r` are both manipulable, independently, by JIT depth or a price move. Audit APEX-2026-012 (High).

---

### Design 2 — add real swaps, keep quote-priced entitlements

The vault now *executes* swaps (e.g. to fund a redemption), but `V_d`/`V_r` still come from `Quote.quote(...)`.

```
m      = ⌊S·D / V_quote(deposit)⌋
payout = ⌊s·V_quote(redeem) / S'⌋
```
**Verdict: APEX-012 survives unchanged.** The executed swap only changes *how* the payout is funded; the *entitlement* is still the inflated mark. The over-mint at the deposit is untouched, so the attacker's gain is untouched. The only difference is that the payout is now capped by what the vault can actually raise (the sleeve, plus a real swap at a real price) — i.e. the payout side is bounded by reality while the mint side is not. That is a *partial* mitigation of the loss, not a fix of the mechanism.

---

### Design 3 — executed-price mint (`m = S·D/(A_T + p_exec·A_O)`) and its corrected variants

The brief's literal form uses the **pre-swap** book at the vault's executed price:

```
V_ref    = A_T + p_exec · A_O                              // pre-swap book, executed price
m        = ⌊S·D / V_ref⌋
```

Three corrections are needed, and the brief names them:

- **post-swap book**: `V_ref = A_T' + p_exec·A_O'` where `(A_T', A_O')` is the book *after* the vault's conversion. Using the pre-swap book with a post-swap price double-counts the conversion.
- **fee-aware price**: `p_exec` must be the *net* price (`opposing received / target spent`, net of `f`), not the gross marginal price, or the depositor is charged the fee twice.
- **final contribution**: the deposit's own credit must be in the *post* state, i.e. `m = ⌊S·D/(V_post − D)⌋` for the post-state value, or `V_ref` must exclude `D`.

**Verdict: the dilution channel survives, in a new place.** `p_exec` is the price at which *the vault itself* traded. An attacker who front-runs that trade moves `p_exec` and therefore the mint. In the model (§S3): a −200 tick front-run lowers the executed price from `0.923894977` to `0.907913357` opposing per target, lowers `V_ref` from `2 050 207 958 899` to `2 040 753 760 471`, and **over-mints the depositor by 1 129 812 036 shares (+0.4633 %)**. The depositor paid the front-run impact and fees to create that move, so the *net* is settled in §4, but the structural point stands: **an executed price is still a mark, and a mark that the vault's own trade produces is sandwichable.** The correct reading of the brief's phrase "a swap is not itself a fair-mint invariant" is exactly this.

*Fee rule:* the conversion's fee and impact are charged once, to the depositor (they reduce `D` net), never to the incumbents. *Cutoff:* the conversion must be bounded by the deposited quantity, never by the vault's whole inventory. *Execution rule:* the conversion needs a price limit; without one the vault's own trade is the sandwich victim (§4).

---

### Design 4 — price-free proportional position-vector mint, unmatched input refunded

The mint is a **quantity ratio**; no price is used to convert the two currencies.

```
deposit D_T                                    // target only (PRD O6)
vault converts x = D_T·A_O·P / (A_O·P + A_T)   // P = price used ONLY to size the conversion
net contribution c = (D_T − x, y)             // y = opposing actually received
k = (D_T − x)/A_T                              // quantity ratio (the opposing side must agree)
m = ⌊S·k⌋
unmatched input refunded                       // rounding dust / unconvertible remainder
```

**Verdict: the dilution channel is structurally closed, with one honest caveat.**

- The mint depends on quantities only. A price path that does not involve the vault's own trades changes no quantity, so it cannot change `m`. This is the only candidate in the list with that property.
- The price enters **once**, to size the vault's conversion. That is a *cost* the depositor bears (fewer opposing received), not a *transfer* from the incumbents.
- **Caveat (important for this family):** "price-free" is exact only if the vault's book is a fixed token vector. In Wings the book includes an **in-range core LP position whose principal and composition are price-dependent**. My witness quantifies it: after a conversion, the target-side and opposing-side proportionality constants differ by **26–29 %** (model §S4), because the core's composition moved with the price. A quantity mint over a Wings-style book is therefore "price-free in the mint" but not "price-free in the book". A genuinely exact vector design requires the vault to stop holding an in-range core, or to define shares as claims on *specific positions* with in-kind redemption and no scalar value at all — which PRD §3 currently excludes ("a proportional basket-exit fallback" is listed as out of scope) and which PRD §7A's target-only payout route also constrains.

*Fee rule:* the LP fee and the price impact of the conversion are borne by the depositor, once, and are visible as a reduction in the net contribution. *Cutoff:* the conversion is sized by the deposit, never by the vault's inventory. *Execution rule:* the conversion needs a price limit and a slippage bound; the depositor's `minimum` must be computed from the *net* contribution.

---

### Design 5 — same-pool TWAP as the reference (corrected historical TWAP vs. the actual oracle)

The brief asks for the corrected historical same-pool TWAP to be distinguished from the actual implementation. They are not the same object.

**Actual implementation** (`UniswapV4TruncatedTwapOracleLib.write`, as read):
```
recordedTick = truncate(liveTick, prevTick)                    // clamped to prevTick ± 9116
delta        = time_ - last.blockTimestamp
tickCumulative = last.tickCumulative + recordedTick · delta   // the WHOLE gap gets the END-of-gap tick
state_.prevTick = recordedTick;  state_.lastTimestamp = time_   // and writeAge resets
```
plus `update(PoolKey)` is **permissionless** and has **no `isUnlocked` check**.

Consequences: `9116` ticks = `1.0001^9116` = **2.4882× price**; one push-poke-restore inside one unlock moves a whole window by that amount (audit APEX-2026-050, measured 2.488e36 against a fair 1e36). The clamp also *ratchets*: each subsequent write may move the recorded tick by another 9116 while the spot price stays put, so a longer window is not by itself a defence.

**Corrected historical same-pool TWAP** (credit the interval with the anchor tick that held before the write; extrapolate with `prevTick`; forbid writes while unlocked; require a minimum observation count and a deviation bound) removes the retroactive-gap skew, but a *same-pool* TWAP remains manipulable by moving that pool's price inside the window. Under the brief's premise (one venue, TWAP as the only reference) it is the best available reference, **not** a manipulation-resistant one.

**Verdict: a TWAP reference is a strict improvement over the live quote for the *deposit* side only if the window is long and the deviation bound is enforced; it is not a fix for APEX-012, and it must never be combined with the hypothesis that the same pool's price is safe.**

---

## 4. What disappears under slice-only settlement, and what does not

| APEX-012 element | under executed entry + proportional-slice exit | why |
|---|---|---|
| JIT/temporary depth inflating the quote | **dead** | an executed swap is bounded by liquidity that exists and is paid for; a JIT range is consumed or invisible |
| in-session price move re-pricing the *deposit* reference | **dead only under Design 4** | a quantity mint cannot be moved by a price path; a mark-based mint (quote, `p_exec`, TWAP) can be front-run |
| in-session price move re-pricing the *redemption* reference | **dead only under Design 4** | same reason; under a mark-based redemption the attacker restores the price before redeeming |
| the `profit = D·(V_r − V_d − D)/(V_d + D)` transfer | **dead iff `V_d` and `V_r` are the same function of the same state** | Corollary 1 |
| quote step-cap freeze (APEX-2026-026) | **dead** if the quote leaves the money path | a `QuoteWorkExceeded` revert on `getRate`/`liquidationValue` cannot freeze deposits that no longer quote |
| **the vault's own order being sandwiched** | **alive, and larger than the audit's headline** | the vault trades; a searcher sandwiches it. Currently unbounded: `_swapDeficit` sells the **entire** opposing balance with `priceLimit = MAX_SQRT_PRICE−1` / `MIN_SQRT_PRICE+1` (no slippage bound at all), and `RebalanceTarget._validate` measures its loss cap at the manipulated spot (APEX-2026-025) |
| **the vault's inventory risk (LP composition)** | **alive** | a Wings book holds an in-range core; its composition and its mark move with the price. This is symmetric across holders, but it is exactly what makes a "quantity vector" claim approximate |
| **the vault's own conversion being large** | **alive and designable** | see the cutoff below |

### 4.1 The inventory cutoff, quantified

Model §S5 (sleeve 0, the production-scripted configuration), a 66.7 % redemption:

| conversion shape | vault opposing sold | searcher profit (token0 raw) | unfunded shortfall |
|---|---|---|---|
| A. whole opposing balance, `MIN/MAX` limit (current `_swapDeficit`) | 505 024 831 046 | **173 037 339 373** | 0 |
| B. deficit-only, `MIN/MAX` limit | 505 024 831 046 | 173 037 339 373 | 0 |
| C. deficit-only, price limit +200 ticks | 10 181 201 407 | **145 047 742** | 77 894 571 469 (must revert) |

Redemption-size sweep (searcher profit, token0 raw):

| exit share | A whole dump | B deficit-only | C deficit-only +200 ticks |
|---|---|---|---|
| 10 % | 6 532 811 176 | 6 532 811 176 | 285 189 791 |
| 20 % | −102 638 158 (no swap needed) | −102 638 158 | −102 638 158 |
| 50 % | 135 735 534 305 | 135 735 534 305 | 164 970 877 |
| 66.7 % | 173 037 339 373 | 173 037 339 373 | 145 047 742 |
| 100 % | 173 037 339 373 (shortfall 49 774 370 341) | same | 145 047 742 (shortfall 369 279 777 040) |

Three conclusions, all of them design requirements:

1. **A redemption that the removed slice's target part can cover needs no swap at all and has zero sandwich exposure** (the 20 % row). The exposure starts exactly where the deficit exceeds the slice's target part.
2. **The cutoff only bites when the conversion size is bounded below the whole balance.** At 66.7 % the slice *is* the whole core, so "deficit-only" and "whole balance" coincide; at 50 % they differ in size but not in this model, because the slice is still the whole opposing inventory available. The cutoff therefore has to be expressed as *the amount the deficit requires*, not as "the slice".
3. **A price limit is the only thing that actually bounds the extraction** (1193× at 66.7 %, 824× at 50 %), and it converts the extraction into *liveness*: with a +200 tick limit the 66.7 % redemption cannot be funded and must revert. That is the real trade-off the owner has to rule on — it is a named requirement change, not an implementation detail.

### 4.2 The quantity-design attack, closed end to end

Model §S4 (full attacker ledger: target, opposing, shares, LP, debt, fees, and the remaining token vector):

```
front run          : token1 15 119 852 699 sold -> token0 14 924 506 888 received (fee 45 359 559)
victim's deposit   : the vault converts 122 077 026 239 target into 114 763 813 104 opposing
mint               : m = 332 797 195 171 shares (k = 0.332797195171, target side; no price used)
price restored     : token0 99 989 287 830 spent -> token1 106 786 288 271 received
redemption         : payout 477 684 258 591 (paid entirely from the local sleeve; no vault swap)
flash credit       : 500 000 000 000 taken, repaid from the payout
shares at end      : 0        LP at end: 0        debt at end: 0
remaining vector   : token0 392 619 477 649 / token1 91 666 435 572
NET (target-denominated) : −107 380 522 351
NET (marked at spot)     : −15 714 086 779
```

And the invariance check that matters: with vs. without the price move, the quantity mint changes by **−1 499 562 847 shares (−0.4486 %)**, and that difference is entirely the conversion's own execution (impact + fee) — a cost the depositor bears — not a re-pricing of the book. Under the quote-priced design the *same* price move produced a **2 932 957 016 raw token0 transfer from the incumbents to the depositor** (model §S2, and the identity confirms it is exactly the incumbents' loss by conservation).

---

## 5. Separate risks that remain, with sources

1. **Unbounded slippage on the vault's largest trade.** `Money._swapDeficit` sells the whole opposing balance exact-in with `priceLimit = MAX_SQRT_PRICE−1`/`MIN_SQRT_PRICE+1`. Audit APEX-2026-024: back-run profit 1.428e16, 5.3 % stayer loss; with a +200 tick front-run, 614 bps. My witness: 173 037 339 373 raw token0 at 66.7 %/0 % sleeve. `HolderValueLoss` does not catch it because the pre-swap quote already assumes the same full dump.
2. **The rebalance loss cap is measured at the manipulated spot.** `RebalanceTarget._validate` quotes before and after at the live `slot0`; the vault's own impact cancels out of the measurement. Audit APEX-2026-025: R2 profit 9.09e15 (720 bps holder loss); R1 holder loss 1.78×–12.75× the designed cap.
3. **The vault's own swaps are the attack surface, not its pricing.** Any redesign that *adds* swaps (entry conversion, slice exit, rebalance) increases the sandwichable order size unless each one is bounded by both a price limit and a size cap.
4. **The TWAP reference is the weakest link in the premise.** APEX-2026-050: the whole idle gap credited with the poked tick, ±9116 tick clamp (2.4882×), permissionless `update`, `writeAge` reset. Any mint that uses it inherits a 2.49× skew unless the deviation bound is enforced and the write is gated.
5. **The quote's 512-step cap (APEX-2026-026)** is a liveness freeze of `getRate`, `liquidationValue`, deposits and redeems. It disappears only if the money path stops quoting; it must not be "fixed" by relaxing the owner's "work exhaustion is not market-limited" rule.
6. **The bootstrap/donation trap (APEX-2026-040)** is independent of APEX-012: `issue()` has no dead-share sink, and `PoolManager.donate` is permissionless on a hookless pool, so the first depositor's shares can be rounded to 1. A redesign that changes the mint must not inherit this.
7. **The LP-composition risk is irreducible for a Wings-style book.** The core's principal and composition are price-dependent, so "the vault's book" is not a fixed quantity vector. Any quantity/vector accounting must either accept that or stop holding an in-range core.
8. **Blocked-mode behaviour must be re-specified.** `Money.begin()` does not check `isUnlocked()` (audit APEX-2026-012 affected code), and blocked redemption pays from the local sleeve only. Under an executed design, "blocked" must mean *no vault swap at all*, and the error must carry requested vs. available.

---

## 6. The strongest counterargument to this verdict

**The counterargument.** "You have answered a different question. APEX-012 is a *High* finding whose headline is '7.1 % of TVL per transaction with zero capital'. Actual swaps remove exactly that: the attacker can no longer sell into depth it does not pay for, so the zero-capital JIT extraction is gone; the remaining exposure is ordinary AMM sandwich risk on the vault's own trades, which every LP vault in DeFi has, is bounded by the trade size and the pool depth, and is not 'manipulation-induced ownership dilution' at all. Under that reading the swap redesign *does* eliminate APEX-012 as a High-severity finding, and the residual belongs in a separate, lower-severity finding about the vault's execution discipline (price limits, deficit-only sizing) — which is a liveness/slippage engineering matter, not a share-accounting vulnerability. A council that reports 'swaps do not eliminate APEX-012' will be read as overstating the risk and will push the owner toward a much larger redesign than the problem requires."

**Why I do not concede, but I do concede the severity point.** The counterargument is right about severity and about the *shape* of the fix, and I have said so twice above. It is wrong about the *class*:

- Under designs 1–3 the dilution channel is still open, and I have measured it: `+1 129 812 036` over-minted shares (+0.4633 %) from a single −200 tick front-run of the vault's own entry swap. That is ownership dilution of incumbents caused by an unprivileged manipulation, and it is precisely the thing APEX-012 names.
- Under design 4 the *dilution* is closed, but the *extraction* is not: 173 037 339 373 raw token0 leaves the vault in one transaction in my witness, and the current code's unbounded limit means the order can be as large as the vault's whole opposing inventory. "Bounded by the trade size" is a statement about a parameter the owner sets, not a safety property of the system. In the current code that parameter is "everything".
- "Ordinary AMM sandwich risk" is not a defence here because the vault is not an ordinary LP: it is a *managed* book whose order size is a governance variable (the sleeve), it can be large relative to the external depth, and it is executed at a price limit of `MAX_SQRT_PRICE−1`. APEX-024 already rates that shape as a finding.

The honest resolution: **the swap redesign is a prerequisite for closing APEX-012, not a substitute for it.** It must be paired with (a) a quantity-based mint, (b) deficit-only conversion sizing, (c) a price limit derived from a pre-trade reference with a bounded deviation, and (d) an explicit ruling on which exits may revert for lack of funding. With those, APEX-012's mechanism is dead; without (a), it is merely relocated.

---

## 7. What remains unproved after this first pass

1. **Production reachability.** APEX-2026-012 is *latent: not deployed* (audit). Nothing here was executed against the real vault, a real PoolManager, or the real wings; my model is an idealized single-range witness. I did not reproduce the PoC's exact post-rebalance book, the wings, the fee growth, the harvest/rebalance scheduling, or the 512-step cap.
2. **The wings.** The vault's real book is core + upper wing + lower wing + sleeve, with out-of-range wings that become one-sided and harvest-eligible. My model has a core and a sleeve only. Wings change the *shape* of the book, not the identity, but they change the numbers and the inventory cutoff materially.
3. **Multi-range pools.** My witness has one wide range. Real pools have many initialized ticks, and the quote's tick walk (and its 512-step cap) is where the audit found the DoS. A slice exit that crosses ticks has a different price path from the linear single-range case.
4. **A proof, not a finite search.** The statement "no price path changes a quantity-based mint" is a *structural* argument about the mint's arguments, not an exhaustive search over price paths. It is proved for a book that is a fixed token vector; for a Wings book with an in-range core it holds only up to the conversion's own execution (measured at −0.4486 % in the witness), and I have not proved a bound on that term.
5. **The sandwich bound.** I measured a searcher's profit for one book shape, one depth, one front-run size and one exit fraction. I have not derived a closed-form bound in terms of (slice size, pool depth, fee, deviation limit), and I have not verified whether a bounded price limit can be honoured *and* the redemption funded for the useful domain.
6. **The TWAP as a bound source.** I read the oracle; I did not model a TWAP-based mint, and APEX-2026-050 shows the implementation is skewed. Whether a *corrected* same-pool TWAP with a deviation bound is sufficient for the deposit side is untested here.
7. **Consumer and route impact.** DETF composition, the `IRateProvider` contract, the SY routes, the transition quotes and `Projection`/`Projection.value` all re-quote the same book; a redesign that changes the money path changes every one of them, and I did not enumerate those surfaces.
8. **`getRate`.** I did not analyse `getRate` beyond noting it is `V·1e18/S` off the same quote (`EconomicTarget.getRate`). Per the standing instruction it stays the normalized single-share withdrawal-and-sale preview, separate from issuance accounting; nothing in this pass redefines it, and nothing here is implementation authorization.
9. **The fee attribution.** "The depositor bears the conversion's fee and impact" is a design stance I derived, not an owner ruling; PRD O4 ("the vault pays execution costs from reserves") and the §15 requirement that the initiator bears operation fees pull in opposite directions for a *deposit-side* conversion.

---

## 8. The reproducible case

**Artefact:** `members/minimax/model.py` (standalone Python 3, no third-party packages, no network, no EVM).

```
python3 model.py
```

**What it contains**

| section | content |
|---|---|
| S0 | TickMath anchors (tick 0 → `2**96`, MAX/MIN tick → MAX/MIN sqrt price) and a tick round-trip over ±887 220; pool reserves; swap direction and the constant-product invariant check |
| S1 | APEX-012 as implemented: JIT depth between deposit and redemption, with the full attacker ledger and the identity check |
| S2 | APEX-012 as implemented: in-session price move (depress the deposit quote, restore, redeem) |
| S2b | the unified identity sweep |
| S3 | executed-price mint with a sandwiched vault entry swap (over-mint measurement) |
| S4 | price-free quantity mint + slice exit: the same attack closed end to end, full ledger, mint-invariance check |
| S5 | the residual sandwich of the vault's own trade; three conversion shapes; redemption-size sweep; the inventory cutoff and the price-limit trade-off |
| S6 | size/depth sensitivity: JIT-depth ladder, front-run tick sweep, and 49/50/51 % swaps in both directions |
| S7 | the actual TWAP implementation's numbers (9116 ticks = 2.4882×) |
| S8 | the design matrix |

**Model fidelity and its limits**

- The pool is a **single wide range**; inside one range v4-core *is* a constant-product AMM. The model's swap step
  follows the vendored `SwapMath.computeSwapStep` / `SqrtPriceMath` control flow and rounding (including the
  double round-up in `getAmount0Delta` and the remainder-as-fee branch), and `TickMath.getSqrtPriceAtTick` is
  re-implemented from the published constants with anchor and round-trip self-checks. The `x·y` invariant is
  asserted after every executed swap.
- Scale follows the production fixture (token0 6 decimals, token1 18 decimals, fee 3000, spacing 60, hookless, `sqrtP = 2**96`): external liquidity 1e12, vault core 5e11, sleeve 1.1e12, supply 1e12.
- The Wings quote is reproduced in its essential steps (collect own principal, remove own liquidity from the depth, simulate selling the whole opposing inventory through the remaining external liquidity from the live price).
- **Not** reproduced: the wings, fee growth, harvest/rebalance scheduling, the 512-step cap, the real PoC's post-rebalance book, and any multi-range tick crossing. The witness is evidence about **mechanism and identity**, not about production magnitudes; the production magnitudes are the audit's measured figures, which I cite separately and never present as model output.

**Key outputs (exact, from the final run)**

```
S1  quote-priced, JIT depth
    V_d 1 974 155 616 710   V_r 3 098 499 999 973   U 124 344 383 263
    profit 41 808 297 643 raw token0 = 4.181 % of the deposit
    identity D*(V_r-V_d-D)/(V_d+D) = 41 808 297 644   (1 wei of flooring)
    audit PoC: 70 634 405 953 = 7.1 % of a 1e12 vault

S2  quote-priced, in-session price move (+200 ticks)
    quote depressed by 8 697 561 015; profit 2 932 957 016 (identity matched)

S3  executed-price mint, -200 tick front run of the vault's entry swap
    p_exec 0.923894977 -> 0.907913357; V_ref 2 050 207 958 899 -> 2 040 753 760 471
    over-mint +1 129 812 036 shares (+0.4633 %)

S4  quantity mint, full round trip
    mint differs by only -1 499 562 847 shares (-0.4486 %) with vs. without the price move
    and that difference is the conversion's own execution (impact + fee)
    attacker NET -107 380 522 351 token0 (-15 714 086 779 marked); shares 0; debt 0
    remaining vector token0 392 619 477 649 / token1 91 666 435 572

S5  residual sandwich (66.7 % exit, 0 % sleeve)
    A whole-balance dump, MIN/MAX limit : searcher +173 037 339 373
    C deficit-only, +200 tick limit     : searcher +145 047 742 (1193x smaller),
                                          vault shortfall 77 894 571 469 -> must revert
    20 % exit: no vault swap is needed at all -> zero exposure
```

---

## 9. Requirements this analysis would change (named, not authorized)

Nothing here authorizes implementation. These are the named requirement changes the evidence points at, for the owner to rule on:

1. **R1 — the mint must be quantity-based.** Issue from the depositor's *net* contribution vector against the vault's book vector, with the conversion's fee and impact charged once to the depositor and any unmatched input refunded. `Accounting.issue` stops being `S·D/V_quote`. Consequence: the Wings book must either stop holding an in-range core, or accept an explicit approximation bound (measured at up to ~29 % mismatch in the witness, ~0.45 % effect on the mint).
2. **R2 — the redemption reference must be the same function as the deposit reference** (Corollary 1), or both must be quantity-based. A mixed regime (quantity mint, mark redemption) re-opens `V_d ≠ V_r`.
3. **R3 — the inventory cutoff is a rule, not a side effect.** The vault converts only what the deficit requires, never a whole balance; and a redemption that the removed slice's target part can cover performs no swap at all.
4. **R4 — every vault swap carries a bounded price limit** derived from a pre-trade reference with a stated maximum deviation, and an unfunded deficit is a typed revert, not a fill at `MIN/MAX±1`. This is the single change that collapses the measured 173 037 339 373 to 145 047 742.
5. **R5 — the TWAP, if used at all, must be a corrected same-pool TWAP** (anchor-tick interval crediting, write blocked while unlocked, minimum observation count, deviation bound), and it may bound the deviation of a vault swap; it may not be used as an unconstrained mint reference.
6. **R6 — blocked mode means "no vault swap"**, with requested/available in the error, and `getRate`, `liquidationValue` and the previews guarded consistently (audit APEX-2026-012's smallest fix, now a precondition rather than a mitigation).
7. **R7 — `getRate` is unchanged in role**: the normalized single-share withdrawal-and-sale preview, separate from issuance accounting. It must not be read as the issuance rate, and the issuance rule above must not be inferred from it.

---

*Prepared as an independent first pass from primary code, PRD and audit sources only. No claim of audit closure is made or implied; the council's agreement is not evidence. The model is a mechanism witness, not a production test, and the production magnitudes cited are the audit's measured figures.*
