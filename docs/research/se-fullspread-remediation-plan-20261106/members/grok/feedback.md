# Feedback

## Identity

- Member: grok
- Phase: advisory review
- Role: council-member
- Requested model: xai/grok-4.7:xhigh
- Actual model: not exposed
- Task ID: not exposed
- Fresh or continued: not exposed
- Runtime reasoning: not exposed

## Draft under review

- Draft ID: draft-se-fullspread-remediation-plan-20261106-r1
- Draft path: docs/research/se-fullspread-remediation-plan-20261106/coordinator/draft.md
- Coordinator-supplied SHA-256: b2738a3b21c993f0e13153cdf7aefa4e27cd113f318f75c3d0adf54d3de74fba
- That hash was not recomputed
- Requirement fingerprint recorded in the draft, coordinator-supplied, not recomputed: 4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3

## Disposition

requested-changes

This feedback does not authorize implementation and does not replace the draft. It does not request another round.

Section 1 is not a concern. The copied law in section 3 is not a concern. The draft does not restore a removed sizing method. The concerns are places two readers of the draft would not do the same thing.

## Concerns

### Sections 4 and 5. A partial fill of the 49% quote

Section 4 says one exact-input quote of 49% of the processed input. Section 5 says the swap input is `mulDiv(amount, 49, 100)`, and that a 49% swap that cannot be formed keeps no swap. Neither section says whether a quote that spends less than that amount, but spends more than zero, has formed the swap.

One reader keeps `quote.spent` and adds against that smaller amount. Another reader treats any spent amount other than `mulDiv(processed, 49, 100)` as a collapsed candidate, pushes no swap, and does not retry. Both can cite the draft. The second reading is the closed law: swap 49%, do not iterate, and keep no swap when that swap cannot be formed.

Requested change: state, as advice and not as an edit, that the swap input equals `mulDiv(processed, 49, 100)`, and that a quote which does not spend that whole amount, or which receives zero, is collapsed. Do not keep the smaller spent amount. Do not retry a smaller size.

### Section 5. "A later share mint"

Section 5 says a collapsed candidate keeps no swap, then says a later share mint refunds the whole input and mints nothing. Section 3 says a share mint refunds that input and mints nothing.

One reader refunds on the collapsed share-mint call itself, unless that call is a first deposit that does not add more than 1,000 liquidity. Another reader leaves the collapsed call unrefunded and waits for a later mint. "Later" is the split.

Requested change: state that the share-mint path of that same call refunds the whole input and mints nothing, except when the call is a first deposit that does not add more than 1,000 liquidity, which reverts `MinLiquidityNotMet` and does not refund.

### Sections 4 and 6. Which function pays the receipt

Section 4 says `Planner._exit` sets `amountOut` to the four-part receipt, and names `Execution.exchangeIn` only for `plan.failed` and the first-deposit floor. Section 6 says pay the recipient the four-term sum and that `minAmountOut` binds it. The 2026-11-06 lock, which section 2 says wins, also says the receipt is not a stale preview. The draft never says that.

One reader pays `plan.amountOut` from the planning quote. Another reader has `Execution.exchangeIn` pay the four-term sum using the requested token the executed swap delivered in that call. One reader also reverts `AmountOutNotMet` before the burn when the executed sum is below `minAmountOut`. Another reader burns first. Section 4 puts "before the burn" only on `plan.failed`.

Requested change: name `Execution.exchangeIn` as the function that pays and returns the four-term receipt. Swap proceeds are the requested token delivered by the executed swap in that call, not a preview taken before the call. A minimum miss reverts `AmountOutNotMet` before the burn, as the projected shortfall already does. Do not add a new error for an unobserved quote-versus-pool gap.

### Section 6. Whose opposing principal is swapped

Section 6 says swap all opposing principal, opposing fee, and opposing booked claim. The fee and booked sentences above it are the holder's claims. "Opposing principal" is not tied to the withdrawn exiting claim. Section 4 says "the whole unwanted claim," which is narrower.

One reader swaps only the exiting holder's withdrawn opposing principal plus that holder's opposing fee and opposing booked claim, and does not swap the staying holders' inventory. Another reader swaps every opposing-token principal in the position. The closed law is the first reading.

Requested change: state that the swapped amount is that exiting holder's withdrawn opposing principal plus that holder's opposing fee and opposing booked claim. Do not swap, pay, or book that residual if the swap cannot spend it. Do not swap the staying holders' inventory.

### Section 7. Which `setUp` the weighted row calls

Section 7 says the weighted two-leg `setUp` calls the parent `setUp`, then `_initializeWeighted(2)`. The contract's inherited parent is the behavior contract. The family plan says this row calls the weighted test base and does not call the behavior `setUp`.

One reader calls `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()`. Another reader calls the behavior parent `setUp`. Those are different functions.

Requested change: name `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()`, then `_initializeWeighted(2)`. Do not call the behavior `setUp`. Do not delete the override. Leave the three-leg file as the `n == 3` override.

### Section 7. Capacity overrides and `seBooked`

Section 7 says keep the empty `limitCapacity` and `openCapacity` overrides if the parent declares them. The closed law is that they stay unless the parent does not require them. The parent `SeMatrixFixture` declares `limitCapacity`, `openCapacity`, and `seBooked` with no body. The draft leaves the check open and does not say not to add a production booked view.

One reader keeps the empty overrides and leaves `seBooked` returning 0. Another reader deletes the overrides, or adds a production booked view so `seBooked` can report the ledger instead of a balance.

Requested change: state that the parent declares those three functions with no body, so the empty capacity overrides stay and are not filled in. `seBooked` returns 0 and does not read a balance. Do not add a production booked view. Do not add a capacity gate.

### Section 7. FS-A01 through FS-A04 narrowed by the colon

Section 7 says `Package.t.sol` must assert FS-A01 through FS-A04: the selector cut, a `bindingHash` change, `InvalidComponent` for each of the six addresses, and the slot check. The colon can be read as the whole requirement.

One reader asserts the family-PRD rows, including an uninitialized pool key, a hooked pool key, a second initialization, a wrong `processArgs` caller, and the bound registry in the wrong account. Another reader asserts only the four items after the colon and treats FS-A03 as done. F9 adopted the rows, not the four-item gloss.

Requested change: state that the colon does not replace FS-A01 through FS-A04. Keep the six-address `InvalidComponent` check, and also name the other FS-A03 rejects: uninitialized pool key, hooked pool key, second initialization, wrong `processArgs` caller, and the bound registry when `address(this)` is not the bound `diamondFactory`. Do not add an `exchangeRate` test.

### Section 8. Gas routes and files are not named

Section 8 names the seven standalone routes and says each lives in the money or maintenance file that owns the route. It says one composed measurement for each family-plan section 12 row, in that row's file, and one preview measurement for each preview route. It does not name the row files or the measured call. Section 9 says this pass does not walk the preview-consumer index.

One reader measures the seven routes in `Money.t.sol`, one exact-input hook swap in each of the nine section 12 row files, with setup outside the snapshot and no preview before it. Another reader puts `compound` in a separate maintenance file, counts `BufferHookIntegration.t.sol` as a section 12 row, measures a direct vault call or an exact-output call, or adds a preview measurement per index consumer. The brief required each route and file to be named. The closed law is one cold measurement per named standalone route and per section 12 row, ceilings unchanged, no preview warm-up.

Requested change: name `Money.t.sol` for all seven standalone routes. Name each section 12 row file from the family plan, and name the measured call as that row's exact-input hook swap that mints this vault's shares, whole transaction, setup outside the snapshot. Do not count `BufferHookIntegration.t.sol` as one of those rows. Limit preview measurements to the quote-file preview routes the family plan already assigns. Do not walk the index to invent more.

### Section 9. Unresolved list

Section 9 says naming the unresolved items is not a finding that they are defects. The closed law says do not implement those items in this plan.

One reader does not implement them. Another reader implements them because the draft does not forbid the work, only the defect label. The first-deposit floor in section 5 is the adopted lock. It is not a license to implement the rest of that unresolved report.

Requested change: state that the unresolved list is not implemented in this plan. Do not expand the adopted floor sentence into the other unresolved items.

### Section 10. Donate, compound, boundary, and exit-receipt rows

The inside donate and compound row says the same 49% shape, without saying one-token. The boundary rows say no swap, without saying price equal to each stored bound. The exit-receipt row states the four-term sum, without saying the fee portion and the booked claim must be nonzero, and without saying the figure is not a preview taken before the call. Section 10 also says a row that already matches stays.

One reader asserts 49% only on a one-token `donate` or `compound`, sets the price equal to each bound, and uses a nonzero requested fee portion and a nonzero requested booked claim. Another reader requires a both-token compound to swap 49%, treats a price outside the range as the whole boundary row, or keeps a two-term receipt test because those other terms were zero and the row "already matches."

Requested change: state that the 49% donate and compound row is the one-token path only, and that a both-token maintenance call does not swap. State that each boundary row includes price equal to each stored bound, not only a price outside the range. State that the exit-receipt row is not met when the requested fee portion and the requested booked claim are zero, and that `amountOut` is not a preview taken before the call.

### Section 12. Stop omits package, fixture, and gas

Section 12 stops when every section 10 row is true, or when a named function cannot meet its section 4 row without a new product choice. Section 10 does not carry the package rows, `seBooked`, the weighted `setUp`, or the gas measurements. Section 8 says an oversized route is unresolved, not passed, but section 12 does not name that report as a blocker.

One reader stops when the section 10 money rows are true and leaves F5, F6, F8, and F11 open, or raises a ceiling when a measurement does not fit. Another reader stops only when the section 7 rows, the section 8 measurements, and the section 10 rows are true, and reports an oversized measurement without passing it and without raising the ceiling.

Requested change: stop when the section 7 package and fixture rows, the section 8 measurements, and the section 10 rows are true, or when a named blocker is reported. Name an oversized measurement as a blocker: report the route, file, and measured value; do not pass it; do not raise the ceiling. Do not certify the preview-index walk. Do not choose a new product rule.

## What was not adopted from others

Peer responses and peer feedback were not read. Nothing in this feedback is adopted from them. This feedback also does not ask the draft to copy another member's test names or file layout. A concern above is only a split in the draft, or a drop of a closed law.

## Limits

- The draft was read. The coordinator-supplied SHA-256 was not recomputed.
- No file was edited except this feedback file.
- No test, Git command, or install was run.
- This feedback does not replace the draft.
- This feedback does not authorize implementation.
- This feedback does not request another round.
