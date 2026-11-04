# Member response

## Identity
- Run ID: apex-012-prd-clarity-20261024
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-prd-clarity-20261024/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Question: Is `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` clear enough that two implementers would build the same V3 and V4 Upper Lower Wings accounting?

Required target: that PRD. Context only, and not a substitute specification: the `APEX-2026-012: apportioned reserve` section of `docs/security/audit/second_review/REMEDIATION_TRACKER.md`, and the current V4 Wings sources under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`. V3 FullSpread was not treated as the V3 Wings family.

Verdict: no. The bans are specific enough to share. The positive accounting is not. Two implementers can comply with the written sentences and still ship different share counts, different `getRate` values, different entry swaps, and different V3 vaults.

## Evidence

PRD, read in full (105 lines). Citations below use those lines.

Context, tracker. Table row at line 21, and the section starting at line 353, heading `APEX-2026-012: apportioned reserve`, through the bullet that implementation is not authorized, before `Migration design checkpoint`. That section restates the ruling. It does not add a mint equation, a counter ledger, or a swap-size rule. Its phrase "swaps into the current mix" does not define the mix across three slots or whether the mix is taken before or after the swap moves the price.

Context, current V4, read to see which unnamed paths an implementer can leave in place:

- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` lines 27-36. `getRate` is `Quote.quote(...).value * 1e18 / supply`. `quoteRate` returns that same quote when the exchange or asset does not match, and `Projection.value` of the supplied state when they do. `Projection.value` is a liquidation quote of the projected book.
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` line 18. `issue` mints `credit` when supply is zero, otherwise `supply * credit / value`, where `value` is the quote.
- `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`. Deposit (line 112) and redeem (line 141) price shares and target from `Quote.quote`. `depositExactShares` (line 115) and `redeemExactAssets` (line 144) override that result with a caller-supplied exact amount. `requiredInput` (line 244) and `preview` (line 266) use the post-harvest quote. Redeem then `_fund`s the quoted target payout. `_swapDeficit` (line 219) swaps the entire opposing local balance at `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`. A second quote can revert the redeem through `HolderValueLoss`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol` line 118. `harvest` does not swap. It closes a wing that `Inventory.harvestEligible` marks converted, then placement adds liquidity from local balances into ranges derived from the current price. It does not add in proportion to liquidity already in the three slots.
- `UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol` line 61. Upper is eligible when it holds token1. Lower is eligible when it holds token0. Core is never eligible. Principal amounts are a function of sqrt price.
- `UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol`. Core is the full usable range. Wings are the nearest strictly separated ranges. Placement follows that geometry, not the existing slot liquidity.
- `UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol`. Booked state is `local0`, `local1`, and three positions. There is no settled-target field. Donations sit outside the booked locals because backing checks `balanceOf >= booked`, not equality.
- `UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceTarget.sol` lines 22 and 33. `rebalance` quotes the book, then `_reshape` harvests, closes wings, and executes `Planner.bestSwap`. That swap can sell whichever token the excess wing holds.
- `UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget.sol` line 30. `exchangeRate` repeats the liquidation-quote formula. It does not call `getRate`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol`. `exchangeOut` uses `requiredInput`, then `depositExactShares` or `redeemExactAssets`.

V3. A depth-2 listing of `contracts/vaults/standard/exchange/protocols/uniswap/v3` showed no `upperLowerWings` tree. V3 FullSpread sources were not opened and are not evidence for Wings accounting.

No forge, install, deploy, or runtime execution. Static reading is not proof that a future implementation matches either reading below.

## Assumptions

- "The same accounting" means the same share mint, the same redemption payout, the same settled-target updates, and the same harvest credit. It does not mean identical V3 and V4 pool calls.
- A requirements question is included only when the two answers change a contract, a required test, or vault token, share, or rate behavior.
- Where the PRD explicitly allows both outcomes, that is not a question. `liquidationValue, if it remains` is the example. A labeled preview that does not mint or burn is also explicitly allowed.
- Current V4 code is context for divergence. It is not a default that fills a silent PRD rule. An implementer who keeps an unnamed path, and one who replaces it, can both claim the PRD told them to do that.
- This review does not choose a ledger, a mint base, or a swap-size algorithm. Clarifications say which rule must be written. They do not supply the economic choice.
- V3 FullSpread is a different family. Nothing in it was used to interpret Wings.

## Coverage

Read the whole PRD, the tracker section named above, and the V4 money, rate, harvest, geometry, rebalance, exact-route, and SY surfaces that the PRD's bans would touch.

These points are clear. Two implementers following them would not diverge:

- Deposit, redeem, and `getRate` are not priced from `LiquidationQuote.quote` or from any view that sells the book through current depth (lines 6, 18, 68, 70, 93).
- Redeem pays the slice, not a precomputed liquidation of the whole book (lines 51-55, 87).
- The exit sale is not sized as the whole opposing balance (lines 60, 77, 92). Current `_swapDeficit` is that behavior.
- The remaining position may fill an exit sale. A test must not require the remaining holder's target balance to stay constant (lines 21, 58, 104).
- `getRate` is `settledTarget * 1e18 / supply`, and `1e18` when supply is zero. The read does not use `slot0`. An unlocked pool manager does not turn the rate into a live quote (lines 33-37, 68, 89).
- A donation is not inventory. It must not move the settled rate or mint shares (lines 29, 76, 90).
- Build a new V3 Upper Lower Wings family. Do not convert or delete V3 FullSpread. Do not run the V3 half of the tests against FullSpread (lines 8, 23, 82, 99).
- Do not upgrade, enable, or repair a deployed vault (lines 9, 78).
- This document does not authorize implementation, and it does not by itself close 024, 025, 026, or 040 (lines 3, 25, 72-77, 98).
- No new share class, receipt id, second rate provider, or oracle. The counter is not a price of the other token (lines 102-103).
- One family passing does not close the other (lines 6, 17, 82).

What is not unique is the arithmetic those sentences depend on. The defects below are the gaps and the contradictions. The questions are only the forks that change the build.

## Conclusions

No. A V4 implementer who only deletes the quote from `getRate` has not been given one replacement ledger. A V4 implementer who also rewrites deposit and redeem has not been given one mint quantity, one entry-swap size, or one rule for the harvest and rebalance functions the PRD both constrains and refuses to change. A V3 implementer has no Wings source to preserve and no geometry, fee, or facet list to copy. The test section can be satisfied by more than one of those builds, because several tests restate a formula without pinning the quantity inside it.

The tracker context does not close any of that. It records the same ruling in shorter words.

### Requirements questions

1. **What are the settled-target credits and debits?** After a two-sided deposit of 100 target that spends 40 target in the entry swap, one reading sets the counter to 100 (gross deposit; the entry spend is not in the event list) and another sets it to 60 (deposit net of target spent, or target still held). On an exit whose burn returns 20 target and whose swap delivers 15, of which 6 is filled by the remaining vault position, payout is 35. One reading debits 35. Another credits the 15 received and debits the 35 paid, a net debit of 20. A third writes the counter from target still in liquidity at the end of the call. Those are different `getRate` values. A later outsider swap separates them again if one reading re-reads composition at the next checkpoint and another never does. Full exit to zero supply is also open: the next `getRate` is `1e18` either way, but the next deposit inherits a stale counter unless the counter is zeroed. Smallest clarification: a stored-counter equation for deposit, entry-swap spend, exit-swap receipt, redeemer payout, self-fill, harvest fee, and supply going to zero. State that the end-of-call write applies that equation and does not copy token amounts out of the position.

2. **What quantity is the share mint, across three slots?** Line 43 mints from "the liquidity actually added against the position that existed before the add." Core, upper, and lower are three liquidities. After rounding, the three ratios differ. Minting on the core ratio, the sum, or the minimum ratio produces different share counts. A slot with zero liquidity has no ratio. Line 45's "pro-rata" for a single-sided target deposit does not say pro-rata of which total. Smallest clarification: one mint equation, the zero-slot rule, and the rounding direction.

3. **What happens on the first deposit, when no range exists?** Line 24 says a deposit adds in proportion to existing positions and does not open a new range. Rebalance is out of scope and, for V4, unchanged. Supply zero has no "position that existed before the add," so line 43 does not cover it. Line 76 leaves bootstrap dead-share rounding open. One implementer mints shares equal to target deposited and opens three ranges. Another reverts until some other function opens ranges, and mints a dead-share offset. Different contracts. Smallest clarification: name the function that opens the initial ranges, and the share count and settled-target value for the zero-supply deposit. Say whether the open 040 item allows that first mint to differ.

4. **How much of a two-sided deposit is swapped, and may that size be computed from the current tick?** "Part of that deposit" (line 43) and the tracker's "current mix" do not choose a pre-swap ratio, a post-swap ratio, or a solved amount after the swap moves the price. Line 18 bans `slot0` and a simulated swap for pricing deposit on V3 only. A V3 implementer can treat a tick read used to size the swap as banned. A V4 implementer can treat `getSlot0` as allowed because it is not a sale view and the sentence names V3. The swap size changes liquidity added, which changes shares under line 43. Smallest clarification: the swap-size rule, and whether a tick read used only to size the real swap is inside the pricing ban on both families.

5. **Which entry rule yields when extra pool depth increases liquidity added?** Line 43 mints from liquidity actually added. A real swap's output depends on pool depth. Extra liquidity during the call improves the swap, increases liquidity added, and increases shares. Line 47 says that share count must not increase. Test 3 (line 88) says the same deposit mints the same shares with and without liquidity added and removed around the call. Both cannot hold for a two-sided deposit. They can hold for a single-sided target deposit, because no swap runs and external liquidity does not change liquidity-per-target. One implementer follows line 43 and fails line 47. Another mints from a depth-invariant quantity and fails line 43. Smallest clarification: state which sentence governs a two-sided deposit, and align test 3 with that sentence. "Around the call" and "for the duration of the call" also need to mean the same window.

6. **May the vault's own liquidity fill the entry swap?** Line 21 allows that fill on exit only. Line 13 requires the entry swap in the same pool. In the current V4 family the vault's liquidity is in that pool, so a swap that crosses it is filled by the vault. Test 6 (line 91) says the new holder's claim on other token is only the other token bought by the entry swap, not a slice of other already held. If the bought other came out of the vault's own position, that test fails under a pro-rata claim. Withdrawing liquidity before the swap satisfies the test and changes the position the mint is measured against. Smallest clarification: state whether entry self-fill is intended, as line 21 does for exit, and define the test 6 claim if it is.

7. **When is "the position" two-sided, and what does a deposit do if it is single-sided in the other token?** Line 43 swaps when the position is already two-sided. Line 45 skips the swap only when it is single-sided in target. A wings vault holds three slots. With the current V4 geometry, a funded core is mixed, the upper wing is token0-only, and the lower wing is token1-only. One implementer keys off the aggregate and almost always swaps. Another keys off one slot and often does not. Neither sentence covers single-sided in the other token. The branch changes whether a swap runs. Smallest clarification: the predicate, and the other-token-only deposit rule.

8. **Is idle inside the redeemed slice, and is unused deposit target refunded?** Line 29 defines the position as liquidity plus idle, and idle is not `balanceOf`. Line 51 removes `s / S` of the position. Lines 53-55 and test 2 pay only target removed by burning liquidity plus target delivered by the swap. One implementer pays pro-rata idle target. Another leaves idle, including a preserved liquid-reserve sleeve and add-dust. Current V4 placement withholds an oracle sleeve and reverts if local target is zero after deposit. The PRD never mentions that sleeve. Keeping it changes how much liquidity a deposit adds. Refunding unused target to the depositor changes balances again. Smallest clarification: whether a sleeve remains, whether unused target is refunded or booked idle, and whether idle is excluded from the `s / S` payout.

9. **Does the burned slice include uncollected fees?** Burning a V3 or V4 position can return principal plus uncollected fees. One implementer sells only principal other and leaves fee other. Another sells all other received, including fees, and adds target fees to the payout. Test 2's equality changes if fees are nonzero. Smallest clarification: the slice is principal only, or principal plus fees, and whether other-token fees are sold on exit.

10. **What does the exit minimum compare, what price limit replaces MIN and MAX, and must the whole slice other be sold?** Line 62 says "minimum target out" and also "if the swap cannot deliver that minimum." Test 7 (line 92) compares the minimum to what the swap delivers, not to slice target plus swap output. Current `redeem` compares `minimum_` to total target paid. One implementer keeps that check. Another reverts when the swap output alone is short, even if the total payout meets the caller's minimum. Line 62 forbids `MIN` or `MAX` as a price limit that ignores the slice and does not name the replacement. "Sell only that slice's other token" caps the sale. It does not say the swap is exact-input of the entire slice amount. A partial sale that meets the minimum leaves a different inventory than a revert. Smallest clarification: the compared amount, the price limit, and exact-input of the full slice other or a smaller sale.

11. **What may harvest mutate besides the target-fee credit?** Test 9 (line 94) says a harvest leaves other-token principal in place and may increase settled target only by target fees actually collected. Current `harvest` (line 118) does not sell, but it closes a converted wing and placement puts the tokens back into ranges chosen from the current price. One implementer keeps that close, so redeem's later `s / S` burn sees a different position, and "in place" means "still owned." Another collects fees only, so the wing stays. Compounding other-token fees into liquidity increases principal without a sale. All three pass a loose reading of the sell ban. They do not leave the same position. Smallest clarification: whether deposit and redeem still harvest first, whether converted wings are still closed, and what happens to other-token fees.

12. **Which rebalance sentence wins?** Line 74 says this PRD does not change rebalance. Line 66 says no other function may sell the position's other token. Line 101 says no rebalance call that sells it. Current `_reshape` executes a swap that can sell the other token. Leaving rebalance unchanged violates the sell ban. Stopping that swap changes rebalance. Smallest clarification: one sentence stating that the existing rebalance swap stays, or that the sell ban overrides it. Do not leave both.

13. **Which current rate and exact-route functions follow the new execution?** Line 68 puts `getRate` and `quoteRate` on the counter. It does not say what `quoteRate` does with `state_` besides not pricing it from the quote: ignore it, or revert. Those differ for a transition caller. `exchangeRate` (SY target line 30) is not named and today duplicates the banned formula; changing `getRate` does not change it. `depositExactShares`, `redeemExactAssets`, and `requiredInput` price deposit and redeem from the quote. A broad reading of line 18 forces them onto the new execution. A narrow reading changes only functions named `deposit`, `redeem`, and `getRate`, and leaves `exchangeOut` on the quote. Line 70 allows a labeled non-executing preview to remain a quote, so view-only preview is not the open item. The executing exact routes are. Smallest clarification: a list, each of `quoteRate(state_)`, `exchangeRate`, `depositExactShares`, `redeemExactAssets`, `requiredInput`, and `exchangeOut`, marked as settled-counter or new execution, or as a labeled quote that does not execute.

14. **What is the V3 family beyond the accounting sentences?** Lines 8 and 23 require a new V3 Upper Lower Wings family with the same accounting. They do not state range bounds, fee, target selection, or which V4 facets exist on V3. Current V4 geometry is a full-range core and nearest wings. Copying it is a choice the PRD does not make. A narrow core and a full-range core produce different token ratios, different swap sizes, and different redemption amounts for the same deposit. Including V4 rebalance on the new V3 family imports the line 74 conflict; omitting it is a different vault. Smallest clarification: either "V3 copies the V4 Wings geometry, fee policy, and facet surface, with V3 pool calls" or the name of the document that specifies those facts. This PRD does not currently contain them.

15. **Is the liquidity-fraction equality exact?** Test 1 (line 86) requires B's shares over the new supply to equal B's fraction of remaining liquidity. Removing `floor(L * s / S)` from each slot leaves dust. One test requires exact equality and fails that rounding. Another allows one unit. Line 76 leaves 040 rounding open, which licenses both. Smallest clarification: the rounding direction for the proportional remove and the mint, and whether test 1 is exact.

## Review findings

### Settled target has no ledger

- **Location:** PRD lines 33-37, 66, and test 5 at line 90. Context: tracker line 365, "last settled target balance per share." Current V4 has no counter; `getRate` at `EconomicTarget.sol` lines 27-30 reads the quote.
- **Invariant or requirement:** `getRate` is the last settled target balance per share. It changes only when target moves in a vault operation. It does not follow an outsider swap, and it is not a live reading of composition.
- **Impact:** The display formula does not identify the quantity. Gross deposit, deposit net of entry-swap spend, and a checkpoint snapshot of target still held are different balances. Exit payout, exit-swap receipt, and self-fill can be applied in different orders and produce different rates, including the 100-versus-60 and 35-versus-20 cases in question 1. Test 5 passes all of them if the test reads the implementation's own counter. Two vaults with the same trades return different `getRate`.
- **Fix direction:** Write the credit and debit equation asked in question 1. Do not leave "tokens actually move" as the specification. State that the checkpoint write is that equation, not a `slot0` inventory read. This is not a proposal for which side of the equation to pick.
- **Evidence class:** prd-gap. The event list omits entry-swap spend and does not net the two exit events it does name.

### Three-slot mint and zero-supply bootstrap are undefined

- **Location:** PRD lines 24, 43, 45, and 76. Context: `Accounting.issue` at line 18 mints `credit` at supply zero and `supply * credit / quoted value` otherwise. `Harvest.place` adds into price-derived ranges, not in proportion to existing slot liquidity.
- **Invariant or requirement:** A deposit adds liquidity in proportion to existing core and wing positions, does not open a new range, and mints from liquidity actually added against the pre-add position. The depositor is not gifted other token already held.
- **Impact:** "The liquidity" is not a number when three slots round to different ratios, or when a slot is empty. Supply zero has no pre-add position, and line 24 forbids the deposit from opening the ranges that would create one. Line 76 keeps the bootstrap dead-share rule open. Two implementers mint different first-deposit shares and different later shares from the same target in. Question 2 and question 3.
- **Fix direction:** Write the mint equation, the zero-slot rule, and the zero-supply exception, including who opens the initial ranges. Say whether the open 040 item is allowed to change that first mint. Do not treat current `issue` as the implied answer; it prices from the quote this PRD bans.
- **Evidence class:** prd-gap, with a prd-internal conflict between line 24 and any first deposit.

### Entry swap size is unspecified, and the tick ban is V3-only

- **Location:** PRD lines 13, 18, and 43. Context: tracker "swaps into the current mix," which still names no formula.
- **Invariant or requirement:** A two-sided deposit swaps part of the target into the other token in the same pool, then adds the pair. Deposit is not priced from a book-sale view. On V3 that ban includes `slot0` and a simulated swap.
- **Impact:** Swap size determines the pair added and, under line 43, the shares minted. Pre-swap ratio, post-swap ratio, and a solved amount are different swaps. The `slot0` sentence is attached to V3 only, so a V4 implementer can read `getSlot0` to size the swap while a V3 implementer treats that read as pricing. Question 4. The families this PRD says share one accounting are not given the same tick rule.
- **Fix direction:** State the swap-size rule and whether a tick read used only to size the real swap is banned on both families. Do not invent the sizing algorithm here.
- **Evidence class:** prd-gap. The V3-only sentence is also prd-internal relative to line 17's "same rules."

### Depth-invariant share count contradicts minting from executed liquidity

- **Location:** PRD lines 43, 47, and test 3 at line 88.
- **Invariant or requirement:** Shares come from liquidity actually added, and the same target deposit must not mint more shares because an outsider added liquidity for the duration of the call and then removed it.
- **Impact:** For a two-sided deposit these sentences cannot both be true. External liquidity does not change liquidity-per-token if the price does not move. It does change the entry swap's price impact, the other token bought, the liquidity added, and therefore the line 43 share count. One implementation fails line 47. Another drops line 43 and mints from a quantity the swap output cannot change. Test 3 can be written to pass either, because "around the call" can mean the extra liquidity is gone before the swap. Question 5.
- **Fix direction:** Choose which sentence governs and make test 3 use that window. A clarification that restates both sentences does not close it.
- **Evidence class:** prd-internal.

### Entry no-gift rule does not say whether the vault may be the swap counterparty

- **Location:** PRD lines 13, 21, 31, 43, and test 6 at line 91.
- **Invariant or requirement:** Entry converts through a real swap in the same pool. The new holder is not gifted other token already in the position. Every holder has the same mix. Exit self-fill is intended. Entry self-fill is not mentioned.
- **Impact:** Same-pool execution against V4-style in-range liquidity fills the entry swap with the vault's own other token. A pro-rata claim then gives the new holder other that was already held, which fails test 6. Pulling liquidity out before the swap can pass test 6 and changes the pre-add position used for the mint. Line 31's same-mix rule holds in both builds. It does not decide this. Question 6.
- **Fix direction:** State whether entry self-fill is intended, in the same way line 21 does for exit, and define the test 6 measurement. Do not add a second share class. Line 102 already forbids that.
- **Evidence class:** prd-gap. Test 6 asserts a result the entry steps do not implement.

### Idle is inside the position and outside the exit steps

- **Location:** PRD lines 29, 51-55, and test 2 at line 87. Context: V4 booked `local0` and `local1`, the oracle liquid floor in harvest placement, and the post-deposit `InsufficientLocalTarget` check.
- **Invariant or requirement:** Position amounts are liquidity plus idle, not raw `balanceOf`. Redeeming `s` shares removes only `s / S` of the position and pays only that slice. Test 2 equates the payout to burn target plus swap target.
- **Impact:** If idle is part of the position, `s / S` includes it and test 2 fails whenever idle is nonzero. If idle is excluded, line 51's "the position" does not mean line 29's position. A preserved sleeve also changes liquidity added on the next deposit, so share counts diverge even when the payout test is staged with zero idle. Refund versus booked dust is a third balance outcome. Question 8.
- **Fix direction:** State whether idle is excluded from the payout, whether the sleeve remains, and whether unused deposit target is refunded. One sentence each is enough.
- **Evidence class:** prd-internal, plus a prd-vs-current-v4 gap for the unnamed sleeve.

### Slice fees are unnamed

- **Location:** PRD lines 53-55 and test 2 at line 87.
- **Invariant or requirement:** The burn returns the actual target and other in that liquidity at the current tick. The sale is only that slice's other token. The payout is burn target plus swap target.
- **Impact:** "In that liquidity" can mean principal, or principal plus uncollected fees that a burn-and-collect returns. Selling fee-other and paying fee-target changes the payout and the remaining position whenever fees are nonzero. Question 9.
- **Fix direction:** Say whether the slice includes uncollected fees and whether other-token fees are sold on exit.
- **Evidence class:** prd-gap.

### Exit slippage protection names two different minimums and no price limit

- **Location:** PRD lines 60 and 62, and test 7 at line 92. Context: `Money.redeem` compares `minimum_` to total target out; `_swapDeficit` uses `MIN` and `MAX` sqrt price.
- **Invariant or requirement:** The exit must not reproduce the whole-book opposing sale. The swap does not use `MIN` or `MAX` as a price limit that ignores the slice. If the swap cannot deliver the exiting holder's minimum, the exit reverts and no shares burn.
- **Impact:** The whole-book ban is clear. The protection that replaces it is not. Total target out and swap output are different checks, and both fit a sentence in this section. No replacement price limit is given. Exact-input of the full slice other and a smaller sale that still meets the minimum leave different inventories. Question 10. The current redeem signature has a total-target minimum and no price-limit argument, so two implementers will also house the new check in different places.
- **Fix direction:** Name the compared amount, the price limit, and whether the swap is exact-input of the entire slice other. Do not design a new slippage product beyond closing those three words.
- **Evidence class:** prd-internal on the minimum. prd-gap on the price limit and the fill rule.

### Harvest "in place" does not identify the current close-and-replace

- **Location:** PRD lines 22, 66, 94, and 101. Context: `Harvest.harvest` at line 118 and `Inventory.harvestEligible` at line 61. `Money` calls harvest before deposit pricing and before redeem pricing.
- **Invariant or requirement:** Harvest credits target fees actually collected, does not sell the other token, does not set the counter from the current tick, and leaves other-token principal in place.
- **Impact:** The sell ban is already true of the harvest library. The close is not a sale, and the PRD does not mention it. Keeping the close moves other-token principal out of the wing and can run before the `s / S` burn, so redeem does not remove a slice of the position the holder had. Stopping the close, or compounding other-token fees, is a different position and a different later redemption. Question 11.
- **Fix direction:** State what harvest may change besides the target-fee credit, including whether deposit and redeem still call it first. "Does not sell" does not answer that.
- **Evidence class:** prd-vs-current-v4. Test 9's "in place" is also prd-internal if it means the same slot rather than the same owner.

### Rebalance is both unchanged and forbidden to sell

- **Location:** PRD lines 66, 74, and 101. Context: `RebalanceTarget.rebalance` at line 22 and `_reshape` at line 33, which executes `Planner.bestSwap`.
- **Invariant or requirement:** This PRD does not change rebalance, and rebalance still measures its loss cap at spot. No rebalance call sells the position's other token.
- **Impact:** Against current V4, the two sentences cannot both be implemented. One build leaves the rebalance swap, which can sell the other token. The other build removes that swap and has changed rebalance. Question 12. A new V3 family has no existing rebalance to leave unchanged, so the same pair of sentences also fails to say whether V3 has the function at all. That part is question 14.
- **Fix direction:** State which sentence wins. Do not rewrite the 025 loss-cap rule in this clarification.
- **Evidence class:** prd-internal, confirmed against current V4 `_reshape`.

### Exact routes and SY exchangeRate are outside the named rate functions

- **Location:** PRD lines 18, 68, and 70. Context: `quoteRate` at `EconomicTarget.sol` lines 32-36, `exchangeRate` at `SYTarget.sol` line 30, `depositExactShares` at `Money.sol` line 115, `redeemExactAssets` at line 144, `requiredInput` at line 244, and `OutTarget.exchangeOut`.
- **Invariant or requirement:** Do not price deposit, redeem, or `getRate` from the liquidation quote. `getRate` and `quoteRate` read the settled counter and the supply. A preview that does not mint or burn may remain a labeled quote.
- **Impact:** A narrow reading updates three names and leaves `exchangeOut` pricing exact deposit and exact redeem from the quote. A broad reading rewrites those execution paths and has no formula to put in their place, because questions 1 and 2 are open. `exchangeRate` stays on the banned formula unless it is named. `quoteRate`'s return value is specified; its `state_` argument is not, so ignore and revert are both still available and differ for transition callers. Question 13. Line 70 does close the view-only preview case. That one is not a question.
- **Fix direction:** List each executing caller and `exchangeRate` as new-execution or labeled non-executing quote. State that `quoteRate` does not decode `state_` into a book projection, and whether a foreign `state_` is ignored or reverts.
- **Evidence class:** prd-gap against current callers the PRD does not name. Line 68 already forbids keeping `quoteRate` on `Projection.value`.

### V3 Wings geometry and surface are not specified

- **Location:** PRD lines 8, 17, 23, and 98. Context: V4 `Geometry.ranges` is a full-range core and nearest wings. No V3 `upperLowerWings` tree was found. V3 FullSpread was not used as a stand-in.
- **Invariant or requirement:** Build a new V3 Upper Lower Wings family to this same accounting. Do not convert or delete V3 FullSpread. Do not satisfy the V3 tests with FullSpread.
- **Impact:** The FullSpread exclusion is clear and was followed. It does not specify the family that replaces it. Two V3 implementers can pick different range widths, fees, and facet sets, including whether rebalance and SY exist, and both claim "the same accounting." Those choices change swap size, shares, and redemption tokens. Question 14. A V4 implementer at least has a geometry to leave in place. A V3 implementer does not. The PRD therefore does not force the two families onto one accounting even after the V4 gaps are closed.
- **Fix direction:** Point at the V4 geometry and facet surface, or name the document that specifies the V3 equivalents. Do not fill those facts in from FullSpread, and do not invent a V3 range design here.
- **Evidence class:** prd-gap.

### The required tests do not pin the quantities they name

- **Location:** PRD lines 80-94, especially tests 1, 3, 5, and 6.
- **Invariant or requirement:** The same nine tests run on a real V4 Wings vault and on the new V3 Wings vault, through each family's own registry path and TestBase, with no mocks. They are the proof of the accounting.
- **Impact:** Test 5 checks `getRate` against `settledTarget` without defining `settledTarget` as an observable token amount. Test 1 holds by construction if removal is proportional, and fails or passes on rounding that line 76 left open. Test 3's "around the call" can avoid the swap window that line 47 is about. Test 6 does not define the claim measurement under self-fill. An implementation that fails questions 1, 2, or 5 can still be written to pass this set. The tests therefore do not force two implementers onto one build.
- **Fix direction:** After the questions above are answered, name the observed quantity in tests 1, 3, 5, and 6. Do not add a new economic assertion beyond those answers.
- **Evidence class:** prd-gap.

## Limits

Static reading only. No forge build, no test run, no deploy. Nothing here proves a future vault's runtime behavior.

V3 FullSpread sources were not opened and were not used as the Wings specification. A depth-2 listing showed no V3 `upperLowerWings` tree. V3 divergence is judged from the PRD's silence, not from a V3 Wings implementation, because none exists.

The tracker section is context. It does not contain a companion ledger. A docs search for `settledTarget` found no specification outside this PRD and the tracker restatement. That search incidentally returned excerpts from other members' response paths under `docs/reviews/apex-012-prd-clarity-20261024/members/`. Those files were not opened and were not used. This response was not revised against them.

No replacement economic design is proposed. Where a question asks for an equation, the equation is the clarification the PRD still owes. It is not an equation chosen here.

Current V4 behavior is evidence of paths the PRD leaves free. It is not evidence that the current quote, whole-opposing swap, or harvest close is the required new accounting.
