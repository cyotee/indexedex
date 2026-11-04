# Member response

## Identity

- Run ID: v4-wings-complete-design-20261025-01a171a0
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh (coordinator-supplied in the brief)
- Actual role, model, reasoning, task ID, and session ID: role is the assigned council member. The session prompt exposes the model as Grok 4.7. Provider route, reasoning effort, task ID, and session ID are not exposed. This self-description is not proof of the runtime route.
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Recommend the entire replacement design for the Uniswap V4 Upper Lower Wings Standard Exchange vault, including ownership, deposits, share issuance, fees, compounding, maintenance, withdrawals, previews, getRate, and use in external liquidity pools.
- Required targets: this brief; CLAUDE.md; audit APEX-2026-012, 024, 025, 026, and 040; the current V4 Wings source family named in the brief; StandardExchangeRateProviderFacet; direct Uniswap V4 buffer-hook rate consumers sufficient to say whether they value shares without redemption.
- Optional context: historical PRDs, the apportioned-reserve PRD, open questions, the remediation tracker, prior council report, and production tests. Not read. They are not constraints on this recommendation.
- Admitted read scope: the brief's admitted project sources and public primary sources. No public query was used. Peer response and draft paths were not opened.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Assignment and freedom to change expectations | brief.md, Current conversation | coordinator-supplied | Full-credit imbalance, one-share getRate as a target exit preview, actual-proceeds exits, and authority to recommend requirement changes. getRate must not be redefined as NAV. No reference source has been chosen. |
| Family routing | CLAUDE.md | source observation | Supported Uni V4 SE family is upperLowerWings. Both V4 FullSpread families are deleted and must not be restored. Weird-token law: fee-on-transfer and rebasing underlyings forbidden; non-18 decimals allowed. |
| Share issue and redeem math | Accounting.sol:18-27 | source observation | `issue = credit` when supply is 0, else `floor(supply * credit / value)`. `entitlement = floor(shares * value / supply)`. No dead-share sink. |
| Live-quote share price | Money.sol:120-140, 147-181; EconomicTarget.sol:27-31; QuoteBase.sol:13-18 | source observation | Deposit and redeem set value from `Quote.quote`. getRate is `floor(whole-book quote * 1e18 / supply)`, not a simulated one-share sale. `liquidationValue` is the same quote. |
| Unlocked-manager acceptance | Money.sol:41-48, 94-105, 167-170; Common.sol:38-46 | source observation | `begin` does not revert when the PoolManager is unlocked. Harvest and place return immediately when unlocked. `Common.execute` does revert if already unlocked. |
| Whole-book opposing dump | Money.sol:219-233 | source observation | `_swapDeficit` sells the entire opposing local balance at `MIN_SQRT_PRICE+1` or `MAX_SQRT_PRICE-1`. |
| HolderValueLoss | Money.sol:174-177 | source observation | Compares a post-exit live quote with the pre-exit live quote, plus `swapCost` of the whole opposing balance. |
| Quote step cap | Common.sol:31; LiquidationQuote.sol:25, 108-133 | source observation | `stepLimit` is hard-coded to 512. The quote sells opposing inventory through live external liquidity after removing owned positions. Header states it reads the live hookless pool and does not execute. |
| Geometry and placement | Geometry.sol:16-41; Harvest.sol:118-167, 168-194 | source observation | Core is the full usable range. Wings are the nearest strictly separated ranges. Token0 uses the upper wing; token1 uses the lower wing. Placement keeps a target sleeve, then adds core, then wings. Wing harvest closes a wing that has acquired the other token. |
| Fee collection on any modify | PoolManager.sol:94-120; Pool.sol:147-190; IPoolManager.sol:130-134 | source observation | `callerDelta = principalDelta + feesAccrued`. Any modify, including a poke, returns the position's entire uncollected fees. The interface warns that `feesAccrued` can be inflated by `donate`, especially in one unlock. |
| Execution settlement | ExecutionDelegate.sol:22-73 | source observation | The callback settles the combined caller delta. It does not separate fees from principal. |
| Share decimals | DFPkg.sol:115, 124-136 | source observation | Shares use the target token's decimals. The pool must be hookless. Any tick spacing in 1..32767 is accepted. |
| No V4 observe in the vendored tree | grep of `lib/crane/contracts/protocols/dexes/uniswap/v4` for `function observe` / `observations` | source observation | The only hits were Pancake V3 dependency interfaces, not PoolManager. This is not a line-by-line proof that no oracle exists under another name. |
| Permissionless rebalance | RebalanceTarget.sol:22-65; RebalancePlanner.sol:11-47 | source observation | Anyone may rebalance. The loss cap re-quotes live liquidation value after the vault's own swap. The planner's price limit is the projected post-sale sqrt price. |
| Balancer rate adapter | StandardExchangeRateProviderFacet.sol:45-90 | source observation | Does not call the vault's `getRate`. Prices `totalSupply` through `previewExchangeIn` or projected `quoteAssets`, then normalizes. A failed full-book quote returns 0. Comment says a failed full-book quote must not become a smaller trade. |
| Buffer hook rates without redemption | single CP ClaimLib.sol:407-440, 456-468; Math.sol:19-31; dual ClaimLib.sol:203 | source observation | The single-asset CP hook staticcalls `IRateProvider.getRate` and multiplies share balance by that rate. `ratedReserve` does not redeem. The dual hook has the same staticcall at line 203; the surrounding function was not fully read. Hook tests observed in grep wire CP fixtures through `RateProviderFixtureLib`, not this Wings vault. Wings-to-hook production wiring was not established. |
| APEX-2026-012 | DiffReview, heading at line 268 | source observation of the audit text | High, latent, not deployed. Share price is the live liquidation quote. Cited in-unlock JIT profit 70,634,405,953 raw token0 on a 1e12 vault; settled variant 74,704,386,253. I did not run the PoC. |
| APEX-2026-024 | DiffReview, heading at line 1605 | source observation of the audit text | Low, latent. Large redeem sells the whole opposing balance at a protocol-extreme price limit. Same-state HolderValueLoss passes by construction. |
| APEX-2026-025 | DiffReview, heading at line 1109 | source observation of the audit text | Medium, latent. Permissionless rebalance measures its loss cap at the manipulated or self-moved spot. |
| APEX-2026-026 | DiffReview, heading at line 1173 | source observation of the audit text | Medium, latent. stepLimit 512 freezes deposit, redeem, getRate, and liquidationValue. Audit quotes a PRD rule that work exhaustion must revert rather than be marked market-limited. I did not re-read that PRD. |
| APEX-2026-040 | DiffReview, heading at line 2141 | source observation of the audit text | Low, latent. No dead-share sink. Donated fee growth plus rounding can mint 1 share for the next depositor. Audit quotes historical rulings against a virtual offset. I did not re-read those rulings. |
| Public query | none | source observation | not used |

`_sell`'s tick-walk body below LiquidationQuote.sol:220 was not read. Audit descriptions of that walk are audit text, not my execution trace.

## Assumptions

- One fungible share that can sit in an external pool remains a product goal. Dropping it would make separate section tokens the better design. I do not drop it.
- "Independent reference" means a price source that is not this pool's slot0, not this vault's getRate, and not an adapter that derives its rate from this vault. No such adapter is present in the Wings package today.
- Share decimals stay equal to target decimals so the existing 1e18 raw-parity rate scale and the buffer-hook scale still mean the same thing. A later split of those decimals is an owner decision and would require the hook's 36-scale, not a raw multiply.
- Audit PoC numbers are evidence of what the audit reported, not results I reproduced.
- The audit's "not deployed" status was not checked against a live chain.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| brief.md | required | examined | Read through the decision questions and output rules. |
| CLAUDE.md | required | examined | Router read, including the Wings family boundary and weird-token law. Full agent-law file not required by the brief and not read. |
| APEX-2026-012 | required | examined | Finding text read from the cited heading. PoC not run. |
| APEX-2026-024 | required | examined | Finding text read. PoC not run. |
| APEX-2026-025 | required | examined | Finding text read. PoC not run. |
| APEX-2026-026 | required | examined | Finding text read. PoC not run. |
| APEX-2026-040 | required | examined | Finding text read. PoC not run. |
| Wings Money, Accounting, EconomicTarget, Projection, In/Out/SY targets, Geometry, Inventory, Harvest placement, Repo, Types, Common, ExecutionDelegate, DFPkg validate, Rebalance | required | examined | Read as cited above. |
| LiquidationQuote | required | partially examined | Request, result, quote entry, and remove-owned setup read. `_sell` body not read. |
| Query facet/target and SY exchangeRate | required | examined | `liquidationValue` delegates to the same quote. `exchangeRate` scales that quote by supply. |
| StandardExchangeRateProviderFacet | required | examined | Full file read. |
| V4 buffer-hook rate use | required | partially examined | Single CP rate path and math read. Dual staticcall located. Other hook families not read. |
| Historical PRDs, prior council report, open questions, tracker | optional | not examined | Disclosed gap. Audit quotations of the PRD were not re-checked against the PRD file. |

## Conclusions

- Current issuance and redemption entitlements are the same live whole-book liquidation quote. That is the APEX-012 price. A one-whole-share execution quote is a different number whenever the sale has price impact. Scaling the whole-book quote by `supply` does not produce it.
- One fungible ERC-20 cannot give unequal fractions of core, upper, and lower. Internal section ledgers behind one balance do not create a second fraction. Full credit for a retained imbalanced deposit into that one token requires a numeraire. The live liquidation quote is a manipulable numeraire. An independent reference is a numeraire only if it is actually independent and fresh. Without one, the honest action is to refund the imbalance.
- Exact entry or exit swaps do not close APEX-012. The audit's profit formula is `D * (V1 - V0 - D) / (V0 + D)` where both mint and redeem use the live quote. Changing the zap percentage does not change that formula.
- getRate must stay an execution quote of one whole share. It must not become the mint price, and external pools must not treat it as an oracle that pays without redeeming.
- This is one member's recommendation. Peers were not read. It is not council consensus and not a security proof.

## Preferred complete design

Call it the slice vault. One ERC-20. Two mint modes. One exit machine. One getRate definition.

The share is a fraction of the booked book: three positions, both idle balances, and collected fees. It is not a promise of target tokens. After a transfer, the recipient owns that fraction of whatever the book is then. There are no per-section internal accounts and no second token.

Mint mode is selected by configuration, not by the caller guessing a price.

- Priced mode, only when a fresh independent reference is configured: imbalanced and target-only deposits are accepted. Retained tokens, including overage, are credited at the reference. This is the only mode that meets full credit for a retained imbalance.
- Unpriced mode, the default when no fresh reference exists: the vault refunds any amount that is not strictly proportional to the current book. It does not swap. It does not retain overage as shares.

Exit is the same in both modes. Burn the shares, remove only that fraction of each position and of both idle balances, sell only that fraction's opposing tokens, and pay the actual target recovered. A rate read does not execute that swap.

getRate is the decimal-normalized preview of exiting exactly one whole share. It is not NAV, not the whole-book quote divided by supply, and not a size-invariant rate.

### 1. Units, state, fungibility, bootstrap, dust, donations, liabilities

Share decimals remain the target token's decimals, as DFPkg initializes them today. `U = 10^shareDecimals` is one whole share. Because those decimals match, one whole share and one whole target token are the same raw unit. Do not switch the share to a universal 18. That would make the current raw `* 1e18 / supply` scale disagree with the buffer hook's 36-scale unless every consumer is rewritten together.

State stays in the existing Wings repo: `local0`, `local1`, three position slots, `busy`, pool key, target side, fee-oracle sleeve percentage. Add two deploy-time values: the reference adapter address (zero means unpriced) and the maximum reference age. Add no second share token and no section ledger.

Ownership fraction after an operation is `balance / totalSupply`. It applies to every slot and both idle balances. Rounding dust from a floor slice stays in the book and is owned by remaining holders, including the next slice. The last holder, `shares == supply`, takes the actual remaining liquidity and idle, so prior dust is not stuck.

Bootstrap, priced or unpriced: the first deposit must be at least one whole target token of credited value, and larger if the owner sets a higher minimum. That minimum is not locked. The first depositor may later exit. Empty-vault `getRate` returns `1e18`. That is a consumer convention, not a promise that a mixed first deposit will exit at par. I do not add a permanent virtual-share offset. An offset large enough to matter would move bootstrap getRate off `1e18` and surprise the rate adapter's unit-deposit inversion. Inflation protection is the minimum size plus the round-trip guard below, which is an explicit overturn of the no-minimum, no-virtual-denominator posture quoted by the audit. I did not re-read that ruling.

Direct token donations are not contributions. At each checkpoint, surplus `balanceOf(vault) - local - pending` is swept into `local` before NAV or the ratio check. It raises the existing book. It is never added to the caller's credit. `PoolManager.donate` is different: it inflates in-range fee growth. Those fee tokens are real inventory and are valued as tokens, either at the reference or inside the proportional book. They are not valued by replaying the donation through the liquidation quote. The PoolManager interface already warns that `feesAccrued` can be inflated this way. Do not treat `feesAccrued` as a deposit.

Liabilities are only the in-flight pull, accounted as `pending0` and `pending1`, excluded from `local` until mint or refund. There is no debt token and no external credit that counts as a depositor's contribution. Fee-on-transfer and rebasing underlyings stay forbidden. A pausing or blacklisting token can make the transfer fail; the operation reverts. Backing at the end of an operation is `balance >= local` on both currencies, with pending cleared.

Fungibility limit: one balance cannot say "this holder owns more of the upper wing than of the core." If that is required, the product is three tokens, and that is the rejected alternative below.

### 2. Share-credit equations

Let `S` be total supply before the mint. Let `R` be target whole tokens per one opposing whole token, scaled by `1e18`. `R` is not a sqrt price and not slot0.

Convert a raw amount to target raw at `R`:

```
toTargetRaw(targetAmount) = targetAmount
toTargetRaw(opposingAmount) = floor(opposingAmount * R * 10^targetDecimals
                                     / (1e18 * 10^opposingDecimals))
```

Use a full-width multiply. Do not truncate through a wad if that loses a raw unit the guard later needs.

Position value is not live principal marked at `R`. Convert `R` to the pool's raw `sqrtPriceX96` (Uniswap's price is raw token1 per raw token0, so the decimal conversion is part of the formula, not optional), then:

```
principal = Inventory.principal(sqrtR, lower, upper, liquidity, roundUp = false)
positionValue = toTargetRaw(principal.amount0) + toTargetRaw(principal.amount1)
```

That is the token mix the position would hold if the pool were at the reference. Live spot can change the current mix without changing this value. Idle balances and uncollected fee balances are already token amounts; value those at `R` directly. Do not run them through `Inventory.principal`.

```
NAV = sum of three positionValues at sqrtR
    + toTargetRaw(fee0) + toTargetRaw(fee1) for each position
    + toTargetRaw(local0) + toTargetRaw(local1)
```

`NAV` excludes `pending`. Fees already in `local` because of a checkpoint are not also added as `fee0`.

Priced credit is only the retained pending balances after the caller's own swap, if any:

```
credit = toTargetRaw(pending0) + toTargetRaw(pending1)
if S == 0:
    shares = floor(credit * U / 10^targetDecimals)
else:
    shares = floor(S * credit / NAV)
require shares > 0 and shares >= minShares
require floor(shares * (NAV + credit) / (S + shares)) + 1 >= credit
```

The last line is the round-trip guard, in target raw units. It allows at most one target raw unit of rounding loss against the same reference. It reverts a donation that would mint one share for a large deposit. It does not detect a wrong `R`. A wrong `R` makes `NAV` and `credit` wrong together, and the guard passes.

Worked illustration, not a test. Book is 100 target and 100 opposing, `R = 1e18`, both tokens 18 decimals, `NAV = 200`, `S = 200`. A target-only deposit of 50 has `credit = 50`, `shares = floor(200 * 50 / 200) = 50`. The depositor owns 50/250 of a book worth 250 at `R`, claim 50. A limiting-token mint would have given them zero shares and donated the 50. That is the rule being replaced.

Unpriced credit uses live removable composition, not a price. After the fee checkpoint:

```
(book0, book1) = idle + removable principal at live spot + collected fees
```

If `S == 0`, there is no prior ratio. The first unpriced deposit must be target-only. Any opposing sent with it is refunded. That seeds target inventory. It does not invent a cross-rate.

If `S > 0` and both sides of the book are positive:

```
retain0 = min(pending0, floor(pending1 * book0 / book1))
retain1 = min(pending1, floor(pending0 * book1 / book0))
```

Then shrink to the pair that still matches, refund `pending - retain`, and mint the worse side:

```
shares = min(floor(S * retain0 / book0), floor(S * retain1 / book1))
```

If the depositor brings only target and the book holds opposing, `retain0 = 0` and the entire pull is refunded. Unpriced mode cannot accept a target-only deposit once the book is two-sided. That is the incompatibility with the current target-only UX. A router that wants that UX on an unpriced pair must swap outside the vault and deposit both tokens on ratio. The vault must not do that swap itself and then call the result proportional: the vault would have moved the spot, and the ratio would be measured after its own trade.

One-sided book (`book1 == 0`): only token0 is proportional. A token0 deposit mints `floor(S * pending0 / book0)` and refunds token1. No price is required.

Ownership is established at mint, after pending is added to `local` and before placement. Custody starts at the pull. Between pull and mint the tokens are an operation liability, not shareholder property. A revert rolls the pull back. There is no partial mint.

### 3. Deposit sequence

1. `begin`: initialized, not busy, PoolManager not unlocked, deadline not passed, vault not disabled, recipient not zero, amount not zero. Set `busy`.
2. Pull target and, if the caller sent it, opposing. Require the balance delta to equal the requested amount. Account the pull as pending, not as `local`.
3. Checkpoint. Poke each live position with `liquidityDelta = 0` so the whole fee delta is booked to `local`. Sweep raw surplus into `local`. Do this before any entrant swap. Pre-entry fees belong to the existing book.
4. If the caller specified a swap of their own pending tokens, execute only that swap, with the caller's sqrt price limit. Reject a limit at the protocol minimum or maximum. The swap input is caller-specified. The vault does not search, and it does not hard-code 49% or 51%. Residual of that swap stays in pending. If the swap cannot fill inside the limit, revert the deposit. Do not partial-fill a mint.
5. Fees the vault's existing liquidity earned during that swap stay in position fee growth. Include that growth in priced `NAV`. Do not add it to `credit`. Do not poke it into pending.
6. Priced mode: read `R`. If the adapter is missing, the call fails, the answer is zero, or `block.timestamp - updatedAt > maxAge`, revert the priced path. Do not fall back to slot0. If the caller passed `maxR` and `R` exceeds it, revert. Then apply the priced equation.
7. Unpriced mode: skip the swap step even if one was requested. Apply the proportional equation and refund the excess to the caller before mint.
8. Mint. Check `minShares`. Run the round-trip guard. Book retained pending into `local`. This is the ownership point.
9. Place idle above the target sleeve floor: core first, then the token0 upper wing, then the token1 lower wing, using the existing geometry derived from the actual sqrt price. Placement does not change `shares`. An unavailable wing leaves that token idle. Idle remains owned.
10. `end`: pending is zero, both balances cover `local`, clear `busy`.

Failure is atomic. No minted shares survive a revert. Deadline is checked at `begin`; the timestamp does not move inside the transaction.

The entrant's swap fees, price impact, and any tokens the pool keeps are already outside `credit`, because credit is the post-swap pending balance. That charges entry execution to the entrant. Existing inventory is not an input to that swap.

### 4. Fee attribution on entry

Pre-checkpoint fees are in `NAV` or in the proportional book, not in `credit`. Fees earned by existing positions during the entrant's swap are in post-swap `NAV`, not in `credit`. The new holder pays for a fair fraction of them by minting against that NAV, and is not also paid in shares for creating them. That is one count, not two.

I do not recommend paying those fees to the entrant. Their swap already moved the price in their favor or against them; the fee paid to incumbent liquidity is the incumbent's yield. Giving it back as shares would cancel the reserve's reason to exist.

Unpriced mode has no in-vault entrant swap, so this clause is only the pre-checkpoint. A router swap outside the vault can still pay fees to the vault's positions before the deposit. Those fees are incumbent property if they have already accrued when the ratio is measured. The router cannot include them in the deposit amounts. That is acceptable, and it is another reason the vault should not wrap an unpriced zap around the ratio check.

### 5. Withdrawal sequence

1. `begin` with the same unlocked, busy, and deadline checks. Recipient is not zero and not the vault. Holder balance covers the shares. A pushed pre-transfer still has to authenticate the caller, as today.
2. Checkpoint fees into `local` and sweep surplus, before computing the slice. The exiter's fraction of fees is the idle slice. It is not a second payment.
3. Let `s` be shares to burn and `S` the supply before the burn.

```
for each slot:
    liqOut = (s == S) ? liquidity : floor(liquidity * s / S)
idle0Out = (s == S) ? local0 : floor(local0 * s / S)
idle1Out = (s == S) ? local1 : floor(local1 * s / S)
```

4. Decrease each position by `liqOut` only. Do not close a position unless `liqOut` is its full liquidity. The PoolManager delta includes all uncollected fees, not a fraction. After the checkpoint those fees should be near zero. Any nonzero `feesAccrued` on this decrease is booked back to shared `local`, not to the exiter. The IPoolManager donate warning is why. Principal from the decrease goes to a per-operation tray, together with the idle slice. The tray is not `local`.
5. Target tokens in the tray are payable. Opposing tokens in the tray are the only tokens sold. Stayer opposing, whether idle or still in a position, is not an input.
6. Target mode, the default: exact-in swap of the tray's opposing amount, with a caller sqrt price limit that is not the protocol extreme. If it cannot sell the full tray amount inside that limit, or the resulting target is below `minTargetOut`, revert. Do not sell more opposing to finish the shortfall. Do not donate the unsold tray back to the vault. Unsold tray on a revert never leaves the book, because the transaction reverts before burn is committed. Implementation order: compute and execute while `busy`, burn and reduce `local` and liquidity only after the sale succeeds, then transfer.
7. In-kind mode, caller opt-in: skip the swap. Pay both tray tokens to the recipient. This mode exists so a dust-tick or empty external book cannot freeze principal. It is not a silent fallback. A caller who asked for target must not receive an unexpected second token.
8. Payout in target mode is tray target plus actual swap proceeds. No top-up from stayer idle. No payment of the pre-trade liquidation entitlement.
9. Last holder (`s == S`) removes every position and takes both idles. There is no dead balance left behind, because the inflation guard is not a locked share. If external liquidity cannot buy the last opposing inventory, target mode reverts and in-kind mode pays both tokens.
10. Clear `busy` only after the transfer. A token callback sees `busy` and cannot re-enter mint, redeem, or getRate.

Delete `HolderValueLoss` against a second live quote. That check compares two quotes of the same manipulated state, and it treats a whole-book dump as the baseline. A correct slice exit does not need it. Stayer harm from this exit is pool price impact on positions that remain, which is ordinary LP exposure to a sale of the exiter's own size, plus fees those positions earn during the sale. Those fees stay with stayers.

In-kind is necessary as an opt-in. It is not necessary as the default. The historical no-basket-exit posture, as quoted by the APEX-026 write-up, is overturned only for the opt-in mode.

### 6. Quotes, getRate, and preview consistency

Preview and execution call one slice function. The view loads a memory book. The state path loads the same struct from storage and then performs the planned modify and the one swap. If those diverge, that is an implementation bug. They still will not match if the pool moves between the eth_call and the transaction. `minShares` and `minTargetOut` cover that. Do not "correct" a preview toward the whole-book quote to make them look stable.

```
previewRedeem(s) = target raw from the exit machine for exactly s shares
                   reverting on the same unlock, fill, and step-budget conditions
getRate():
    if S == 0: return 1e18
    if S < U: revert
    proceeds = previewRedeem(U)
    return floor(proceeds * 1e18 / U)
```

`U = 10^shareDecimals`. With share decimals equal to target decimals, `1e18` means one whole target token per one whole share. A one-share sale that returns exactly `U` target raw publishes `1e18`. A sale with impact publishes less. A caller cannot scale `getRate` by an arbitrary size and call the result the execution quote. `previewRedeem(s)` is that quote. It is not `s / S * previewRedeem(S)` and not `s / S * liquidationValue`.

`liquidationValue()` may remain a diagnostic whole-book quote. It is not the mint price and not getRate. `exchangeRate()` on the SY surface must return `getRate()`, not the whole-book quote scaled by supply. Two published rates will be integrated as if they were the same.

Projected `quoteRate(exchange, asset, state)` runs `previewRedeem(U)` against the supplied book and pool overlay. If the exchange or asset does not match, reverting is better than returning the live rate; the current fallback to live `getRate` hides a bad call. If the manager is unlocked or the vault is busy, revert. A failed one-share simulation reverts. It does not become a smaller trade and it does not become zero. Zero is a published price. The Balancer adapter's current "return 0 on failure" is unsafe if any consumer treats zero as a real rate or caches the last nonzero value. That adapter is a different contract; this vault should not copy that failure mode.

Exact-in preview is the mint equation for the specified amounts and mode. It does not walk ticks unless the caller also asked for a projected entrant swap, in which case the view may simulate that one swap to compute post-swap pending. The stateful path executes that same specified swap once.

Exact-out is a view search, not a stateful solver. At most 16 preview iterations to find the smallest share amount whose `previewRedeem` covers the requested target, rounding up. If the search does not bracket, revert. `exchangeOut` redeems that share amount and still requires `payout >= amountOut` and `shares <= maximum`. Integrators should prefer exact-in. Exact-out exists because the current out route has it, and its gas is the quote walks, not a liquidity search.

Supply below one whole share cannot publish getRate. After the one-whole-token minimum, a normal first deposit is large enough. A later full exit returns to the empty convention.

### 7. Compounding and maintenance

With one share class, compounding does not transfer ownership from core holders to wing holders. It changes the mix every share owns.

`compound()` is permissionless and swap-free. It checkpoints fees, sweeps surplus, and places idle above the sleeve floor using the same core-then-wings rule. Target fees and leftover target go to the target wing (upper if target is token0, lower if target is token1) after the sleeve reserve. Opposing fees go to the opposing wing. They are not swapped into target. Core fees of both tokens are placed by the same rule. A caller can choose a bad moment, so the new wing boundaries follow a manipulated spot. That misses fees later. It does not sell inventory into the pool. I accept that. I do not add a "corrective" swap to the same function.

Keep the existing harvest-close: a wing that has acquired the other token is removed to idle and replaced at the new boundaries. Removal is `modifyLiquidity`, not a pool swap. Rounding is borne by the book, because this is maintenance of incumbent inventory, not an entrant's trade.

Delete the permissionless swap rebalance. APEX-025 is that function. The sleeve refills when exits and harvest-closes return target, and when target deposits leave a sleeve. It does not refill by selling opposing at spot. If the owner later wants a keeper swap, it is a different function: role-gated, selling at most the sleeve deficit, price-limited by the reference rather than by the post-trade slot0, with loss measured as `inputTargetRaw - toTargetRaw(output)` at `R`. Without a fresh `R`, that function does not exist. I recommend not building it in the first cut.

Nobody can force a harmful swap through `compound`. The deleted rebalance was the force path.

### 8. Gas

I measured no gas. The distinction that matters is which path walks ticks.

Mint NAV is three `Inventory.principal` evaluations at a stored sqrt price, plus fee-growth reads and a handful of `mulDiv`s. The proportional check is cross-multiplies. Neither walks the bitmap. That removes the quote from the deposit path, which is what makes APEX-026 able to freeze deposits today.

An entrant swap, an exit swap, and a one-share preview are real tick walks. Their cost follows initialized ticks crossed by that sale, not a vault solver. Dust ticks still count as steps for any quote that crosses them. A one-share sale crosses fewer ticks than a whole-book dump only when in-range liquidity absorbs it first. If the vault is the only LP and dust sits on the path, `getRate` can still revert. Mint and in-kind exit do not depend on that walk.

The current rebalance planner binary-searches up to 12 quotes. Deleting it removes that search from maintenance. Exact-out's 16 view iterations are the only remaining on-chain search, and they are not on the exact-in deposit path.

The original gas objection was an on-chain iterative zap that sizes both tokens to the book. This design puts that sizing off-chain. On-chain work is either a ratio check or a reference multiplication. The 49/51 figure is not computed on-chain at all.

### 9. Price source

No price is used for proportional mint, for the slice exit, for getRate, or for compounding.

A price is used only to turn a retained imbalance into fungible shares. The adapter is set at deploy. It must not be this vault, this pool's slot0, or the Balancer rate facet pointed at this vault. The pool is hookless, so it cannot host an observation hook, and the vendored V4 tree I searched has no PoolManager `observe`. Recommending "the pool TWAP" would invent a source. I do not recommend one.

Value ranges at the reference sqrt price. Valuing live-spot principal at `R` is still spot-dependent and is not allowed. Idle and fees are token amounts; valuing those at `R` is correct.

If the adapter is absent or stale, the vault still accepts proportional deposits. Priced deposits revert `ReferenceUnavailable`. There is no owner hot-update of `R` after deploy in this recommendation. An owner-set spot is a rug of every depositor. If a pair has no feed the owner trusts, deploy it unpriced.

A wrong but fresh `R` is not solved by this accounting. Illustration, not a test. Book is 100 target and 0 opposing, `S = 100`, true price of opposing is 1, stale `R` says 10. Attacker donates 10 opposing. `NAV` becomes 200. Victim deposits 100 target and receives 50 shares. Attacker redeems 100 of 150 shares and receives about 133 target plus a slice of the donation. The guard passes because both sides used the same bad `R`. The depositor's `maxR` stops a victim who sets it. It does not stop a victim who does not, and it does not stop the attacker from minting cheap shares when `R` is too low. The residual risk of priced mode is oracle risk. That is why unpriced mode exists and why slot0 is not a fallback.

### 10. Attacker economics

The audit's demonstrated profits are not re-measured here. They apply to the current live-quote machine. Under this design the same steps do not have the same payoff, for structural reasons. That is an argument, not a passing test.

Deposit after a spot move, priced mode. Shares use `NAV` at `R` and `credit` at `R`. Moving slot0 changes live composition and the live quote. It does not change amounts-at-`R`. The attacker does not mint more shares by depressing the quote. Their later exit sells only their slice, at whatever spot they leave behind, and `minTargetOut` is their problem. They can still lose or gain on that sale the way any trader does. They cannot redeem `shares * V_live / S`.

Settled JIT. Extra external depth does not enter `NAV`. It can improve the execution price of the attacker's own slice sale. They paid to add that depth and they are selling only their fraction. The audit profit `D * (V1 - V0 - D) / (V0 + D)` required both mint and redeem to use `V_live`. This machine uses neither. I do not claim the round-trip profit is zero. I claim that demonstrated formula no longer describes the payout.

Unsettled JIT inside `unlock`. `begin` reverts if the manager is unlocked, so the in-unlock deposit-then-redeem path cannot start. The vault's own `execute` already reverts if the manager is unlocked. A hookless pool has no hook callback into the vault during someone else's swap.

Unpriced proportional deposit after a spot move. The attacker can match the manipulated composition and become a shareholder of that book. When the price reverts they share the inventory change with every other holder. They do not receive a claim on a larger fraction than they funded. This is not APEX-012. It is ordinary entry into a pool at a bad time, and the caller's slippage on any outside swap is theirs.

Donation. Raw surplus is swept into the existing book before credit, so the attacker is not minted shares for it. Fee-growth donation increases `NAV` at `R` by the donated tokens' reference value. The round-trip guard blocks the "mint 1 share" rounding the audit demonstrated, provided the implementation uses target raw and not a 1e18 wad tolerance. A 1 wad tolerance on a 6-decimal token would be an entire token. Do not do that.

Exit sandwich. The victim's slice can still be sandwiched if their price limit is loose. Stayer opposing is not sold to fill that victim's quote. That is the APEX-024 change. The victim's loss is their own slippage. Stayers still see price impact on remaining positions. That impact is the sale of the exiter's opposing slice, which is the size they actually owned, not the whole book.

I did not construct a new numerical exploit. The audit figures stay the audit's.

### 11. getRate consumers

What getRate honestly is: on a pool that does not move, the target raw a redeemer of exactly one whole share would receive, scaled to `1e18` per whole target token. It reverts rather than publish a number if that sale cannot be quoted, if the manager is unlocked, if the vault is busy, or if supply is below one whole share.

What it is not: a safe pricing oracle for a pool that pays the counterparty without redeeming. The single CP buffer hook values `balanceOf(shares) * getRate` and does not redeem. The Balancer facet prices the full supply through `previewExchangeIn` and also does not redeem. Neither path settles the Wings book. I did not find a production wiring from this vault to those consumers. The interface risk is still the one that matters, because the product goal is to use the share in external liquidity.

An accurate one-share quote is optimistically high for a large redemption. Convex impact makes the average proceeds per share of a full exit worse than the one-share quote. Multiplying `totalSupply` by `getRate` overstates the target obtainable by redeeming the supply. The Balancer facet currently does the opposite, and its full-supply preview is the quote that APEX-026 can freeze. Pointing that facet at the new `getRate` would change both the quote size and the manipulation surface. Do not do that and call it the same rate.

Raw target and shares are not economically identical. They match, at the published scale, only for a one-whole-share redemption on an unchanged pool, after fees and impact. A 50% redemption is a different price. An unredeemed transfer is not a redemption at all.

Honest integration:

- Settle by redeeming the actual size in the same transaction, before paying the external counterparty. The payout is actual proceeds, capped by the caller's minimum. That is the safe use of this share in a buffer.
- A view quote is valid only for the quoted size and only if the pool does not change before settlement.
- A pool that must mark shares without redeeming needs an independent bound, and even `min(getRate, NAVperShare)` is not enough for a large unredeemed payment. `NAVperShare` can be stale. `getRate` can be moved with spot and depth. The bound is a circuit breaker, not a pricing source.
- If `getRate` reverts because of dust ticks or an empty external book, a consumer that requires a live rate will freeze. That is a reason not to register this vault as a rate-provider subject until external depth exists, and a reason to keep in-kind exit available to the holder. It is not a reason to publish a fake rate.

### 12. Audit implications, reentrancy, quote liveness

APEX-012. The mint price is no longer the live quote, and the redeem payout is no longer `shares * V_live / S`. Unlocked entry reverts on the state path and on views. The audit's own fix note says an unlock guard alone is partial, because settled depth and spot moves remain. This design addresses that remainder only if `R` is independent. It does not close the finding. No test was run.

APEX-024. The exit sells the tray, not `local` opposing, and it does not use a protocol-extreme limit. `HolderValueLoss` is removed rather than retargeted. Not closed without a test that a large exit leaves stayer opposing in place.

APEX-025. The permissionless swap is removed. A future keeper swap is out of the first cut and, if built, must measure loss at `R`. Not closed by deletion on paper.

APEX-026. Deposits no longer call the 512-step quote, so the demonstrated deposit freeze does not have a quote to trip. Target redeem and `getRate` can still revert if the slice sale's quote exceeds its step budget. In-kind redeem does not. A reverting `getRate` can still freeze an external pool. I am not adopting the audit's suggested spacing formula as a measured constant. I do recommend that deploy validation refuse a spacing the owner has not explicitly accepted, and that work exhaustion keep reverting a target quote rather than returning a market-limited success. That preserves the rule the audit quotes. The new escape is opt-in in-kind, not a partial target quote.

APEX-040. Minimum first deposit plus the one-raw-unit round-trip guard is the intended mitigation. Excluding fees from the quote is not sufficient, as the audit says, because a checkpoint books them before the mint. Including them in `NAV` at `R` is intentional. Not closed without the regression the audit names.

Reentrancy. `busy` remains. Add the unlocked check to `begin`, `getRate`, `preview`, `quoteRate`, and `liquidationValue`. The vault cannot call `execute` while the manager is unlocked. A token callback during the final transfer sees `busy`. Nested unlock from the vault's callback is already rejected. This does not fix Balancer buffer-hook reentrancy in other contracts. If a Wings share is later the asset inside one of those hooks, that hook's bug is still that hook's bug.

Quote liveness. Target quotes revert when the step budget is exhausted. They do not report a partial fill as the redemption value. Mint and in-kind exit stay available. That is the liveness split.

No static proposal here closes any finding. The validation plan is the bar, and it was not executed.

### 13. Validation plan

Do not treat this section as a run. Production-first: real PoolManager, real package deploy path, no mock of the vault.

Invariants:

- Priced and unpriced round trip in one transaction, with and without added depth and a spot push: attacker target profit is not positive beyond the fees they paid. This replaces the SEC-08 check the audit says was not waived.
- Another holder's target exit does not decrease stayer opposing principal plus stayer idle opposing, except a one-unit rounding if a position decrease is indivisible. The sale input equals the exiter's tray.
- `floor(shares * (NAV + credit) / (S + shares)) + 1 >= credit` after every priced mint, and a deposit that would mint one share for a large credit reverts.
- Pre-swap vault fees are not in `pending`. Post-swap fee growth is not in `credit`.
- When `S >= U` and the one-share sale is quotable, `getRate == floor(previewRedeem(U) * 1e18 / U)`.
- On a pool with no concurrent mutation, `previewRedeem(s)` equals the target paid by `redeem(s)` for one share, for half the supply, and for the full supply.
- On a thin external book, `getRate` is not equal to `floor(liquidationValue * 1e18 / S)`. This locks the semantic change.
- Unpriced mode refunds a target-only deposit against a two-sided book and mints zero.
- Priced mode mints nonzero shares for a target-only deposit when `R` is fresh, and the opposing holder is diluted only by `credit / (NAV + credit)`.
- `compound()` leaves slot0 unchanged.
- The old rebalance selector is absent or reverts for an unprivileged caller.
- While the manager is unlocked, deposit, redeem, getRate, preview, and liquidationValue revert.
- The APEX-026 dust-tick shape: deposit still succeeds; target redeem reverts without burning; in-kind redeem pays both tokens.
- The APEX-040 donation shape: the next depositor's round-trip at the same `R` loses at most one target raw unit; the attacker's profit at that `R` is not positive. A separate case with an intentionally wrong `R` documents the oracle residual rather than pretending the guard covers it.
- Last-holder in-kind exit empties both locals and all three positions.
- Integration negative: a pool that pays `balance * getRate` without redeeming can be moved by a spot or depth change. That is a consumer failure, not a vault invariant. The vault invariant is that the same change does not change priced shares minted.

### 14. Requirement changes, limits, and the implementation surface

Changes from the current preferences, named as changes:

- Full credit for retained imbalance is conditional on a fresh independent reference. Without one, overage is refunded. A target-only deposit into a two-sided unpriced book is a full refund.
- The vault does not implement a 49/51 or any other fixed zap fraction. A caller may pass a swap amount of their own pending tokens in priced mode only. The fraction is a router choice. It affects composition, not the fairness of the share count. Share count is `credit` at `R`.
- getRate stays a one-whole-share target exit preview. Its implementation changes from `floor(wholeBookQuote * 1e18 / supply)` to `floor(previewRedeem(U) * 1e18 / U)`. Those are different numbers when impact exists. I am not conceding the preference. I am refusing to implement it as a scaled whole-book quote.
- Issuance NAV is not the exit quote and not zap-out value. The user already separated those. This design keeps that split and defines NAV as amounts-at-reference, not live amounts marked at the reference.
- In-kind exit is added as an opt-in. Target mode does not fall back.
- Permissionless swap rebalance is removed.
- The live liquidation quote is no longer the share price. That overturns current `Accounting.issue` inputs and the liquidation-proceeds share price described in the audit's PRD citations.
- A minimum first deposit and a one-raw-unit round-trip guard are required. That overturns the no-minimum, no-virtual-denominator posture the audit quotes. I did not re-read the ruling. I am not adding a permanent virtual offset.
- External liquidity may hold the share. It may not mark the share with raw getRate unless it redeems the size it is pricing. "A rate so shares can be used in liquidity" is satisfied by actual-size settlement, not by an oracle read.
- `HolderValueLoss` against a same-state quote is deleted.
- Deposits do not depend on the 512-step quote.

Historical expectations I am explicitly not restoring: V4 FullSpread, a same-pool TWAP, an on-chain iterative solver, and a basket exit as the silent default.

Owner decisions left open:

- Which pairs get a reference adapter, and the max age.
- The minimum first deposit, if larger than one whole target token.
- The sleeve percentage. It remains a placement reserve, not a pricing input.
- Whether unpriced instances are deployed at all.
- Which tick spacings are accepted. I would refuse spacing 1 unless the owner accepts getRate liveness risk.
- Whether any keeper swap is ever added. My recommendation is no.

Simplest surface: keep the diamond, three slots, geometry, inventory principal, execution delegate, and the busy flag. Rewrite Money deposit, redeem, and funding. Point `Accounting.issue` at `(S, NAV, credit)`. Add a small reference conversion library. Share the slice function between preview and execution. Delete the rebalance swap planner from the permissionless surface. Do not add a token, a solver, or an oracle inside the pool.

Practical limitation: a pair with no trusted feed does not get the target-only UX inside the vault. A router can still swap and deposit on ratio. That router is outside this design and must not be described as the vault crediting imbalance.

Deployment: the audit says this family is not deployed. I did not verify that on a chain. This is a new accounting machine. I would ship it as new instances, not as an assumption that an existing diamond can be cut over with old shares still priced the old way.

## Alternatives and strongest objection

Fungible shares, reference NAV mint, actual-proceeds exit, execution-quoted getRate. This is the preferred priced mode. It is the only option I compared that both credits retained imbalance and stops using the live quote as the share price.

Oracle-free proportional ownership with an off-chain size and an on-chain ratio check. This is the preferred unpriced mode, not a rejected alternative. It is cheaper and it needs no feed. It fails full credit the moment the book holds both tokens. I will not paper over that with an in-vault zap.

Separate section claims, whether three ERC-20s, an ERC-1155, or an NFT position. This gives full credit with no price: a target deposit mints the target wing claim in proportion to liquidity added to that wing, and never dilutes the core. Cross-section compounding then becomes a real transfer. Core fees compounded into a wing must mint wing claims to core holders, or the compounded liquidity must remain inside the core claim. A wrapper that turns the three claims into one LP token either holds a fixed basket, which breaks as soon as fees compound unevenly, or values the variable mix, which is the numeraire problem again. I reject this as the primary design only because the share is supposed to be one external-pool asset. If that goal is dropped, separate claims are the better unpriced design, and I would switch.

`sqrt(aggregate token0 * aggregate token1)` and any other single invariant on summed reserves. Rejected. The book is a full-range core, two single-sided wings, and idle. Those are not one constant-product pool. Summed reserves move when spot moves, even if no one deposits. The live liquidation quote is the invariant the audit already broke. I will not replace it with a geometric mean and call the result resistant.

The 49/51 on-chain zap, as a fairness mechanism. Rejected. It spends gas on a search or on a fixed guess, it moves the spot with depositor funds, and it does not determine a manipulation-resistant share count. As a caller-specified swap in priced mode, the same action is harmless to fairness because the share count uses `R`. The percentage should not become a vault constant.

Strongest objection. Reference NAV will credit inventory the pool cannot sell, and a wrong `R` is theft that the round-trip guard cannot see. A depositor can be minted shares against opposing tokens at `R` while external depth is zero. Their one-share getRate may revert or print a poor execution price, and a large exit is worse. Remaining holders share the unsellable inventory. If `R` is stale and high, the donation illustration above takes the victim's target. If `R` is low, the attacker mints cheap shares and redeems a slice of real target. Proportional-only mode has neither failure. The objection is decisive for any pair whose feed is missing, stale, thin, or administratively controlled. It is not decisive for a pair with a feed the product already trusts for other money, because the alternative that credits imbalance there is the live quote, and that alternative has a demonstrated exploit. The split is the response to the objection, not a claim that the objection is weak.

## Limits

- Runtime or extraction proof: none. No tests were run. Audit profit figures are the audit document's figures. No gas numbers were measured. Live files can change; this is not a repository snapshot.
- Not examined: LiquidationQuote `_sell` body; historical PRDs and the prior council report; dual-hook valuation beyond the getRate staticcall; production wiring from this vault to a buffer hook or Balancer pool; on-chain deployment status; any oracle adapter, because none is configured in this package.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement. `apply_patch` was not in the exposed tool set; the file was written with the session file-write tool.
- Public query: not used.
- No security proof. No claim that any APEX finding is closed. No council consensus.
