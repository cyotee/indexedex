Ask: Independent first pass on whether actual deposit and slice-exit swaps eliminate APEX-012 - wanted: a sourced response with exact mint rules and a closed ledger. For you: apply_patch is not in the catalog, so the complete original is inline. Verdict: no. A real swap does not remove the bug while mint or payout still uses a pool-derived scalar. Closed same-pool profits: quote JIT +295 target; quote plus a 50% entry swap +343; spot-mark mint then slice exit +125 and +1014; executed-price mint on a skewed out-of-range wing +1087. Price-free vector mint lost money on the same pushes. Now: none. Next: none.

# Independent original — Grok

apply_patch is not available. This is the complete `members/grok/response.md`. The witness code at the end is the complete `members/grok/model.py`. No production file was written.

## Verdict

No. Actual entry swaps and proportional-slice exit swaps do not eliminate manipulation-induced ownership dilution or reserve extraction.

A swap is not a fair-mint invariant. APEX-012 is an issuance and payout rule: shares and target payouts are scalars of a live whole-book liquidation quote. Executing a swap somewhere in the same transaction does not change that rule. The temporary-depth attack disappears only when both of these are true:

1. The minted fraction is the matched token-vector fraction, with no pool price in the mint.
2. Every swap used to complete a target-only deposit, or to convert a slice to target, is filled only by external liquidity. Remaining vault liquidity is removed before the swap and is not the counterparty.

Slice-only settlement removes the inflated whole-book payout and the whole-balance dump in APEX-024. It does not remove over-issuance. Extra shares, redeemed as a real slice, are still an extraction. The ledgers below are closed after repayment through the same pool.

This is not implementation authorization. Named requirement changes are marked as such.

## Source observations

Production mint and payout, read from code, not from the audit summary.

Subsequent deposit, after the pull and after harvest, before the credit is booked:

```
m = floor(S * D / V)     if S > 0
m = D                    if S = 0
```

`Accounting.issue` is `FullMath.mulDiv(supply, credit, value)` for existing supply, and `credit` at zero supply. Zero shares and `S > 0, V = 0` revert. `depositExactShares` may mint fewer than that formula, never more: it requires the formula amount to be at least the requested amount, then mints the requested amount.

Redemption:

```
assets = floor(s * V / S)
```

`redeemExactAssets` may pay less, never more. While any shares remain, an unlocked redeem must be covered by local target plus one unit. A locked redeem may close positions and swap.

`V` is `LiquidationQuote.quote`, not a spot mark and not a one-share sale. The quote removes this vault's own liquidity, collects removal-floor principal plus uncollected fees once, then simulates an exact-input sale of the entire opposing balance through the remaining external depth. Unsold opposing adds nothing. The walk reverts at 512 steps. It does not execute.

`getRate` is `floor(V * 1e18 / S)`, the same whole-book quote. That is not a one-whole-share withdrawal-and-sale preview. This note does not redefine `getRate`. Issuance and that preview are different objects. Using either the current `getRate` or a true one-share sale preview as the mint price would keep a depth channel open. The separation is load-bearing.

Ordinary harvest never swaps. Placement adds liquidity from local inventory. The only production money-path swap is `_swapDeficit`: on a large locked redeem it sells the entire opposing balance, exact-input, at `MIN_SQRT_PRICE+1` or `MAX_SQRT_PRICE-1`. `PoolManager.swap` fills against all active liquidity, including any vault position that was not closed first. The quote's sale excludes own liquidity. Those are different prices.

There is no Wings entry or exit usage fee. The pool's combined LP and protocol fee is inside the quote step once. `HolderValueLoss` re-quotes the same state, so it cannot see depth or price that was inflated before both quotes.

Owner rules that bind the accounting, from the Wings PRD: O1 excludes currently unsellable inventory from priced value and gives incumbents no separate recovery claim; O6 accepts and pays only the target token; V1 is whole-book liquidation after removing own liquidity, and it forbids replacing that with a spot mark or with liquidation of only the redeemer's fraction; SEC-08 names temporary liquidity and JIT. A1 and the implementation notes say later recovery is shared by whoever holds shares. That is a policy transfer, not the APEX-012 attack. The attack is a same-transaction round trip that creates and then removes the depth.

Reported audit outputs, not re-executed here:

- APEX-012 in-unlock JIT: +70,634,405,953 raw token0, 7.1% of a 1e12 vault, control −1. Settled JIT: +74,704,386,253. Spot-move variant also reported profitable.
- APEX-024: a large redeem dumps the whole opposing balance; back-run profit reported +1.428e16.
- APEX-025: permissionless rebalance measures its loss at the same manipulated spot it just traded.
- APEX-026: `stepLimit = 512` freezes every quote caller, including deposit, redeem, and `getRate`.
- APEX-040: no dead-share sink; donated fee growth can round the next deposit to 1 share.
- APEX-050: `MAX_ABS_TICK_MOVE = 9116`. `write` credits the idle gap with the truncated live tick. `update` is permissionless and has no `isUnlocked` check. The read path extrapolates with the live tick. Reported poke: mean tick 9116, about 2.488 times the fair price, after a push-poke-restore.

Geometry: core is full usable range. Wings are strictly separated. At one price at most one wing is in range. The other wing, if funded, is one-sided and out of range. Its principal does not change until price enters it. That is the inventory the out-of-range ledger uses. It is not a claim that a mixed core-plus-wing production transaction was executed.

## Rules for each answer

Target is token0 in the witness. Production can bind either token. The mirror swaps the labels. `zeroForOne` in `_swapDeficit` is `!target0`.

Fee cutoff, all designs: no second usage fee. A real swap pays the pool fee once, to external LPs and to whatever vault liquidity was left in the pool. Protocol fee is not vault-owned. Uncollected vault fees are incumbent inventory and are counted once. Do not count a PoolManager delta and fee growth as two receipts.

Inventory cutoff, all designs: measure after isolating the pending credit and after locked-path harvest. Include booked local balances, removal-floor principal, and uncollected fees. Exclude external depth, the caller's unbooked credit, and liabilities. The one-unit local floor while shares remain is a payout constraint, not part of `V`.

### 1. Current whole-book quote

```
V(L) = A_T + proceeds(A_O, L_ext, fee)
m    = floor(S * D / V(L_at_deposit))
pay  = floor(s * V(L_at_redeem) / S)
```

`A_T` and `A_O` include local, removal-floor principal, and fees. `proceeds` is the quote's exact-input sale after own liquidity is removed. Execution on the locked path may still swap the whole opposing balance through liquidity that includes uncleared vault positions.

Single-tick sale of opposing token1, the production exact-in step with no tick cross:

```
less = floor(amount * (1_000_000 - fee) / 1_000_000)
P'   = P + floor(less * 2^96 / L)
out  = amount0Delta(P, P', L, roundDown)
```

`out` is strictly larger at larger `L` for a positive sale that stays inside the tick. The witness: 90,661 at external L = 1e6, 94,965 at 2e6, 98,070 at 6e6, same 100,000 opposing, fee 3,000. A general proof for every tick-crossing bitmap is not claimed.

If the deposit adds `D` target and does not change opposing or price, `V1 = V0 + D + U` with `U = proceeds(L1) - proceeds(L0) > 0`. Then:

```
profit = floor(m * V1 / (S + m)) - D
       ≈ D * U / (V0 + D)
```

`HolderValueLoss` compares two quotes at `L1`. It does not subtract `U`.

### 2. Real swaps, quote-priced entitlements

Same mint and payout as design 1. The added rule is an exact-input swap of a fixed fraction φ of `D`, φ in {0.49, 0.50, 0.51}, through `PoolManager.swap`, before or after the quote. Credit remains `D`, not `D` net of swap output. Placement cost stays socialized, which is the current O4 order.

This does not remove `U`. A swap of target into opposing increases `A_O`, which increases the inventory whose proceeds rise with temporary depth.

### 3. Executed-price mint, and the corrected variants

Literal pre-swap rule. Swap `x = floor(φ * D)` target for `y` opposing. If `y = 0`, revert.

```
p_exec = x / y                         # target paid per opposing received
V      = A_T + floor(x * A_O / y)      # pre-swap book, pending D excluded
m      = floor(S * D / V)
```

`A_T` and `A_O` are the pre-swap vector. The formula applies the depositor's average execution price to the incumbents' entire opposing balance.

Fee-aware final-contribution variant, same swap:

```
contrib = (D - x) + floor(x * y / y) = D     # fees included in x, so they cancel
V_post  = (A_T + D - x) + floor(x * (A_O + y) / y)
        = A_T + D + floor(x * A_O / y)
m       = floor(S * D / (V_post - D))
```

Ignoring the inner floor, this is the literal formula again. The fee is not charged to the depositor. It is hidden by revaluing every incumbent opposing unit at the depositor's slipped price. A "corrected" version that values the purchased opposing at pre-swap marginal spot does charge the slippage, but that spot is still the attacker's price. Post-swap mark at the same manipulable price has the same defect.

Exit rule used in the witness: burn the shares, pay the proportional token vector, then sell the attacker's residual opposing through external liquidity and repay. That is a slice exit. It is not a second quote.

### 4. Price-free vector

```
Q = (q_T, q_O)     # cutoff above, before the depositor's swap
C = (c_T, c_O)     # what the depositor actually adds after an external-only completion swap
α = min(c_T / q_T, c_O / q_O)          # a zero incumbent leg is unconstrained only if the add on that leg is zero
M = (floor(α * q_T), floor(α * q_O))
refund = C - M
m = floor(S * M_T / q_T)               # binding leg; revert if 0
```

If `q_O = 0`, a target-only deposit matches and nothing is refunded. If both legs are positive and the user sends only target, α = 0 unless a swap creates `c_O`. Under O6 that swap is mandatory, and the refund of leftover opposing contradicts O6. That is a named requirement change, not a silent route.

Execution rule that makes the identity hold:

1. Remove vault liquidity to local before the completion swap. Swap only against external liquidity. Re-add afterward; that rounding is vault cost and must not change `m`, which is already fixed.
2. On exit, remove the share fraction of each position, of local, and of fees. If the payout must be target-only, swap only that slice's opposing after remaining vault liquidity has also been removed. Pay slice target plus those proceeds. Do not pay `floor(s * V / S)`.

Identity, exact match, no self-fill, no price move against vault inventory: the exit returns `M` minus at most one unit per leg from the floors. External JIT does not change `Q`. An out-of-range wing's `Q` does not change with spot. The depositor pays the external fee. Incumbents' vector is unchanged.

### 5. Same-pool TWAP

Actual write, from `UniswapV4TruncatedTwapOracleLib`:

```
recorded = clamp(liveTick, prevTick ± 9116)
cumulative += recorded * (now - lastTimestamp)
prevTick = recorded
```

A corrected historical write credits the gap with the anchor that held during the gap:

```
cumulative += prevTick * (now - lastTimestamp)
prevTick = clamp(liveTick, prevTick ± 9116)
```

The current read also extrapolates an unpublished gap with the truncated live tick. The corrected read extrapolates with the stored anchor.

Neither is the mint rule unless a requirement change says so. A TWAP is a price. JIT depth can raise `proceeds(L)` without moving the tick. A price bound does not cap that. Mint at `max(V_live, V_twap)` and redeem at `min(V_live, V_twap)` can close the instantaneous depth channel if `V_twap` is a depth-independent mark and is not itself poked. That is the audit's suggested reference bound, not a swap. It marks inventory that O1 currently excludes, so adopting it changes O1. A corrected TWAP still moves if the attacker holds the price for the window. With one pool, that cost is finite.

## Closed ledgers

Single-tick mechanism witness. Fee 3,000 pips unless noted. Range sqrt prices `2^95` to `2^97`, start `2^96`, so one unit of in-range liquidity holds about half a unit of each token. Not a Forge trace. Not production reachability. Books checked equal before repayment; profit is wallet minus flash debt after the residual opposing leg is sold or bought through external liquidity of the same pool. `profit1 = 0` in every closed row.

### Design 1 — quote JIT, in-range vault, own L removed from the quote

Vault: in-range L = 200,000, local target 80,000, opposing principal 100,000, fees 0. External L = 1,000,000. S = 100,000. D = 20,000. Price does not move. JIT is added and removed at the same price, so it earns no fee. Payout comes from local target. That is the in-unlock shape, not the settled close-and-dump shape.

| Case | V0 | V1 | m | payout | target profit |
| --- | ---: | ---: | ---: | ---: | ---: |
| No JIT, control | 270,661 | 290,661 | 7,389 | 19,999 | −1 |
| JIT L = 1e6 | 270,661 | 294,965 | 7,389 | 20,295 | +295 |
| JIT L = 5e6 | 270,661 | 298,070 | 7,389 | 20,508 | +508 |
| JIT L = 5e6, fee 0 | 270,909 | 298,360 | 7,382 | 20,510 | +510 |
| External L = vault L = 2e5, D = 10,000, JIT L = 2e6 | 216,533 | 255,377 | 4,618 | 11,272 | +1,272 |

The +295 row closes exactly:

```
U = 4,304
V1 = 270,661 + 20,000 + 4,304 = 294,965
m = floor(100,000 * 20,000 / 270,661) = 7,389
payout = floor(7,389 * 294,965 / 107,389) = 20,295
profit = 295
```

Remaining honest quote is `V0 + D - payout = 270,366`. Honest loss against `V0` is 295. The attacker repaid the deposit flash and the JIT capital flash. Ending opposing debt is 0. The extracted token is incumbent target. Composition of the in-range position did not change. No vault fee was earned. Dust was 0 on this constant-price path.

Depth sensitivity is monotone here: more temporary external L, more profit, until proceeds approach the marginal sale. A larger vault share of active L does not defend the quote, because the quote deletes own L. The thin-external row is the expensive one for incumbents: +1,272 on a 10,000 deposit.

### Design 2 — 49/50/51% entry swap, then the same quote mint, then JIT L = 1e6

Same book as the +295 row. The vault swaps φ of D target into opposing through live liquidity, including its own, after the mint quote and before the JIT redeem. Credit is still D.

| φ | y opposing bought | redeem V | payout | target profit |
| --- | ---: | ---: | ---: | ---: |
| 0.49 | 9,691 | 295,703 | 20,346 | +342 |
| 0.50 | 9,887 | 295,719 | 20,347 | +343 |
| 0.51 | 10,083 | 295,734 | 20,348 | +344 |

The swap did not remove the attack. It increased profit. It added opposing inventory, and the temporary depth then priced that larger book. 49, 50, and 51 are the same bug.

### Design 3 — spot mark, out-of-range opposing wing, slice exit

No vault liquidity in range. Active L is external only, so the manipulation does not trade against a vault position. Vault holds 100,000 local target and 100,000 out-of-range opposing. S = 100,000. D = 20,000. Mint is `floor(S * D / (A_T + floor(P_spot * A_O)))` with `P_spot = 2^192 / sqrt^2`. Exit pays the token slice. Residual opposing is sold through the same external pool. Flash of D target and of the push's opposing is repaid.

| Push of opposing | V | m | target profit |
| ---: | ---: | ---: | ---: |
| 0 | 200,000 | 10,000 | −111 |
| 1,000 | 199,800 | 10,010 | −99 |
| 5,000 | 199,010 | 10,049 | −53 |
| 20,000 | 196,128 | 10,197 | +125 |
| 50,000 | 190,728 | 10,486 | +470 |
| 100,000 | 182,689 | 10,947 | +1,014 |
| 200,000 | 169,513 | 11,798 | +1,987 |

The no-push −111 is the attacker's own cost of selling the slice's opposing back through the pool, plus floors. It is not a gift to the attacker. From a 20,000 push upward, the same exit is profitable. Small pushes lose. That loss region is not a safety proof.

+125 row, after repayment: attacker +125 target and 0 opposing. Vault ends at 108,896 target and 90,747 opposing. Against start plus the 20,000 deposit, incumbents are short 11,104 target and 9,253 opposing; those are exactly the units the attacker withdrew. Net of the deposit, incumbents hold +8,896 target and −9,253 opposing. At the pre-attack price of 1, that inventory loss is 357. Attacker target profit is 125. External LPs took the spread: token0 −9,022, token1 +9,252, fees 59 and 88. Dust 1 and 1. The attacker's profit is smaller than the incumbent inventory loss because the pool collected the rest. Incumbents lost. The ledger closes.

A thinner external book with a larger wing is worse: external L = 100,000, wing 200,000/200,000, push 20,000, profit +2,149. A dominated external book is not automatically safe either; one tested point lost money because the price was not a small deviation. Size and depth move the sign. They do not create an invariant.

### Design 3 — literal `p_exec`, same slice exit

Balanced wing, external L = 1e6, push 50,000, φ in {0.49, 0.50, 0.51}: target profit −318, −333, −351. The mandatory vault purchase of depressed opposing, valued into the whole book at the slipped average, did not pay for the push at that one point.

That is not safety. The same formula is profitable on other books, including with no separate push:

- Skewed wing, external L = 100,000, target 50,000, opposing 400,000, D = 20,000, S = 50,000, push 20,000. φ 0.49 / 0.50 / 0.51 profit +1,118 / +1,087 / +1,056. The 0.50 row mints 2,760 shares against V = 362,256. Vault ends 56,862 target and 391,215 opposing. Attacker profit +1,087 after selling the residual through that same pool. External token0 −7,951, token1 +8,783, dust 2 and 2.
- Same skewed book, push 20,000, φ 0.10: profit +2,247. φ 0.80: profit +126. The fraction is not the defense.
- No push, φ 0.80, external L = 200,000, balanced 300,000/300,000, D = 30,000, S = 300,000: profit +480. The swap's own slippage, applied to the whole pre-swap opposing balance, is enough. m = 14,130 against V = 636,905. External LPs gained on the round trip; the vault paid both of them and the attacker.

So 49/50/51 is not a fair-mint rule. It is a size-dependent revaluation of incumbent inventory. Post-swap cancellation does not fix it, because it reduces to the same equation.

In-range self-fill searches at external L = 1e6 and vault L = 2e5, φ 0.49/0.50/0.51, pushes 0, 20,000, and 80,000, lost money (about −40 with no push, −196 to −866 with a push). I do not promote that loss to a safety result. The core being full-range raises the cost of a spot push, because the push trades against vault liquidity. It does not change the quote, which deletes that liquidity. One wing is still out of range. The profitable rows are that wing.

### Design 4 — price-free match, external-only completion swap, same wing

Incumbent vector is unchanged by the push. The deposit swap runs against external L only. Unmatched output is refunded. Exit returns the matched fraction. Residual opposing is liquidated through the same pool.

| Push | matched fraction, bps of D swapped | m | target profit |
| ---: | --- | ---: | ---: |
| 0 | 5,050 | 9,900 | −62 |
| 20,000 | 4,950 | 10,100 | −121 |
| 100,000 | 4,550 | 10,862 | −576 |

The push increases the raw share count because the completion swap buys more opposing, so more of D matches. It does not increase attacker wealth. The attacker paid the push. Incumbents were not the counterparty. Profit is the external fee and the floors, signed against the attacker. This is a finite witness for the identity, not a proof that every φ and every re-add rounding is harmless. The identity above is the claim. The rows are the check that a price move does not flip the sign when the mint ignores price and the swap does not self-fill.

I do not have a closed profitable self-fill witness for this vector rule at the sizes I tested. The structural hole remains: if the completion swap or the slice swap is filled by remaining vault liquidity, the attacker is the counterparty of the other holders, and the LP set changes between the outbound trade and the return. That is a different extraction from APEX-012's quote. Production `PoolManager.swap` will do it unless vault liquidity is removed first.

## What slice settlement removes, and what remains

Removes, if the payout is the removed slice plus the proceeds of that slice only:

- Payment of other holders' hypothetical liquidation proceeds. The `U` term is no longer multiplied into every holder's entitlement.
- APEX-024's sale of the whole opposing balance, if the swap size is the slice deficit and not `localOpposing`.
- The sleeve as the profit cap. The in-unlock cap exists because the inflated entitlement is paid in target from local cash. A slice that cannot be paid does not become a larger entitlement.

Does not remove:

- Over-mint from design 1, 2, 3, or 5, followed by a slice exit of the extra shares. Designs 2 and 3 are the closed examples.
- Self-fill, if the slice swap hits remaining vault L.
- APEX-025. Rebalance is a separate permissionless swap whose loss cap is two live quotes. Entry and exit swaps do not touch it.
- APEX-026, for any caller that still walks the whole book. That includes current `getRate`. A slice path can avoid the walk. The rate preview cannot, if it stays a sale quote.
- APEX-040. Donated fee growth inflates the vector too. `floor(S * D / q_T)` still rounds a victim to a small share when `q_T / S` is huge. A dead-share sink or virtual offset is a different fix. Vector mint does not do it.
- O1 recovery sharing. Buyers of shares at a depressed realizable value participate in later proceeds. That is the written policy. It is not a same-transaction JIT round trip, and a fee adjustment does not give incumbents an exclusive claim.
- A consumer that mints or borrows against `getRate`. Fixing vault issuance without that separation leaves the downstream trade.

## TWAP, actual against corrected

The actual oracle can be moved by one unlocked push, poke, and restore, provided the gap since the last write is at least the consumer window. The whole window is then credited at `prevTick + 9116` if the push is at least that large. `1.0001^9116` is about 2.488. That matches the audit's reported price ratio. `writeAge` resets, so a max-age check passes. Correcting the credit to the pre-write anchor removes that retroactive gap. It does not remove a manipulation that is left in place until the next write, and the same-block restore still leaves `prevTick` on the poked tick until a later write. Dilution is then about `9116 * heldTime / window`, not zero.

JIT does not need any of that. Depth can change `proceeds` at a constant tick. A correct TWAP is blind to it. Using the TWAP as `V_ref` in a min/max around the live quote can close the instantaneous depth round trip only by changing the valuation basis away from O1's realizable-proceeds rule. It does not close a manipulation held for the window. It is not a swap result. No consumer currently reads this oracle; that is the audit's statement, and it is not a proof about future callers.

## Strongest counterargument

The strongest claim on the other side is: if both entry and exit only swap the caller's own inventory, the caller cannot be paid from a hypothetical whole-book quote, so APEX-012 is gone.

The payout half of that claim is true. The ledgers show it is not sufficient. Design 2 still pays the quote entitlement after a real 50% swap and still clears +343. Design 3 never pays a quote; it mints at an executed or spot price and exits a real slice, and still clears +125 to +2,247 after selling the residual through the same pool and repaying the flash. The extra shares are the extraction. The swap is the pipe.

The next claim is that a full-range core makes the spot push unprofitable because the attacker must trade against the vault. That raised the cost in the in-range rows I ran, and those particular rows lost money. It is not an invariant. The quote ignores vault liquidity. One wing is out of range by construction and matches the profitable rows. A finite losing search is not a safety proof, which this question already fixed as a standard.

## Assumptions

- One pool. No independent price. No free external liquidation. Attacker residual is sold or bought in that pool before profit is stated.
- Target is token0. The other binding is the mirror image, not a second mechanism.
- Combined swap fee is 3,000 pips in the headline rows. Zero fee does not remove the quote-depth profit.
- Single tick, no bitmap dust, no protocol fee, no hook. Hookless is the production Wings pool constraint. The other simplifications are witness limits.
- Flash repayment is same-transaction. JIT capital is borrowed and returned. Profit is not a mark of leftover tokens.
- `getRate` is left as a preview, separate from issuance. I do not treat current `V/S` as that preview.
- O1's shared recovery is accepted as policy. It is not counted as the attack.
- Requirement changes named above are not implementation authority.

## Unproved

- Production wei. No Forge run. The audit numbers above are the audit's reported outputs.
- Tick-crossing sales, spacing-1 dust, and APEX-026's 512-step revert interacting with a slice swap.
- A vault that holds an in-range core and an out-of-range wing at the same time, with harvest firing because a push entered the wing. The wing ledger and the core quote ledger are separate. Their sum is not a tested production state.
- A closed profitable self-fill witness for the vector rule. The hole is structural; the searched in-range price-mint rows lost money.
- The boundary surface of push size, fee, and inventory skew. Several tested points lose. That does not prove a safe region.
- Corrected-TWAP manipulation cost against a specific production depth and window. The oracle defect and the depth-blindness are proved from the code. A profitable lending round trip against this vault was not built; the audit's lender was hypothetical and is not used here.
- Consumer damage from a still-manipulable `getRate` after issuance is fixed.
- Exact restore to the starting sqrt price. The witness repays in tokens. It does not claim the ending sqrt equals the start.

## Witness

```python
"""Single-tick mechanism witness for the Grok independent original.

Not a production Wings trace. Reproduces the headline closed profits.
Token0 is target. Fee is on input. Own liquidity is absent from quote sales.
"""

Q96 = 1 << 96
LOWER = Q96 // 2
UPPER = Q96 * 2
MAX_FEE = 1_000_000

def mul_div(a, b, d):
    return (a * b) // d

def mul_div_up(a, b, d):
    p = a * b
    return p // d + (0 if p % d == 0 else 1)

def div_up(a, d):
    return a // d + (0 if a % d == 0 else 1)

def amount0(sa, sb, L, up=False):
    if L == 0:
        return 0
    if sa > sb:
        sa, sb = sb, sa
    n1 = L << 96
    n2 = sb - sa
    return div_up(mul_div_up(n1, n2, sb), sa) if up else mul_div(n1, n2, sb) // sa

def amount1(sa, sb, L, up=False):
    if L == 0:
        return 0
    num = abs(sa - sb)
    p = L * num
    q = p // Q96
    return q + (1 if up and p % Q96 else 0)

def swap_exact_in(sqrt, L, gross, zero_for_one, fee):
    if gross == 0 or L == 0:
        return sqrt, 0, 0, 0
    less = mul_div(gross, MAX_FEE - fee, MAX_FEE)
    if zero_for_one:
        n1 = L << 96
        nxt = mul_div_up(n1, sqrt, n1 + less * sqrt)
        out = amount1(nxt, sqrt, L, False)
    else:
        nxt = sqrt + ((less << 96) // L)
        out = amount0(sqrt, nxt, L, False)
    if not (LOWER < nxt < UPPER):
        raise RuntimeError("tick cross")
    return nxt, less, out, gross - less

class W:
    def __init__(self, Lext, Lv, l0, S, fee=3000):
        self.fee = fee
        self.sqrt = Q96
        self.ext = {"L": Lext, "f0": 0, "f1": 0}
        self.jit = {"L": 0, "f0": 0, "f1": 0}
        self.vault = {"L": Lv, "f0": 0, "f1": 0, "l0": l0, "l1": 0}
        self.S = S
        self.a0 = self.a1 = self.d0 = self.d1 = 0
        self.dust0 = self.dust1 = 0
        self.base = self.tot()

    def positions(self):
        return (self.ext, self.jit, self.vault)

    def prin(self, L, sqrt=None):
        sqrt = self.sqrt if sqrt is None else sqrt
        return amount0(sqrt, UPPER, L), amount1(LOWER, sqrt, L)

    def tot(self):
        t0 = self.a0 + self.dust0 + self.vault["l0"]
        t1 = self.a1 + self.dust1 + self.vault["l1"]
        for p in self.positions():
            a0, a1 = self.prin(p["L"])
            t0 += a0 + p["f0"]
            t1 += a1 + p["f1"]
        return t0, t1

    def chk(self, label):
        if self.tot() != self.base:
            d0 = self.tot()[0] - self.base[0]
            d1 = self.tot()[1] - self.base[1]
            raise RuntimeError(f"{label} d0={d0} d1={d1}")

    def flash(self, t0, t1):
        self.a0 += t0
        self.a1 += t1
        self.d0 += t0
        self.d1 += t1
        self.base = (self.base[0] + t0, self.base[1] + t1)

    def accrue(self, fee, zero_for_one, ps):
        L = sum(p["L"] for p in ps)
        if fee == 0 or L == 0:
            return
        claimed = 0
        for p in ps:
            c = fee * p["L"] // L
            claimed += c
            p["f0" if zero_for_one else "f1"] += c
        if zero_for_one:
            self.dust0 += fee - claimed
        else:
            self.dust1 += fee - claimed

    def swap(self, gross, zero_for_one, include_vault):
        ps = [self.ext, self.jit] + ([self.vault] if include_vault else [])
        if not include_vault and self.vault["L"] != 0:
            raise RuntimeError("external swap would reprice vault principal")
        L = sum(p["L"] for p in ps)
        before = self.sqrt
        nxt, less, out, fee = swap_exact_in(before, L, gross, zero_for_one, self.fee)
        b0 = sum(amount0(before, UPPER, p["L"]) for p in ps)
        b1 = sum(amount1(LOWER, before, p["L"]) for p in ps)
        self.sqrt = nxt
        a0 = sum(amount0(self.sqrt, UPPER, p["L"]) for p in ps)
        a1 = sum(amount1(LOWER, self.sqrt, p["L"]) for p in ps)
        if zero_for_one:
            self.dust0 += less - (a0 - b0)
            self.dust1 += (b1 - a1) - out
        else:
            self.dust1 += less - (a1 - b1)
            self.dust0 += (b0 - a0) - out
        self.accrue(fee, zero_for_one, ps)
        return out, fee

    def add_L(self, who, Ladd):
        c0 = amount0(self.sqrt, UPPER, Ladd, True)
        c1 = amount1(LOWER, self.sqrt, Ladd, True)
        self.a0 -= c0
        self.a1 -= c1
        who["L"] += Ladd
        self.dust0 += c0 - amount0(self.sqrt, UPPER, Ladd)
        self.dust1 += c1 - amount1(LOWER, self.sqrt, Ladd)

    def remove_L_to(self, who, Lrem, dest):
        b0, b1 = self.prin(who["L"])
        g0 = amount0(self.sqrt, UPPER, Lrem)
        g1 = amount1(LOWER, self.sqrt, Lrem)
        f0 = 0 if who["L"] == 0 else who["f0"] * Lrem // who["L"]
        f1 = 0 if who["L"] == 0 else who["f1"] * Lrem // who["L"]
        who["f0"] -= f0
        who["f1"] -= f1
        who["L"] -= Lrem
        a0, a1 = self.prin(who["L"])
        self.dust0 += b0 - a0 - g0
        self.dust1 += b1 - a1 - g1
        dest[0] += g0 + f0
        dest[1] += g1 + f1

    def vector(self):
        p0, p1 = self.prin(self.vault["L"])
        v = self.vault
        return v["l0"] + p0 + v["f0"], v["l1"] + p1 + v["f1"]

    def quote(self):
        t, o = self.vector()
        L = self.ext["L"] + self.jit["L"]
        if o == 0 or L == 0:
            return t, 0
        _, _, out, _ = swap_exact_in(self.sqrt, L, o, False, self.fee)
        return t + out, out

def quote_jit(Ljit, D=20_000, fee=3000, Lext=1_000_000, Lv=200_000, l0=80_000, S=100_000):
    w = W(Lext, Lv, l0, S, fee)
    V0, _ = w.quote()
    m = S * D // V0
    w.flash(D, 0)
    w.a0 -= D
    w.vault["l0"] += D
    if Ljit:
        c0 = amount0(w.sqrt, UPPER, Ljit, True)
        c1 = amount1(LOWER, w.sqrt, Ljit, True)
        w.flash(c0, c1)
        w.add_L(w.jit, Ljit)
    V1, _ = w.quote()
    payout = m * V1 // (S + m)
    if w.vault["l0"] < payout + 1:
        raise RuntimeError("sleeve")
    w.vault["l0"] -= payout
    w.a0 += payout
    if Ljit:
        box = [0, 0]
        w.remove_L_to(w.jit, Ljit, box)
        w.a0 += box[0]
        w.a1 += box[1]
    w.chk("quote")
    return {"V0": V0, "V1": V1, "m": m, "payout": payout, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1}

def quote_plus_swap(phi_bps, Ljit=1_000_000, D=20_000):
    w = W(1_000_000, 200_000, 80_000, 100_000, 3000)
    V0, _ = w.quote()
    m = w.S * D // V0
    w.flash(D, 0)
    w.a0 -= D
    w.vault["l0"] += D
    x = D * phi_bps // 10000
    y, _ = w.swap(x, True, True)
    w.vault["l0"] -= x
    w.vault["l1"] += y
    c0 = amount0(w.sqrt, UPPER, Ljit, True)
    c1 = amount1(LOWER, w.sqrt, Ljit, True)
    w.flash(c0, c1)
    w.add_L(w.jit, Ljit)
    V1, _ = w.quote()
    payout = m * V1 // (w.S + m)
    w.vault["l0"] -= payout
    w.a0 += payout
    box = [0, 0]
    w.remove_L_to(w.jit, Ljit, box)
    w.a0 += box[0]
    w.a1 += box[1]
    if w.vault["L"]:
        parked = [w.vault["l0"], w.vault["l1"]]
        w.remove_L_to(w.vault, w.vault["L"], parked)
        w.vault["l0"], w.vault["l1"] = parked
    if w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            if out >= need:
                best = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best, True, False)
        w.a0 -= best
        w.a1 += out
    w.chk("design2")
    return {"profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1, "m": m, "V1": V1, "payout": payout}

def out_of_range(push, D=20_000, S=100_000, AT=100_000, AO=100_000, Lext=1_000_000, fee=3000, phi_bps=None):
    w = W(Lext, 0, AT, S, fee)
    w.vault["l1"] = AO
    w.base = w.tot()
    w.flash(D, push)
    if push:
        out, _ = w.swap(push, False, False)
        w.a1 -= push
        w.a0 += out
    if phi_bps is None:
        V = AT + (Q96 * Q96 * AO) // (w.sqrt * w.sqrt)
        w.a0 -= D
        w.vault["l0"] += D
    else:
        x = D * phi_bps // 10000
        y, _ = w.swap(x, True, False)
        w.a0 -= D
        w.vault["l0"] += D - x
        w.vault["l1"] += y
        V = AT + (x * AO) // y
    m = S * D // V
    if push and w.sqrt > Q96 and w.a0:
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, 0
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                nxt, _, _, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if nxt >= Q96:
                best = mid
                lo = mid + 1
            else:
                hi = mid - 1
        if best:
            back, _ = w.swap(best, True, False)
            w.a0 -= best
            w.a1 += back
    supply = S + m
    took_t = w.vault["l0"] * m // supply
    took_o = w.vault["l1"] * m // supply
    w.vault["l0"] -= took_t
    w.vault["l1"] -= took_o
    w.a0 += took_t
    w.a1 += took_o
    w.chk("oor")
    if w.a1 > w.d1:
        extra = w.a1 - w.d1
        out, _ = w.swap(extra, False, False)
        w.a1 -= extra
        w.a0 += out
    elif w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if out >= need:
                best = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best, True, False)
        w.a0 -= best
        w.a1 += out
    w.chk("oor-liq")
    return {"m": m, "V": V, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1,
            "vault_t": w.vault["l0"], "vault_o": w.vault["l1"]}

def vector_oor(push, D=20_000, S=100_000, AT=100_000, AO=100_000, Lext=1_000_000, fee=3000):
    w = W(Lext, 0, AT, S, fee)
    w.vault["l1"] = AO
    w.base = w.tot()
    w.flash(D, push)
    if push:
        out, _ = w.swap(push, False, False)
        w.a1 -= push
        w.a0 += out
    best = None
    for bps in range(0, 10001, 50):
        x = D * bps // 10000
        if x == 0:
            continue
        try:
            _, _, y, _ = swap_exact_in(w.sqrt, w.ext["L"], x, True, w.fee)
        except RuntimeError:
            continue
        scale = min((D - x) * 10**18 // AT, y * 10**18 // AO)
        unmatched = (D - x - AT * scale // 10**18) + (y - AO * scale // 10**18)
        if best is None or unmatched < best[0]:
            best = (unmatched, x, bps)
    x = best[1]
    y, _ = w.swap(x, True, False)
    w.a0 -= D
    w.vault["l0"] += D - x
    w.vault["l1"] += y
    scale = min((D - x) * 10**18 // AT, y * 10**18 // AO)
    matched_t = AT * scale // 10**18
    matched_o = AO * scale // 10**18
    w.vault["l0"] -= (D - x - matched_t)
    w.vault["l1"] -= (y - matched_o)
    w.a0 += D - x - matched_t
    w.a1 += y - matched_o
    m = S * matched_t // AT
    supply = S + m
    took_t = w.vault["l0"] * m // supply
    took_o = w.vault["l1"] * m // supply
    w.vault["l0"] -= took_t
    w.vault["l1"] -= took_o
    w.a0 += took_t
    w.a1 += took_o
    w.chk("vector")
    if w.a1 > w.d1:
        extra = w.a1 - w.d1
        out, _ = w.swap(extra, False, False)
        w.a1 -= extra
        w.a0 += out
    elif w.a1 < w.d1:
        need = w.d1 - w.a1
        L = w.ext["L"]
        lo, hi, best_in = 0, w.a0, None
        while lo <= hi:
            mid = (lo + hi) // 2
            try:
                _, _, out, _ = swap_exact_in(w.sqrt, L, mid, True, w.fee)
            except RuntimeError:
                hi = mid - 1
                continue
            if out >= need:
                best_in = mid
                hi = mid - 1
            else:
                lo = mid + 1
        out, _ = w.swap(best_in, True, False)
        w.a0 -= best_in
        w.a1 += out
    w.chk("vector-liq")
    return {"m": m, "profit0": w.a0 - w.d0, "profit1": w.a1 - w.d1}

def main():
    expect = {
        "control": quote_jit(0)["profit0"],
        "jit1e6": quote_jit(1_000_000)["profit0"],
        "jit5e6": quote_jit(5_000_000)["profit0"],
        "design2_50": quote_plus_swap(5000)["profit0"],
        "spot20k": out_of_range(20_000)["profit0"],
        "spot100k": out_of_range(100_000)["profit0"],
        "pexec_skew": out_of_range(20_000, phi_bps=5000, Lext=100_000, AT=50_000, AO=400_000, D=20_000, S=50_000)["profit0"],
        "vector20k": vector_oor(20_000)["profit0"],
    }
    want = {
        "control": -1,
        "jit1e6": 295,
        "jit5e6": 508,
        "design2_50": 343,
        "spot20k": 125,
        "spot100k": 1014,
        "pexec_skew": 1087,
        "vector20k": -121,
    }
    for k, v in want.items():
        if expect[k] != v:
            raise SystemExit(f"{k}: got {expect[k]} want {v}")
    print(expect)

if __name__ == "__main__":
    main()
```
