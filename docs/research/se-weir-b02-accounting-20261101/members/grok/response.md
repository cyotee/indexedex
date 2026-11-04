# Member response

## Identity

- Run ID: se-weir-b02-accounting-20261101
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does WeirVaults' own internal accounting resolve the B-02 losses, or does a caller-moved pool price still leave that loss with the other holders?
- Required targets: `contracts/protocols/strategy/weir/WeirVaults.sol`; `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`; B-02 in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`; APEX-2026-023 and APEX-2026-024 in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`; FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, and FS-MONEY-01 in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`.
- Optional context: `TickMath.sol` and `FixedPoint96.sol`, read for `minUsableTick`, `maxUsableTick`, `MIN_SQRT_PRICE`, `MAX_SQRT_PRICE`, and `Q96`. `FullMath.sol` was not opened; the simulation uses truncating integer division for the `mulDiv` shape.
- Admitted read scope: the brief, the required targets, and those two math libraries. Peer responses, the draft, and the final were not read. Public search: not used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Who calls `compound` | `WeirVaults.sol:206-211` | source observation | The notice says anyone can call it. The function is `external` and `nonReentrant`. There is no owner check. |
| Compound before money | `WeirVaults.sol:229-238` | source observation | `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. It does not call `_compound` after the withdraw swap. |
| Sizing price | `WeirVaults.sol:255-262`, `360-367` | source observation | Both `_deposit` and `_compound` size with `poolManager.getSlot0` at the call. `_deposit` reads that price after `_balance` returns. Neither read is compared with a stored price. |
| Swap limit | `WeirVaults.sol:413-422` | source observation | `sqrtPriceLimitX96` is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. The function does not take a pre-operation price, a TWAP, or any other reference. No other function in this file reads a TWAP. |
| Withdraw swap amount | `WeirVaults.sol:289-322` | source observation | Liquidity removed is `v.liquidity * shares / totalShares`. Idle removed is the same fraction. `zapTo == 1` swaps `uint256(net1)` only if `net1 > 0`. `zapTo == 2` swaps `uint256(net0)` only if `net0 > 0`. That net is the removed position amount plus pro-rata idle. It is not a shortfall and not the vault's remaining balance. |
| `_balance` | `WeirVaults.sol:387-410` | source observation | The inputs are the caller's `a0` and `a1`. Value uses the live `sqrtP` twice through `Q96`. The larger side swaps `(excess) / 2`. Holder balances are not arguments. |
| Share denominator | `WeirVaults.sol:264-273`, `114-127` | source observation | Existing supply uses `frame.liq * v.totalShares / v.liquidity`. Idle is not in that division. `previewRedeem` adds pro-rata idle, but that view is not the mint. `_compound` adds liquidity and does not write `totalShares`. |
| Deposit remainder | `WeirVaults.sol:179-180`, `248-285` | source observation | `deposit` sends `amount - used` back to the payer. `_deposit` does not write `idle0` or `idle1`. |
| Idle writers | `WeirVaults.sol:40-41`, `344-378`, `293-294` | source observation | The comment calls idle dust. The formula has no size cap. `_compound` sets idle from the leftover after a live-price mint, including when harvested fees are zero, provided `v.liquidity != 0` and a side exceeds 2. `_withdraw` only decreases idle by the pro-rata share. |
| In-range one-sided mint | `LiquidityAmounts.sol:36-41` | source observation | While `sqrtA < sqrtP < sqrtB`, liquidity is `min(l0, l1)`. A zero amount makes that minimum zero. |
| Audit formula | APEX-2026-023 | source observation | The finding records `IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'` as a full-range approximation in token1. It says the mint is sized from live `slot0`, nothing checks that price, and honest LPs bear the loss. |
| 024 amount | APEX-2026-024 | source observation | `_swapDeficit` sells `opposing`, the whole opposing balance, with the same MIN/MAX limit. The finding says that is not the shortfall. |
| B-02 | blockers file, B-02 | source observation | Decision is open. The question is whether live-price placement and the unbounded swap limit are accepted for entry, `compound()`, and redemption. |
| Copied limit | PRD FS-MONEY-01 | source observation | "The entry swap, when one is needed, uses `_swap`. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. That is not `maxZapTickMove`, and no tighter cap is added." |
| Copied shares and order | PRD FS-MONEY-01 | source observation | "For an existing supply, `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. The denominator is existing liquidity after the preceding compound and before this deposit is added. Idle balances are not in that denominator." And: "`unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`." |
| Copied compound, not the fee | PRD FS-MONEY-01 | source observation | "`_compound` harvests fees by a zero-liquidity modification and reinvests the remainder plus idle. Leftover is held as idle. The source also takes `perfFeeBps` to `treasury`. That cut is not added here." |
| zapTo not installed | PRD FS-MONEY-01 | source observation | "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle. This family does not install `zapTo`. The accepted one-token exit still pays only the selected token or reverts." |
| No tick bound | PRD FS-OWN-10 | source observation | "`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added." |
| Sleeve move is not Weir | PRD FS-OWN-12, FS-OWN-04 | source observation | FS-OWN-12 moves each token's local balance toward a percentage of that token's owned amount, with a 5% band, and does not revert if inexact. FS-OWN-04 says "Do not combine the tokens through a price." Weir has no `liquidReservePercentage`. |
| Permissionless idle deploy | PRD FS-OWN-14 | source observation | "`compound()` deploys booked idle." "Any address may call it." The same lock also says: "If there are no fees, return without a state change and without an event." |
| Redemption swap, no amount cap | PRD FS-OWN-15, FS-OWN-30 | source observation | FS-OWN-15: "A redemption takes deployed liquidity first and may swap through the pool. The purpose is pool volume." FS-OWN-30 pays "the caller's fraction of the deployed position and the caller's fraction of the booked local reserve." Neither sentence says the swap input is the withdrawn unwanted-token net. |
| Half excess already written | PRD FS-OWN-33 | source observation | "A one-sided share mint swaps about half of the excess through the pool so the deposit matches the pool ratio. A bundle deposit does not run that swap." |
| Simulation | `members/grok/sim/b02_accounting.py` | supplied runtime | Command and exit status are below. Asserts passed. |

Command:

```text
python3 docs/research/se-weir-b02-accounting-20261101/members/grok/sim/b02_accounting.py
```

Exit status: 0. The script printed `all_asserts_passed 1`.

Fixture printed by that run: infinite-range limit of `LiquidityAmounts`; `P0 = 1`; displaced prices 2 and 4; existing liquidity and shares both `1000000000000000000`; bundle each side `100000000000000000`; idle not in the share denominator; no TWAP, fee cap, tick bound, exit fee, or pool fee. `createVault` ticks were not used in those totals.

### Case 1, direct sizing, no swap model

Two-sided bundle at `P' = 2`:

- token0 placed `50000000000000000`
- token1 placed `100000000000000000`
- token0 recovered `70710678118654752.44008443621`
- token1 recovered `70710678118654752.44008443621`
- leftover0 `49999999999999999.999999999999`
- leftover1 `0`
- liquidity `70710678118654752.44008443621`
- shortfall in token1 at `P0` `8578643762690495.119831127579`
- audit IL `8578643762690495.119831127579`
- audit minus direct `0`
- deposit shares minted `70710678118654752`
- deposit existing-holder liquidity claim minus old `0.411020871654`
- compound shares minted `0`
- compound existing holders bear that shortfall; caller bears `0`

Two-sided bundle at `P' = 4`:

- token0 placed `25000000000000000`
- token1 placed `100000000000000000`
- token0 recovered `50000000000000000`
- token1 recovered `50000000000000000`
- leftover0 `75000000000000000`
- shortfall `25000000000000000`
- audit minus direct `0`
- deposit shares minted `50000000000000000`
- deposit existing-holder liquidity claim minus old `0`
- compound shares minted `0`; existing holders bear `25000000000000000`

One-sided token0 and one-sided token1, at both `P' = 2` and `P' = 4`: liquidity `0`, shortfall `0`, audit IL `0`. The finite-tick check at `minUsableTick(-887272)` and `maxUsableTick(887272)` also minted 0 from either one-sided amount at the floored `P = 2` sqrt price and at the exact `P = 4` sqrt price.

Zero-fee infinite-range round trip, compound path, attacker pushes and returns in the same pool: attacker PnL equals holder loss equals the direct shortfall, at both displaced prices, with outside liquidity `0` and with outside liquidity `1000000000000000000`. Attacker minus holder loss printed `0`.

Same round trip, deposit path, no `_balance` swap, excess refunded: at `P' = 2`, attacker PnL `8578643762690495.119831127579`, depositor PnL the negation, existing-holder PnL `0`, sum `0`. At `P' = 4`, attacker PnL `25000000000000000`, depositor PnL the negation, existing-holder PnL `0`, sum `0`. Floor-share dust versus the rational share at `P' = 2` was `-0.44008443621`. At `P' = 4` it was `0`.

### Case 2, self-moved trailing placement

Stated exit fraction `2/3`. Stated idle `100000000000000000` on each side. That idle is a stated input, not a balance `deposit` writes.

Identity, no swap model:

- swap amount token0 `733333333333333333.333333333333`
- withdrawn position token0 `666666666666666666.666666666666`
- pro-rata idle0 `66666666666666666.666666666666`
- whole opposing token0 `1100000000000000000`
- swap minus whole `-366666666666666666.666666666666`
- remaining position token0 not swapped `333333333333333333.333333333333`
- remaining idle0 not swapped `33333333333333333.333333333333`

Swap model, zero-fee infinite range: price after the withdraw swap `0.09765625`. Limit binds: false. Sqrt limit `(MIN_SQRT_PRICE + 1) / Q96 = 1073782185/19807040628566084398385987584`.

No following compound: stayer value at `P0` `733333333333333333.333333333333`, stayer loss `0`.

Following compound at that live price, no shares minted:

- liquidity `10416666666666666.666666666666`
- token0 placed `33333333333333333.333333333333`
- token1 placed `3255208333333333.333333333333`
- token0 recovered `10416666666666666.666666666666`
- token1 recovered `10416666666666666.666666666666`
- shortfall `15755208333333333.333333333333`
- stayer value at `P0` `717578125000000000`
- stayer loss versus no compound `15755208333333333.333333333333`

Both sides equal to 2 at that price would produce library liquidity `0.625`. The source skips the mint when both sides are `<= 2`.

### Case 3, whole-balance dump versus Weir withdraw

Same exit fraction `2/3`. Idle `0`. Same absolute limit.

Identity:

- Weir swap amount token0 `666666666666666666.666666666666`
- 024-shape swap amount token0 `1000000000000000000`
- stayer token0 in the 024 amount and not in the Weir amount `333333333333333333.333333333333`
- Weir stayer value at `P0` `666666666666666666.666666666666`
- Weir stayer loss `0`

Outside liquidity `0`: the 024 shape is not executable, because closing the only liquidity leaves no counterparty. Weir stayer loss remains `0`.

Outside liquidity `1000000000000000000`, zero-fee infinite-range model, post-dump inventory shared pro rata. This split is a model choice. It is not the Wings liquidation quote.

- price after `0.25`
- limit binds: false
- token1 out `500000000000000000`
- total loss at `P0` `500000000000000000`
- 024 stayer value `500000000000000000`
- 024 stayer loss `166666666666666666.666666666666`
- Weir stayer loss `0`
- backrunner PnL `500000000000000000`, equal to the total loss

### Case 4, half-excess `_balance`

Identity: at `P' = 2`, direction `zeroForOne`, half excess `25000000000000000`, which is `0.25` of the caller's token0. At `P' = 4`, half excess `37500000000000000`, which is `0.375` of the caller's token0. Holder balances are not inputs. The live spot is not compared with `P0`.

The integer source formula at exact `P = 4` (`sqrtPriceX96 = 2 * Q96`) returned the same `37500000000000000`. Wei difference `0`.

Swap model, then mint at the post-swap price, then return to `P0`:

`P' = 2`: post-swap price `1.86574007874`. Token0 placed `75000000000000000`. Token1 placed `139930505905550185.174759898752`. Recovered each `102444072268317525.567085511204`. Placed shortfall `10042361368915134.040588876343`. Attacker PnL `-13250237426612907.199959698469`. Caller PnL the negation. Existing-holder PnL `0`. Sum `0`.

`P' = 4`: post-swap price `3.461330448891`. Token0 placed `62500000000000000`. Token1 placed `216333153055705786.911844240129`. Recovered each `116279069767441860.465116279069`. Placed shortfall `46275013520822065.98161168199`. Attacker PnL `-55759870200108166.576527852893`. Caller PnL the negation. Existing-holder PnL `0`. Sum `0`.

### Finite ticks and fee cut, not mixed into the fixture totals

At `P = 1`, liquidity `10^24`, tick spacing 1: each finite amount is `54213` below the infinite-range amount. Relative missing amount `0.000000000000000000054213`.

At exact `P = 4`, finite-range shortfall minus infinite-range shortfall is `6777` on an infinite-range shortfall of `250000000000000000000000`. Relative gap `6777/250000000000000000000000`. That gap does not move the loss from one holder to another.

`perfFeeBps` default `500`, harvested fees only. On a fee bundle of `10^17` each side, treasury takes `5000000000000000` of each token before placement. Holder shortfall on the remainder: `8149711574555970.3638395712` at `P' = 2`, and `23750000000000000` at `P' = 4`. Shares minted `0`.

## Assumptions

- The reported fixture uses the infinite-range limit of the library formulas: `amount0 = L / sqrt(P)`, `amount1 = L * sqrt(P)`, and `L = min(amount0 * sqrt(P), amount1 / sqrt(P))`. `createVault` stores `TickMath.minUsableTick(key.tickSpacing)` and `TickMath.maxUsableTick(key.tickSpacing)`. Those finite bounds are the sensitivity section only.
- The price-moving legs use `x * y = L^2` with a zero pool fee. Inside the infinite-range zero-fee limit that identity is exact. It is an approximation of a finite tick range and of a nonzero pool fee. `WeirVaults` does not set the pool fee. No fee cap, TWAP check, tick bound, or exit fee was added.
- The accounting identities do not use that swap model. They are the swapped amount, whose tokens those are, and which price sizes the liquidity. Amounts of unchanged liquidity at a returned price are `getAmountsForLiquidity(L, P0)`. That is a library identity, not a swap result.
- Existing supply is already past genesis. `MIN_SHARES` is not re-simulated. Idle is excluded from the mint denominator because the source excludes it.
- Case 2 idle of `10^17` each side is stated so the trailing mint is visible. It is not a balance the deposit path writes.
- Case 3 outside liquidity of `10^18`, and the pro-rata split of post-dump inventory, are stated so the 024 shape has a counterparty and a holder split. The Wings liquidation quote was not encoded.
- Valuation price after a return is the same pool's `P0`. No independent price was used.
- Public search: not used.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `WeirVaults.sol` deposit, withdraw, compound, unlockCallback, `_deposit`, `_withdraw`, `_compound`, `_balance`, `_swap` | required | examined | Read in full with the rest of that file. |
| `LiquidityAmounts.sol` | required | examined | Both directions read. Infinite-range limit used for the fixture. Finite ticks reported separately. |
| B-02 | required | examined | Open question read. Not answered as a lock. |
| APEX-2026-023 and APEX-2026-024 | required | examined | Finding text read. Foundry PoCs not run. |
| FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, FS-MONEY-01 | required | examined | Operative sentences quoted. FS-OWN-04, FS-OWN-30, and FS-OWN-33 were read in the same file and are cited only as comparison. |
| `TickMath.sol`, `FixedPoint96.sol` | optional | examined | Bounds and `Q96` only. |
| `FullMath.sol` | optional | not examined | Truncating division stands in for `mulDiv` in the integer check. |
| Deleted old FullSpread sources | optional | absent | Not reconstructed. The audit text is the finding record. |

## Conclusions

Source observation, not a verdict. `compound` is permissionless. `deposit` and `withdraw` both call `_compound` before the money operation, not after the withdraw swap. New liquidity is sized at the live `slot0` on deposit and on compound. `_swap` uses the absolute MIN/MAX limit and compares it with nothing. A one-token withdraw swaps the withdrawn net of the unwanted token, including pro-rata idle, not a shortfall and not the vault's remaining balance. `_balance` swaps half the caller's excess at the live spot. The existing-supply denominator is liquidity. Idle does not enter it. `_compound` mints no shares.

Inference from those observations and from the executed simulation. The three B-02 losses are not one result.

External-push loss. Weir does not resolve it for a compound of two-sided idle or harvested fees. `_compound` at lines 360-370 sizes that input at the live price and adds the liquidity without minting shares. Line 207 lets any caller cause that. The other holders bear the shortfall. In the fixture that shortfall is `8578643762690495.119831127579` at `P' = 2` and `25000000000000000` at `P' = 4`, and it equals the audit formula. A same-pool round trip extracts that amount from the holders whether or not outside liquidity is present. The caller of `compound` receives none of the new liquidity.

Weir does resolve that loss for the other holders when the placed tokens are the depositor's own deposit. Line 272 mints shares against the added liquidity, and lines 179-180 refund the unplaced excess. After a return to `P0`, existing-holder PnL is `0`. The depositor bears the shortfall. Floor division in this fixture can leave existing holders a rounding gain below one liquidity unit. That dust is not the placement loss. One-sided in-range idle is not placed, so it is not this loss. `deposit` does not create the two-sided idle the old blocked-deposit path left behind.

Self-moved trailing placement. Weir does not perform the old same-call trailing mint. Lines 236-238 compound before the withdraw swap. The swap sells only the withdrawn slice: in the stated fixture, `733333333333333333.333333333333` token0 against a whole opposing balance of `1100000000000000000`. After a return to `P0`, that swap alone leaves staying-holder value unchanged. A later `compound` does not resolve the trailing placement. It sizes the remaining idle at the post-swap live price and mints no shares, so the other holders bear that shortfall. In the stated idle fixture the loss is `15755208333333333.333333333333`. If both remaining sides are `<= 2`, line 358 places nothing. The source does not create the stated idle on deposit.

Whole-balance redemption dump. Weir resolves it. Lines 316 and 320 pass the withdrawn net, not the vault balance. Stayer liquidity is not the swap input. At `P0`, unchanged liquidity holds the `P0` amounts, so staying-holder deployed value is unchanged. The 024 shape sells the stayers' opposing tokens. With the stated outside liquidity and a pro-rata split, their loss is `166666666666666666.666666666666` and the backrunner's PnL equals the full slippage. The shared MIN/MAX limit does not bind in these fixtures. The amount is the distinction, not the limit. Line 418 is not a guard against this dump.

`_balance` does not protect existing holders from a displaced spot. It only ratio-matches the caller's own input at the live price, then the following `getSlot0` places that input at the post-swap live price. Existing-holder PnL after a return to `P0` is `0` because their liquidity is unchanged and the new liquidity is assigned to the caller, not because `_balance` checks the displacement. In this fixture the caller gains at `P0` and the pusher loses, because selling token0 at `P' > P0` is favorable when marked back at `P0`, and that gain exceeds the placement shortfall.

What the named locks already copy. Selecting Weir is not, by itself, a new rule.

- FS-MONEY-01 already copies the unbounded entry-swap limit, the liquidity-only share denominator, compound-before-deposit and compound-before-withdraw, reinvestment of remainder plus idle, and pro-rata removal. It already says the treasury fee is not added. It already says `zapTo` is not installed.
- FS-OWN-10 already forbids a replacement tick bound. That is an absence of a guard, not a price check.
- FS-OWN-14 already says any address may call `compound` and that `compound` deploys booked idle. Its no-fee return sentence is not what `WeirVaults.sol:344-367` does. Weir still places idle when the fee harvest is zero. B-03 records that conflict. This response does not pick a winner.
- FS-OWN-12 is not a Weir rule. It does not, by its own sentence, combine the tokens through a price.
- FS-OWN-15 already allows a redemption swap and does not cap it at the withdrawn net. FS-OWN-30 already copies pro-rata payment. It does not state the swap amount. FS-OWN-33 already copies the half-excess swap for a one-sided mint, at the pool ratio, with no TWAP check.

The withdrawn-net cap is a Weir source fact at lines 316 and 320. It is not a sentence in FS-MONEY-01 or FS-OWN-15. This response does not write one, and it does not say that a replacement was accepted.

## Limits

- Runtime or extraction proof: one local Python 3 run, standard library only, exit 0. The Foundry audit PoCs were not run. Their wei figures are the audit's record, not this fixture.
- Not examined: `WeirBase`, pool-fee configuration, a specific `tickSpacing` other than the spacing-1 sensitivity, the Wings liquidation-quote split, and `FullMath.mulDiv` beyond truncating division. The deleted FullSpread sources were not reconstructed.
- The finite-tick gap is 6777 wei on a `2.5 * 10^23` shortfall. It does not change which holder bears the loss. It is not part of the fixture totals.
- B-03 stays open. A no-fee return, if that sentence won, would block idle-only compound and would leave the fee-placement path. This response does not decide that.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not edit the PRD or the blockers file. It does not lock B-02.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
- Agreement is not available. Peers were not read. This is not a council consensus.
