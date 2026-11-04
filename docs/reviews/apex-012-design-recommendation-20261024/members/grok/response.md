# Member response

## Identity

- Run ID: apex-012-design-recommendation-20261024
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-design-recommendation-20261024/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Recommend one vault design that earns swap fees from a reserve exposed to trading and can be priced and exited into one target token. Deposit, redeem, and the rate must use one rule. Name what that design refuses to do.

The two goals are a fee-earning reserve on the trading path, and a holder priced and paid in one target token. The price is a view: one `uint256`, 18-decimal rate scale, suitable for a rate provider.

Constraints used as binding, from the brief:

- A live same-pool liquidation quote is not the share price. Temporary liquidity and an in-transaction price move must not mint shares or move the rate.
- Do not use one price for the rate and a different zap-out for redemption.
- A single-sided target range is not, by itself, a fee-earning reserve.
- The current Wings deposit does not sell target for the other token. A future conversion is allowed only if the goals require it, and only if this recommendation names why.
- `getRate` cannot execute a sale. A number that previews a sale through current depth is the rejected quote.
- Deposit, exit, and the rate are one rule. Say what value is absent from the rate until a real conversion settles.
- Same mechanism for a V3 pool and a V4 pool unless a protocol difference forces a split.

Targets read: the brief; `docs/reviews/apex-012-deposit-process-20261024/REMEDIATION_PRD.md`; `docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md` as the design being reconsidered, not as a spec to finish; the deposit and redeem path in `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`; `.omo/ulw-research/20261023-171500/SYNTHESIS.md`.

No defect list. This is a design recommendation.

## Evidence

Current V4 Wings money path, as read:

- `_deposit` pulls target, harvests, then sets `value` from `Quote.quote` when supply is nonzero, mints through `Accounting.issue(supply, value, assets_)`, credits the gross target, mints shares, and places. It does not swap target for the other token. (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, `_deposit`.)
- `_redeem` harvests, sets entitlement from `Quote.quote`, and calls `_fund`. `_fund` can close positions and call `_swapDeficit`. `_swapDeficit` reads `getSlot0`, prices the cost with `Quote.swapCost`, and swaps the whole opposing local balance at a `MIN` or `MAX` sqrt-price limit. Redeem then burns shares and pays target. A second `Quote.quote` enforces `HolderValueLoss`. (`_redeem`, `_oneSided`, `_swapDeficit`.)
- The deposit-process report states the same order and states that harvest's header says an ordinary harvest never swaps. `_swapDeficit` is reached from redeem, not from deposit. That report does not select a replacement deposit. It records three unselected options and says a future swap is not banned if it names the ruling it repairs. It also says a later deposit must not open a new range; placement into an empty slot is a separate defect from the sale premise.

The apportioned-reserve PRD is the design under reconsideration. It already forbids a quote on deposit, redeem, and `getRate`, and it forbids replacing that quote with a reference price for the rate and a zap-out for redemption. It then specifies three different operations: a share is a fraction of every position; entry swaps target for the other token and mints from liquidity added; exit burns a slice, sells that slice's other token, and pays the target removed plus the swap output; `getRate` is `settledTarget * 1e18 / supply` and does not include unsold other token. Those are not one rule. The exit payment is a zap. The rate is a counter. The mint is a liquidity ratio. Completing that PRD would not answer this question.

The same PRD states that no Uniswap V3 Upper Lower Wings vault exists in this repository, that V3 FullSpread is not that family, and that a same-pool `slot0` read or a simulated swap is inside the ban. It also states that a single-sided range earns nothing until price enters it, and then holds the other token.

The synthesis found no inspected production Uniswap vault that both earns swap fees and exposes a view one-token rate that ignores the same pool's spot. The pattern it keeps is stored single-token accounting: accounted target times `1e18` divided by supply. Other token stays out of the rate until a separate conversion credits target. That conversion is outside `getRate`. Panoptic's stored-asset shape is cited as a shape only, not as an LP vault. A Maker-style cached external mark is cited as a different precedent and is not the recommended pattern. Wings `getRate` via `Quote.quote` is named as the bug, not as a model.

The collision those sources produce: a two-token position that is actually in range cannot be one target number unless something converts it. A view cannot be that conversion. A redemption that performs the conversion pays a different number from a counter that omits it. One rule cannot be "fraction of the position" and "settled target per share" at the same time.

## Assumptions

- "One rule" means one counter and its inverse. Deposit may be the inverse of redeem. It may not take a second input, including pool spot, a quote, liquidity added, or a zap preview.
- The `1e18` in the rate is the rate-provider scale. It is not a claim that the target token has 18 decimals. `settledTarget` is in the token's native units. A consumer recovers target as `shares * getRate / 1e18`, rounding down.
- A protocol full-range position, tick-aligned, earns swap fees on pool volume in both V3 and V4 and cannot go inactive while the pool can still trade. This was not executed. It is an assumption about the pool, not a reading of a V3 Wings vault. The PRD says that vault source does not exist.
- V3 fee collection and V4 fee collection differ in the call that delivers tokens. That difference does not force a split in the claim rule. No split is recommended.
- Balance deltas can credit or debit target actually transferred without storing `slot0`. A swap still executes at the pool's current price. That execution price is not the rate.
- The deposit-process report's three options are unsettled. The apportioned-reserve sentence "a share is a fraction of the position" is not binding on this answer. Constraints the brief repeats are binding.
- Booked token amounts, not raw `balanceOf`, are the inventory. A donation is not inventory and must not move the counter. That follows the money file's booked `local0` / `local1` split and the PRD's donation rule. The booking implementation was not re-derived beyond that file.

## Coverage

Read in full: the brief, the deposit-process remediation report, the apportioned-reserve PRD, the synthesis, and the V4 Wings money library through redeem, funding, and the quote-backed preview helpers.

Not read, and not used as evidence: peer responses, Harvest source, Accounting source, EconomicTarget `getRate` source, the quote library body, V3 source, open-questions, tests, and any file outside the brief's admitted list. `getRate` today is taken from the PRD and the synthesis, which point at `Quote.quote(...).value / supply`. That call was not opened in this pass.

No Forge run. No public search. No implementation.

## Conclusions

Recommend a **settled-target claim with a full-range fee reserve**. The share is a claim on settled target only. The trading position is vault property outside that claim until a real conversion delivers target.

The position, the deposit, the exit, and the rate are one counter. Two other operations, allocate and convert, exist because the goals require a conversion. They are not a second price, and deposit, redeem, and `getRate` never call them.

**The position.** The fee reserve is one full-range Uniswap position in the vault's pool. Same shape and the same claim rule on V3 and on V4. Full range is the reserve trading volume actually crosses. It stays exposed without a rebalance, and without a spot loss-cap. It will hold the other token. That inventory is not the share. A target wing, or any range that earns only while price is inside it, is not this reserve.

**The deposit.** Target only. No sale. No quote. No place. No new range.

```text
shares = supply == 0 ? assets : assets * supply / settledTarget
settledTarget += assets
```

Division rounds down. The only inputs are the assets just received, `settledTarget`, and `supply`. On the first deposit, mint one share per target unit and leave the rate at `1e18`.

Deposit reverts while booked other token is nonzero or the fee position has liquidity. It also reverts in the same block as allocate or convert. Those are preconditions on when the rule may run. They are not inputs to the amount. Without the inventory precondition, a depositor mints against the counter while other-token value is absent, then shares the later conversion with holders who already bore that inventory. One `uint256` rate cannot exclude them after the mint. Without the block latch, a same-transaction price move can settle a bad fill and mint against the damaged counter. An in-transaction price move then changes the shares.

**The exit.** Pay the same counter. Do not remove liquidity. Do not swap. Do not read the pool.

```text
assets = settledTarget * shares / supply
settledTarget -= assets
```

Pay `assets` of target and burn the shares. That is `getRate * shares / 1e18`, same rounding. A caller minimum may reject that deterministic amount. It is not a swap slippage limit. A non-final holder may exit at this number and leave unsettled inventory to the remaining shares. That forfeiture is the rule, not a second payout.

A redeem that would leave supply at zero while booked other token or position liquidity remains reverts before payment. The holder converts first, in a prior block, then exits at the updated counter. The successful payment is still the rule. The revert is a refusal to abandon the fee reserve to a zero-supply vault. It does not price a successful exit differently.

Redeem and deposit must not run in the same block as allocate or convert. Full exit of value the rate had omitted therefore takes a later block. The amount paid in that later block is the rate a caller can read before sending it.

**The rate.**

```text
getRate = supply == 0 ? 1e18 : settledTarget * 1e18 / supply
```

One `uint256`. Inputs are the counter and the supply. `getRate` does not swap, does not preview a swap, and does not read `slot0`, a quoter, or position composition.

Absent from the rate until a real conversion delivers target into the counter: other-token principal in the position, other-token fees, and the target allocate already spent to buy that principal. Absent until a harvest delivers target into the idle balance: uncollected target fees. A reversed outsider swap does not write those amounts back. A donation does not write them in. Temporary liquidity does not write them in.

`settledTarget` moves only when target actually transfers in a vault operation: deposit credit, redeem debit, target fees harvested into idle, target spent by allocate, target delivered by convert. The amount is the idle-target balance delta of that operation, not the tick math used to execute it.

**Why the goals require a conversion, and where it sits.** Goal 1 requires an in-range reserve. A full-range position at the current tick holds the other token. Target-only placement cannot mint it. Some deposited target has to be sold. That sale is allocate, not deposit. Putting it in deposit would make an in-transaction price move change the mint, and it would credit a share on a swap the counter must not mark.

Goal 2 requires payment in one target token. Other token the position has collected is not payable. It has to be sold. That sale is convert, not redeem, and not `getRate`. Putting it in redeem would make the payout a zap. Putting it in `getRate` would make the view a sale, or a preview of one.

Allocate spends an explicit target budget, at most the idle settled target, and must leave `settledTarget > 0` while `supply > 0` so the rule stays defined. It may use the current tick as execution math to split that budget into the two tokens the mint requires. If the mint cannot be funded inside the budget, revert and leave the counter unchanged. It must not size the budget from `Quote.quote`, a simulated book sale, or `slot0` used as a valuation. The counter falls by the net target that leaves idle.

Convert withdraws any part of the position and sells only the booked other token the caller named. It credits the target the swap delivers. A caller minimum target out reverts the call with no counter change if the swap delivers less. That minimum is slippage on the settlement. It is not the share price. Convert does not use an unbounded `MIN` or `MAX` sqrt-price limit, and it does not sell "the whole opposing balance" as a side effect of redeem.

Harvest may credit target fees actually received. It must not sell the other token. Selling other token is convert.

**The refused behavior.** The design refuses to treat the trading position as the thing a share is priced or paid in. A share is not a fraction of that position. Exit is not a liquidation. The rate is not a quote of the position. Unsold other token is not value until a vault swap delivers target. The design also refuses the deposit-then-convert extraction that a single rate would otherwise allow, by refusing deposits while that inventory exists.

**The cost.** The published rate is payable target, not net asset value. It falls when allocate spends target to seek fees, and it stays below the position's liquidation value until harvest or convert brings target back. A rate-provider consumer that wants a mark, or a lending market that wants collateral value, will understate the vault. That understatement is the protection. It is also the cost.

Deposits and fee exposure are mutually exclusive. While the full-range position is open, the vault earns fees and does not take deposits. New shares are minted only after convert has closed the position and credited delivered target, and only in a later block. Share transfers still move existing claims during exposure. Capital that must become new shares waits for a window.

A holder who redeems during exposure leaves the fee reserve to whoever still holds shares. A holder who wants that value included must convert first, which settles it for every share, then redeem at the new rate in a later block. One number cannot give the leaver the inventory and also keep it out of a same-block mint.

Full range holds more other token per fee than a narrow in-range position, so more value sits outside the rate, and convert realizes divergence loss instead of marking it. Allocate and convert can be sandwiched. The bad fill is a real target delta in the counter. A later reverse swap by the attacker does not restore the rate. If convert is never called, fees in the other token never become payable. The design depends on that call and refuses to hide it inside `getRate`.

Rejected alternatives, one sentence each:

- The apportioned-reserve PRD is rejected because a position fraction, a slice zap, and a settled-target rate are three rules, and the zap is the forbidden second price.
- The current Wings money path is rejected because deposit and redeem both call `Quote.quote`, and `_swapDeficit` sells the whole opposing balance through `slot0`.
- An entry swap that matches the existing mix before mint is rejected because the mint still depends on inventory composition, and the exit remains a different conversion from the rate.
- A single-sided target range is rejected as the fee reserve because it earns only while price is inside it, and then it holds the other token.
- Using one live same-pool quote for mint, redeem, and `getRate` is rejected because that preview is the banned quote, and temporary liquidity moves it.
- An oracle or cached TWAP rate paired with a zap-out exit is rejected because the rate and the exit are different prices, and a same-pool mark moves inside the caller's transaction.
- A per-holder checkpoint that blocks the conversion gift is rejected because a rate provider has one number for every share.
- Counting target still inside the position, or an `s_inAMM`-style in-pool balance, in the rate is rejected because an outsider swap changes it and recording it reads pool state.
- A V4-only JIT hook that ends each swap in target is rejected because V3 cannot run the same claim path, and that protocol difference would be an implementation split rather than a forced split in the rule.
- Managed wings plus rebalance are rejected because the target wing is not the exposure goal 1 asks for, and rebalance prices a loss at spot.

## Limits

Static reading of the admitted files. No Forge run, no peer comparison, and no test of full-range fee per capital. V3 Wings source is absent, so the V3 half is the same rule applied to a full-range position, not a reading of a V3 vault. Harvest's no-swap behavior is taken from the deposit-process report's statement of the header, not from opening Harvest. Today's `getRate` body was not opened; the PRD and the synthesis name it as `Quote.quote` over supply.

The terminal-exit guard is not fully specified for unsellable other-token dust. Strict reading can block supply from reaching zero if convert cannot sell a remainder. This pass does not set a dust threshold. The payment rule for a successful exit is still the counter.

The block latch stops same-block bundling of settlement and mint or pay. It does not stop an attacker from sandwiching allocate or convert in their own transactions. That loss is accepted and named above. It was not measured.

This recommendation does not authorize implementation, a launch-script change, or a transaction. It does not claim a deployed Wings vault can be upgraded. The apportioned-reserve PRD says existing deployments are immutable; that immutability was not re-checked in code.
