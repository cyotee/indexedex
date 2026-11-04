# Member response

## Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Three questions.

1. Why did the prior review treat a deposit as a sale of target for the other token?
2. Does the existing Wings deposit process sell target for the other token?
3. If `Quote.quote` is removed from the share mint and the rest of the existing deposit sequence is kept, is that process valid under the preserved rulings? If not, what is the smallest deposit process that is valid?

Preserved rulings used for question 3, as named in this run's brief: no live whole-book quote on deposit, redeem, or `getRate`; a share is a fraction of the position; a depositor does not receive a gift of other token already held; an exit may sell only that holder's other token.

Targets read: PRD Entry and the surrounding rulings that define those four tests; `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol` `_deposit`, `_harvest`, `_place`, `_swapDeficit`, and the only callers of `_swapDeficit`; `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol` header, `harvest`, `placement`, and the operations those functions enqueue. Optional context read: `APEX-2026-012-OPEN-QUESTIONS.md`, `docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md`, and `Accounting.issue`.

## Evidence

### What the code does

`_deposit` pulls target, harvests, reads a quote, mints, credits the gross deposit as local target, and places. It does not build a swap.

```128:139:contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol
_pull(assets_, pushed_);
uint256 supply = ERC20Repo._totalSupply();
if (supply == 0) _bootstrapBacking(assets_ + refundReserve_);
_harvest();
uint256 value = supply == 0 ? 0 : Quote.quote(Common.quoteRequest()).value;
shares_ = Accounting.issue(supply, value, assets_);
if (shares_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, shares_);
if (exact_ != 0) shares_ = exact_;
_changeTarget(assets_, true);
ERC20Repo._mint(recipient_, shares_);
_place();
if (_localTarget() == 0) revert IUniswapV4UpperLowerWingsStandardExchangeVault.InsufficientLocalTarget(1, 0);
```

`_harvest` (line 94) and `_place` (line 100) return immediately if the pool manager is unlocked. Otherwise they execute `Harvest.harvest` and `Harvest.placement`. The harvest header says ordinary harvest never swaps. Both functions enqueue `Common.Kind.Modify` only (`close` at line 142, `_add` at line 191). A Modify burns or mints liquidity in an existing or geometry range. It does not exchange one token for the other. Grep of the harvest file finds no `Kind.Swap`.

`Accounting.issue` (lines 18-22) is `credit` when supply is zero, otherwise `supply * credit / value`. The value argument on the deposit path is `Quote.quote(...).value`, not an inventory amount. The credit argument is the gross target pulled. `_changeTarget(assets_, true)` then books that same gross amount. The pending pull is not in local target when the quote runs.

`_swapDeficit` (line 219) is the only `Kind.Swap` constructed in this file. It swaps the opposing local balance, `local1` when target is currency0 and `local0` when target is currency1, toward target, with a `MIN` or `MAX` price limit. That is other token sold for target. Both call sites are in `_fund` (lines 200 and 207). `_fund` is called only from `_redeem` (line 170), and only when the manager is not unlocked. Deposit does not call `_fund` or `_swapDeficit`.

`Quote.quote` on line 132 is a view. The PRD Source bullet describes that view as removing owned liquidity and simulating a sale of the book through remaining external liquidity. The simulated direction is book to a target value. It is not an execution, and it is not a sale of the depositor's target for the other token.

### What the PRD says

Required outcome, line 13: entry and exit convert through a real swap in the same pool. `getRate` does not preview that swap and does not read the current tick.

Owner ruling, line 22: other token is sold for target only inside the acting holder's own entry or exit. Harvest does not sell the other token and does not set the rate from the current tick. A share is a fraction of every position, core and both wings. A deposit adds liquidity in proportion to those positions and does not open a new range.

Entry, line 43: a deposit is target only. If the position is already two-sided, the vault swaps part of that deposit into the other token against the same pool, then adds the resulting pair as liquidity. Shares are minted from the liquidity actually added against the position that existed before the add. The depositor does not receive a gift of other token that was already in the position. Old holders' share count does not change.

Entry, line 45: if the position is single-sided in target, no swap is required.

Entry, line 47: the same target deposit must not mint more shares because an outsider added liquidity for the duration of the call and then removed it.

Test 6, line 91: the new holder's claim on other token is only the other token bought by the entry swap, not a slice of the other token that was already held.

These sentences are not the same trade. Line 22 sells other token for target. Line 43 sells target for the other token. Test 6 defines the no-gift outcome as the result of the line 43 trade.

### What the prior review wrote

`docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md` was a PRD clarity review. Its coverage table (line 28) says V4 Wings sources were partially examined as context. Runtime was not examined. It did not trace `_deposit` and did not identify `_swapDeficit` as redeem-only.

Its preserved list (line 40) shortens line 22 to "Other token is sold only on the acting holder's entry or exit." The words "for target" are not in that bullet. Question 1 (line 52) then asks how `settledTarget` is credited "after a deposit that spends some target in the entry swap." Question 4 (line 58) is an open entry-swap sizing question. Those questions assume line 43. They are not a finding that the code sells target.

The open-questions file records the 2026-10-24 correction: a deposit does not sell target for the other token, question 1 is invalid while it assumes that sale, and the existing deposit process is the reference unless a council shows that process is invalid under the preserved rulings. That note does not withdraw line 43's gift sentence. This run's brief lists that gift sentence as a preserved ruling for the validity test.

## Assumptions

- "Preserved rulings" for question 3 means the four named in this run's brief. The prior council's preserved list is context. It does not contain a separate no-gift bullet. This run added that test, so the gift sentence is in force here.
- The gift sentence is an outcome rule: the new holder must not receive a unit claim on other token that was already in the position. Test 6 states that outcome in terms of the entry swap. The swap is not assumed to be what the code does. It is considered only as a repair if the outcome rule fails.
- Other-token inventory means post-harvest vault inventory, idle plus principal plus fees, as `Harvest.totalInventory` already sums it. It does not mean `balanceOf`, and it does not mean a liquidation value. The pending pull is not part of that inventory, because `_changeTarget` has not run and harvest snapshots local balances.
- A swap the vault fills against its own liquidity does not increase that inventory. Tokens moved from a position to idle are still the position.
- Line 47 and test 3 are not in the four-ruling test. They stay unresolved, as the prior review left them.
- No implementation is authorized by this response.

## Coverage

Examined the deposit sequence, both harvest entry points, the swap call graph in the money file, `Accounting.issue`, the PRD Entry section and the rulings and tests cited above, the open-questions correction, and the prior coordinator final.

Not examined: peer responses of this run; `Common.execute`; the liquidation-quote library; V3 Wings source, which does not exist; redeem, `preview`, and `requiredInput` except to see that they still call `Quote.quote`. No Forge run.

## Conclusions

### 1. Why the prior review treated a deposit as that sale

The cause is the PRD Entry section, not `_deposit`.

Line 43 says that if the position is already two-sided, the vault swaps part of that deposit into the other token. Line 13 says entry converts through a real swap. Line 91 defines a successful entry as the depositor owning the other token that swap bought. The prior review took that design as given and asked how the counter and the swap size work (prior report lines 52 and 58). Its coverage note says the V4 sources were context, not the thing being traced.

Do not attribute the assumption to `_deposit`. That function does not swap. Do not attribute it to `Quote.quote`. That view simulates a sale of the book into a target value, which is the other direction. Do not attribute it to `_swapDeficit`. That function sells other token for target, and only while funding a redeem.

Line 22 did not require the assumption. It says other token is sold for target, on the acting holder's entry or exit. The prior report's preserved bullet dropped "for target," which makes "on entry" sound directionless. The specific claim that the deposit spends target comes from line 43, not from that shortened bullet and not from the code.

The owner correction matches the code. It does not match line 43. Line 43 is why the prior questions assume the sale. Those questions are not evidence that the code sells target.

### 2. Does the existing deposit sell target?

No.

The executed deposit sequence is pull target, harvest, quote, mint, credit the gross target, place, require leftover local target. Harvest and placement enqueue liquidity modifications only. The harvest header says ordinary harvest never swaps. The only swap in this money file sells the opposing local balance for target, inside `_fund`, called only from `_redeem`.

`Quote.quote` does not change that. It is a view used as the mint denominator. Removing it removes a simulated book sale from the mint. It does not remove an executed sale of target, because that sale is not in the sequence.

### 3. Is the quote-removed sequence valid?

No, when post-harvest other-token inventory is positive. It is valid when that inventory is zero, including a first deposit into a vault that holds no other token.

Code and PRD diverge here. The code, minus line 132, keeps a target-only pull, a no-swap harvest, a fungible mint, a gross target credit, and a no-swap place. The PRD Entry section says a two-sided position is entered by swapping part of the deposit for the other token. The owner correction rejects that swap as a description of deposit. The validity test is the four rulings, not line 43's mechanism and not the correction by itself.

Against the four:

- No live whole-book quote. Satisfied for this sequence once line 132 is removed and the replacement denominator is not a depth sale of the book. `Accounting.issue` does not quote. This says nothing about redeem, `preview`, or `requiredInput`, which still call `Quote.quote`.
- A share is a fraction of the position. Satisfied by any single fungible mint. After the mint, every share is `1 / newSupply` of idle and of all three slots. The equation that fits the unchanged sequence is below. It does not need a swap.
- An exit may sell only that holder's other token. Not violated by this sequence. Deposit does not sell other token. `_swapDeficit` remains on the redeem path only. This review does not bless that redeem path.
- A depositor does not receive a gift of other token already held. Failed when other-token inventory `O` is positive.

The failure is arithmetic, not a missing denominator. Let supply be `S`, pre-credit target inventory be `T`, pre-credit other-token inventory be `O > 0`, and the deposit be `D > 0`. The sequence adds no other token. After a mint of `s > 0` shares, the new holder owns `s / (S + s)` of `O`. That is a slice of other token already held. Old holders' other-token units fall by the same amount. They did not sell it.

No value passed to `Accounting.issue` removes that claim. The share is a claim on the whole position, including idle other token. Changing the denominator changes `s`. It does not change what a share owns. The current quote denominator fails the same outcome: it charges the depositor in simulated target and still assigns them a unit slice of `O`. Line 18's quote ban removes that charge. It does not create the other token the gift sentence requires the depositor to have bought.

The equation that fits the unchanged sequence, and that must not be used when `O > 0`, is:

`shares = Accounting.issue(supply, targetInventory, assets)`

which is `assets` when supply is zero, and `supply * assets / targetInventory` otherwise. `targetInventory` is post-harvest target inventory, excluding the pending pull. That equation does not call `Quote.quote`, does not read a book sale, and does not add an entry swap. It is the single-sided equation in line 45. It gifts `O` whenever `O > 0`.

The smallest process that still deposits, and that satisfies the gift sentence, has to add other token that was not already in the position before the mint. That is an entry swap. It is added only because the quote-removed sequence violates the gift ruling. It is not added because line 43 says so, and it is not what `_deposit` does today.

## Review findings

Finding: a quote-removed deposit into a position that already holds the other token gifts that other token to the new holder.

Location: `UniswapV4UpperLowerWingsStandardExchangeVaultMoney._deposit`, lines 128-139. The defect appears once line 132 is deleted and the pull, harvest, gross credit, mint, and place remain.

Ruling: "The depositor does not receive a gift of other token that was already in the position." PRD Entry, line 43. This run's brief lists that outcome as a preserved ruling. The prior council's preserved list does not. Test 6, line 91, is the same outcome written as if the entry swap had already happened. The ruling used here is the outcome sentence, not the assumption that the code already swaps.

Impact: any positive fungible mint gives the new holder a unit claim on pre-existing other token, idle and in range. Old holders' share count stays the same and their other-token units fall. No mint equation inside the unchanged sequence prevents that while a share remains a fraction of the position. The deposit therefore cannot both complete and satisfy the ruling unless other token is added from outside the position first.

Smallest deposit process:

1. Keep the pull, the zero-supply bootstrap, the no-swap harvest, the no-swap place, and the terminal local-target check.
2. Delete `Quote.quote` from the mint. Do not replace it with another view that sells the book through current depth.
3. Measure post-harvest target inventory `T` and other-token inventory `O` from vault inventory, not from `balanceOf` and not from a liquidation quote. The pending pull is not in that measure.
4. If `O == 0`, do not swap. Mint `Accounting.issue(supply, T, assets)`. Credit the gross deposit with `_changeTarget(assets_, true)`. This is the existing sequence without the quote. Line 45 already says no swap in this case.
5. If `O > 0`, the gift ruling requires an entry swap before the mint. Swap deposited target for the other token in the same pool. Let `X` be target spent and `Y` be the increase in vault other-token inventory, not the swap's gross output if that output came out of the vault's own position. Require `(assets - X) / Y = T / O` when `T > 0`. When `T == 0`, the match is `X = assets`. Mint `Accounting.issue(supply, O, Y)`, which is `supply * Y / O`. Credit retained target `assets - X`, not the gross deposit. A gross credit would book target the swap spent.
6. If `Y == 0`, `Accounting.issue` reverts on a zero credit. Do not mint. A self-fill does not buy other token; it relocates inventory the shares already claim. Routing the swap around the vault's own liquidity is not part of this process. If the only fill is the vault, the deposit reverts.
7. Keep the existing `exact_` override and its floor check, pointed at the new `issue` result. `depositExactShares` may mint fewer shares than `issue` returns. It must not mint more. Fewer shares do not give the depositor a larger slice of pre-existing `O`.

No other entry swap is in this process. Harvest still must not sell the other token. Exit is unchanged. `_swapDeficit` stays a redeem funding function.

The owner correction is right about the code and wrong as a claim that this sequence is valid. The sequence is the reference only until it fails a preserved ruling. It fails the gift ruling in the two-sided case. The swap in step 5 is that repair. It is not a reading of `_deposit`.

## Limits

- Line 47 and test 3 say the same target deposit mints the same shares with or without temporary external liquidity. `Y` from a real pool swap depends on that liquidity, so step 5 can fail line 47. The prior review recorded that contradiction and did not decide it (prior report, the paragraph before the preserved list, and open question 2). Line 47 is not one of the four rulings for this question. This response does not pick it over the gift sentence, and it does not invent a sizing quote to paper over it. Sizing `X` by `LiquidationQuote.quote`, by a simulated sale of the book, or by `slot0` is not authorized here. Open question 4 remains open. If no execution meets the inventory ratio without a forbidden pricing view, the deposit reverts.
- A revert whenever `O > 0` would also avoid the gift and would not add a swap. That is a refusal, not a deposit process for the position the gift ruling is about. It is not the process above.
- The terminal local-target check is kept. A position with `T == 0` that must swap the whole deposit can still revert on that check. This response does not remove the check to force that deposit through.
- `place` can add liquidity to an empty geometry range. "A later deposit does not open a new range" is a prior preserved sentence and open question 8's neighbor. It is not one of the four rulings tested here, and this process does not change `place`.
- Proportional slot addition is an owner-ruling sentence and open question 2. A share can be a fraction of the whole position without each slot receiving a proportional add. This process does not add that requirement.
- Fee ownership is open question 6. Using `Harvest.totalInventory`, which includes uncollected fees, is the measure that keeps those fees inside `O` and `T`. It does not settle question 6.
- A zero-supply vault that already holds donated other token is open question 7 and APEX-2026-040. This process does not swap on the first deposit.
- Redeem, `preview`, `requiredInput`, and `_postHarvestValue` still call the quote. The no-quote ruling covers them. They are not this deposit sequence, and no redeem process is proposed.
- `Common.execute` was not read. The claim that harvest and placement do not swap is the operations they enqueue, plus the harvest header. It is not a trace through the manager callback.
- Static reading only. No Forge run. V3 Wings source does not exist. Nothing here authorizes implementation.
