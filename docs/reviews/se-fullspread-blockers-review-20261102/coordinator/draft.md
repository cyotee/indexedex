# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-blockers-review-20261102-r1
- Path: `docs/reviews/se-fullspread-blockers-review-20261102/coordinator/draft.md`
- Run ID: se-fullspread-blockers-review-20261102
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: `members/astra/response.md`, `members/grok/response.md`, `members/minimax/response.md`, `members/kimi/response.md`

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?

## Proposed text

The file is not ready to be the sole instruction for rewriting the PRD. The large locks agree with each other: the sleeve is gone, the usage fee is taken from the new shares and clamped at 30%, entry and redemption swap limits stay unbounded, a redemption swaps only the withdrawn net, the vault has no rate, and a pretransfer uses the unbooked balance up to the caller's maximum. A lock that differs from the current PRD is not a defect. The file says the PRD waits for one pass.

The defect is that several locked sentences name different outcomes, and several others still leave an observable choice. A rewriter who copies the file as it stands will either delete a later lock or ship two different vaults. This draft does not edit the blockers file or the PRD, and it does not authorize implementation.

### Consistent enough to copy

These can be copied once the findings below are reconciled. They are not reopened.

- Sleeve dropped. No `liquidReservePercentageOfVault` target. No sleeve adjustment swap.
- `compound()` and `donate()` are `onlyOwnerOrOperator`. A deposit, a withdrawal, and `exchangeIn` do not call them. The owner accepts a sandwich of that maintenance call and will tell users.
- Entry and redemption limits stay at the Uniswap minimum and maximum. A redemption swaps only the withdrawn net.
- A call with no fees, no donation, and no booked remainder returns unchanged and emits nothing.
- Positive supply with zero deployed liquidity is not given a denominator.
- Borrowed exit uses the open unlock, pulls the deployed fraction, does not call `unlock()` again, and has no sleeve fallback.
- `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` have no other arguments.
- The B-13 lock matches `docs/vaults/PRETRANSFER_DIRECTIVE.md`. Provenance is not checked. The refund is the caller's maximum minus the amount used, in the provided token. The rest of the unbooked balance is not refunded. Parked shares are not the caller's burn credit.
- The 1,000-share floor is minted to `address(0)` through `_mint`. N-06 library assignment and N-07 staying closed are not product choices.

### D1. Genesis credit is stated two ways

- Location: B-01, the `grossShares` paragraph. B-10, "The depositor receives `added liquidity - 1,000`." Already-locked list, the same B-10 sentence.
- Requirement: one genesis credit, one fee base, and one supply increase.
- Impact: at a 30% fee, B-01 credits the first depositor `(added liquidity - 1,000) - feeShares`. B-10 and the summary credit `added liquidity - 1,000`. "Supply grows only by `grossShares`" also fights the floor mint if it is read as a global cap. Two implementors mint different balances and different `totalSupply`.
- Raised by: MiniMax, Grok. Astra treated the two sections as separately intelligible and did not flag the cross-lock.
- Fix direction: write one genesis figure. `grossShares` is added liquidity minus 1,000. The fee is taken from that gross. The net goes to the route recipient. The floor is a separate mint to `address(0)` and is not a fee mint. Scope "supply grows only by `grossShares`" to the fee mint so the floor sentence survives. Later deposits keep `added liquidity * totalSupply / existing liquidity`, with the fee taken from that gross.

### D2. A donation and a booked opposite token choose different swaps

- Location: B-05, "An underlying donation swaps its own tokens." Donation and compound booking, "Both tokens, from any mix of fees, donation, and an already booked balance: do not swap."
- Requirement: one swap rule for a maintenance call whose combined balance contains both tokens.
- Impact: a donation of token0 while token1 is already booked is a swap under B-05 and a no-swap matched deposit under the booking rule. The equal-ratio case is also unstated.
- Raised by: Astra, Grok. MiniMax's coverage called B-05 consistent and did not treat this interaction as a defect.
- Fix direction: the booking rule governs the combined balance. A donation is one input to that balance, not a second swap policy. State the equal case: if neither token is scarcer under the definition in D5, do not swap.

### D3. `reserves()` has no composition after the sleeve drop

- Location: B-06, "The local reserve term remains the last committed snapshot." Booking section, "`reserves()` does not include the booked remainder or uncollected fees." B-07, `localReserves()` is not restored. PRD FS-OWN-07, read in this pass, still says `reserves()` is the local-plus-deployed amount. That PRD sentence is not the defect. The missing replacement is.
- Requirement: one return value for `reserves()` and `reserveOfToken` after the sleeve is gone.
- Impact: one implementor returns the live position plus a last-committed local balance. Another returns the deployed position only. A busy-vault read then differs.
- Raised by: Astra, MiniMax, Kimi.
- Fix direction: say what the local term contains. If no local balance is in the reserve until a later deploy, say the local term is zero and delete the snapshot sentence. Do not leave "last committed snapshot" without naming the balances in it.

### D4. Booking the held balance can take a staged pretransfer

- Location: booking section, "Book the actual held balance after the deposit" and "A non-atomic pretransfer can be booked too." B-13, a pretransfer uses the unbooked balance up to the caller's maximum, and the rest stays for a later call.
- Requirement: a maintenance call must not turn another caller's staged exchange balance into a booked remainder unless that is an explicit accepted risk, and a declared maximum above the unbooked balance needs one result.
- Impact: one implementor books every token sitting on the vault after `donate` or `compound`, including a balance staged for a later `exchangeIn`. Another leaves that staged balance unbooked, as B-13 requires. Separately, B-13 does not say what happens when the declared maximum is larger than the unbooked balance.
- Raised by: MiniMax for the booking collision. Astra for the shortfall. Grok treated the B-13 lock as consistent and put the 039 defect on the audit table.
- Fix direction: name the balances `donate` and `compound` may book. A staged unbooked balance that a later exchange call has not declared is not booked by maintenance, or the file explicitly accepts that a non-atomic pretransfer can be taken. If the declared maximum exceeds the unbooked balance, use the unbooked balance and do not pull the difference. Do not refund the undeclared remainder.

### D5. "The scarcer token" is not defined

- Location: booking section, "The scarcer token is fully used. Book the excess of the other token."
- Requirement: one comparison, and one result when the two amounts already match.
- Impact: on a pool whose tokens are not 1:1, a raw-balance comparison and a pool-price comparison pick different tokens. The both-in-excess case has no sentence.
- Raised by: MiniMax. Astra raised the related exhaustion-versus-best-effort gap.
- Fix direction: define scarcer from the position ratio at the pool's current price. Do not add an independent price source. If neither token is short of that ratio, do not swap, deposit the matched pair, and book only a real leftover. Say whether "fully used" means the match targets exact exhaustion or the best-effort deposit may still book dust of the scarcer token.

### D6. N-03 and the matrix drop swaps the locks keep

- Location: N-03, "B-02 authorizes one maintenance swap" and "FS-OWN-25 still authorizes a pool swap for `exchangeIn` only." Matrix files, "Booked-remainder rows cannot pass here. Unused input is refunded."
- Requirement: a closed note must not forbid a swap a lock keeps, and a matrix adaptation must not drop a booked-remainder row the booking rule requires.
- Impact: one rewriter deletes the donation swap and the booked-remainder swap because N-03 says exchange-in is the only pool swap. Another keeps them. The matrix sentence then drops the rows that would have tested the booking rule, because it treats every remainder as user unused input.
- Raised by: Grok, Kimi. Astra's R10 is the same overgeneralization.
- Fix direction: N-03 closes only the sleeve-adjustment swap. `donate` and `compound` may still swap a one-token combined balance. User unused input is refunded. A maintenance remainder is booked. Those are different rows.

### D7. "No fee cap" can be copied over the 30% clamp

- Location: B-02, "This lock does not add a price check, a tick bound, or a fee cap," and the later "There is no new price check, tick bound, or fee cap." B-01 clamps the usage fee at `3e17`.
- Requirement: the swap sentence must not withdraw the usage-fee clamp.
- Impact: a rewriter who copies the B-02 sentence into the PRD constraints deletes the clamp or leaves two rules.
- Raised by: Grok.
- Fix direction: scope the sentence to the swap. B-02 adds no swap price check, no tick bound, and no pool-fee cap. It does not withdraw the B-01 usage-fee clamp.

### D8. "The owner is `feeTo()`" is not an identity the guard already has

- Location: B-02, "`onlyOwnerOrOperator`" and "The owner is `feeTo()`." Already-locked list, the same pair of sentences.
- Requirement: one authorization rule.
- Impact: `onlyOwnerOrOperator` authorizes the diamond owner or an operator. `feeTo()` is the fee recipient. One implementor leaves the diamond owner alone and mints the fee to `feeTo`. Another sets the diamond owner to the fee collector, or authorizes `feeTo()` in place of the owner. The owner's intent, that the fee recipient may call, is not rejected. The sentence cannot be copied until it says which identity changes, and what happens if `feeTo()` later changes.
- Raised by: Grok only. Astra, MiniMax, and Kimi did not flag it.
- Fix direction: keep the owner's intent. Say whether initialization sets the diamond owner to the current `feeTo()` address, whether `feeTo()` is an additional authorized caller beside the existing owner, and whether a later change of `feeTo()` moves that authority. Do not copy the two sentences as if they already name the same role.

### D9. The share unit is still a choice

- Location: B-10, the paragraph beginning "A scale that makes the stored share balances match `decimals()`." PRD FS-OWN-27, read in this pass: share `decimals()` is 18.
- Requirement: one external share unit.
- Impact: a constant scale cancels in the ratio and does not cancel in `totalSupply`, holder balances, the floor, previews, or a minimum-out. Two implementors can follow B-10 and ship different ERC-20 units. The fate of `decimals() = 18` is unstated.
- Raised by: Astra, Grok, MiniMax, Kimi.
- Fix direction: pick one. Either raw V4 liquidity is the external unit and the optional scale is forbidden, or one stated share-side scale is required and applied to the floor, mints, burns, and previews. Say what `decimals()` returns. Do not leave the scale optional.

### D10. `Compounded()` has a signature and not a predicate

- Location: B-11, emit `Compounded()` when fees are compounded. Booking section, `donate()` also compounds and processes a booked remainder. B-03, the empty call emits nothing.
- Requirement: one emission rule for every maintenance outcome.
- Impact: a donation-only call, a remainder-only `compound()`, and a call that books its whole balance again can emit or not. Indexers will not agree on which PoolManager events were maintenance.
- Raised by: Astra, Grok, MiniMax, Kimi.
- Fix direction: define the condition by outcome. Keep the empty no-event case. Say whether a donation-only deploy, a remainder-only deploy, a mixed deploy, and a best-effort call that deploys nothing each emit the marker.

### D11. The fee is not named on every route that the sentence could reach

- Location: B-01, the fee applies to a one-sided deposit and a bundle deposit, and `previewExchangeIn` and `minAmountOut` use the net shares. FS-OWN-09, read in this pass, maps the bundle preview to `previewExchangeBundleInForSingleOut`. That name is a PRD mapping. It is not a function found in `contracts/` during this pass. FS-OWN-25, read in this pass, says `exchangeIn` supports an underlying-to-underlying swap.
- Requirement: every share-minting preview returns the net, and a route that mints no shares does not take a share fee.
- Impact: one implementor nets only `previewExchangeIn` and leaves the bundle preview gross. Another subtracts a share fee from an underlying-to-underlying quote, where no shares are minted. The confirmed rate-provider consumer calls `previewExchangeIn` and rejects a non-32-byte return. That consumer is D16. It is not itself the fee-scope defect.
- Raised by: MiniMax, Grok.
- Fix direction: name every share preview the fee changes, including `previewExchangeBundleInForSingleOut`. Say the underlying-to-underlying route mints no shares and takes no share fee.

### D12. A quote that cannot finish has two results

- Location: B-06, no view reverts by a vault error, and an unsupported view returns zero. N-04, a quote that cannot finish reverts. N-04 also leaves the pricing engine as a question if the item is reopened.
- Requirement: one result for a preview whose quote cannot finish.
- Impact: one implementor returns zero. Another reverts. A third treats the revert as an EVM out-of-gas and claims B-06 does not cover it.
- Raised by: Astra, Grok, MiniMax. Kimi treated the mechanism choice as not an external rule and treated the revert sentence as the result.
- Fix direction: one sentence for the failed preview. Do not require the owner to pick the V4 quoter versus an analytic planner unless that choice changes the result. The no-new-step-cap rule stays.

### D13. The batch-swap sentence names no operation

- Location: B-02, "this vault cannot be included in a batch swap with other Uniswap V4 pools." The next sentence says that is not a revocation of the borrowed-unlock path or of FS-HOOK-02.
- Requirement: a recorded limitation must name the call it forbids, or say it is a disclosure and not a revert.
- Impact: one implementor reverts when the vault is called inside a multi-pool unlock. Another leaves FS-HOOK-02 in force and treats the sentence as a warning. Both can claim the paragraph.
- Raised by: Astra, Grok.
- Fix direction: name the forbidden call, or say the sentence is a disclosure and adds no revert. Do not leave both readings.

### D14. The package input for WETH is still optional

- Location: N-05, "`PkgInit.wrappedNative` may remain only if it must equal that constant."
- Requirement: one package input ABI.
- Impact: keeping the field changes deployment call data and the binding hash. Removing it does too. Both follow N-05.
- Raised by: Kimi, Grok. Astra treated the storage home as an allowed internal choice and flagged the field only if it remains.
- Fix direction: keep the field and require it to equal the network `WETH` constant, or remove it. The repo that stores the constant can stay an internal choice. There is still no `wrappedNative()` getter.

### D15. The seven-address write is ambiguous, and `StateView` is both stored and not a dependency

- Location: B-07, initialization writes the seven addresses into the Protocol Aware Repo, and "The repo is not given a second per-vault copy." Later, `StateView` is one of the seven stored addresses and "is not the vault's dependency." The Crane directory `lib/crane/contracts/protocols/dexes/uniswap/v4/aware` exists and is empty. That emptiness is a status check, not a defect in the lock.
- Requirement: one runtime source for the seven addresses, and one rule for `StateView`.
- Impact: "second copy" can forbid the instance write the previous sentence requires. One implementor writes the seven addresses into each instance repo. Another reads the package immutables and leaves the repo empty. A third calls `StateView` because it was stored.
- Raised by: Kimi for the second-copy sentence. Grok for `StateView` and the unlisted getters. Astra for the missing public ABI list.
- Fix direction: one per-instance copy in the Protocol Aware Repo, and no second copy in a family repo. Store `StateView` with the other six. This vault does not call it. List the external getters, or say each getter has the component's name and returns the stored value. Do not add a family `poolManager()` or `poolKey()` selector.

### D16. The 64-byte consumer list is still required, and it is not in this file

- Location: B-08, the single PRD pass enumerates the consumers of the old 32-byte return. This lock does not make that list.
- Requirement: the tuple change cannot be copied until the consumers are named.
- Impact: the file is explicit that the list is deferred. That deferral is not a contradiction. It does mean the file is not yet a complete rewrite instruction. A spot check in this pass found `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` returning `(false, 0)` when `data.length != 32`, and hook libraries reverting `RateProviderFailed` on the same check. The full list was not made.
- Raised by: MiniMax, Grok. Astra recorded the migration obligation and did not treat the missing list as a defect inside B-08.
- Fix direction: the PRD pass does not start from this file alone. It starts once the consumer list exists. Do not treat the deferral as permission to change the preview return and leave the consumers for later.

### D17. Stale framing would make the rewrite wait or drop a lock

- Location: the heading "Audit tests that wait on an open decision." The 039 row, "Its expectation waits on attribution." The booking section has no identifier. Already-locked list, "pays the caller's fraction," beside "pays only the principal fraction."
- Requirement: a closed decision must not still say it waits, and a summary must not be wider than the lock.
- Impact: a rewriter waits on 039 after B-13 locked it. A redemption that pays "the caller's fraction" can include booked fees that the withdrawal sentence books and withholds.
- Raised by: Grok, Kimi, MiniMax, Astra's R10.
- Fix direction: retitle the audit section. The 039 expectation is the pretransfer directive, not an open wait. Give the booking section an identifier before the pass copies it. The redemption pays the principal fraction. Collected fees are booked, not paid.

### PRD sentences a rewriter must not leave standing

These were read in this pass. They are the current PRD, not defects in the locks. A pass that edits only the IDs named inside each lock leaves these sentences in force.

| PRD sentence read in this pass | Lock that replaces it |
| --- | --- |
| FS-OWN-07, `reserves()` is the local-plus-deployed amount | D3. The replacement composition is not written. |
| FS-OWN-13, the sleeve is used when deployed liquidity is insufficient | B-02 sleeve drop. |
| FS-OWN-17, wrap before the amount enters the sleeve | B-02 sleeve drop. The WETH-only caller rule stays. |
| FS-OWN-25, `exchangeIn` supports an underlying-to-underlying swap | Not replaced. D11 must say that route takes no share fee. |
| FS-OWN-27, share `decimals()` is 18 | D9. The fate of this sentence is unstated. |
| FS-OWN-30, a redemption pays the caller's fraction of the booked local reserve | Booking section and D17. Principal only. |
| FS-MONEY-01, `unlockCallback` calls `_compound` before deposit and withdrawal | B-02. Those routes do not call `compound()`. |
| FS-MONEY-01, `_withdraw` pays pro-rata idle | Booking section. Principal only. |
| FS-A05, genesis credits only the minted shares and follows FS-MONEY-01 | D1. The netting figure is not one sentence. |
| FS-A09, `previewExchangeOut` reverts | B-06. The preview returns zero. |
| FS-A11, withdrawal includes pro-rata idle, and compound runs before deposit and withdrawal | B-02 and the booking section. |
| FS-A33, borrowed execution uses the same compound as the locked path | B-02. A deposit, a withdrawal, and `exchangeIn` do not call `compound()`. |

This table is not the full invalidation list. It is the set checked before this draft. A complete pass still has to read every PRD sentence the locks touch.

### Not a defect

- A locked owner sentence is not a defect because the PRD still says the old thing.
- The accepted sandwich of an owner or operator maintenance call is not reopened.
- Unbounded swap limits are not reopened.
- B-12 can be copied as written.
- The B-13 lock can be copied. D4 and D17 are the gaps around it, not a reversal of the directive.
- N-01, N-06, and N-07 do not need an owner decision.
- This draft does not choose the share scale, the scarcer-token formula, the `feeTo()` identity, or the failed-quote result. Those are the sentences the file still has to lock.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Donation versus the booking rule | Astra and Grok treat the interaction as a contradiction. MiniMax's coverage called B-05 consistent. | D2 adopts the interaction as a defect. MiniMax's coverage is not recorded as support. |
| Quote engine | MiniMax treats the pricing source as still an implementor choice. Kimi treats the mechanism as not an external rule and treats the revert as the result. | D12 requires one failed-preview result. It does not require the owner to pick the quoter. |
| `feeTo()` identity | Grok alone treats "the owner is `feeTo()`" as not copyable. The other three did not flag it. | D8 adopts the copyability gap. It does not reject the owner's intent, and it does not count the other three as agreement. |
| Genesis cross-lock | MiniMax and Grok treat B-01 and B-10 as different credits. Astra treated the sections as separately intelligible. | D1 adopts the cross-lock. Astra is not recorded as support. |
| B-13 | Grok treats the lock as consistent and puts the defect on the audit table. Astra treats a maximum above the unbooked balance as unspecified. MiniMax treats the booking collision as the defect. | The lock stands. D4 and D17 are the gaps. |

## Evidence gaps

- The full list of 32-byte preview consumers was not made. D16 records a spot check, not that list.
- The PRD invalidation table is the set read in this pass. It is not every sentence in the PRD.
- `previewExchangeBundleInForSingleOut` was confirmed as a PRD mapping in FS-OWN-09. It was not found as a Solidity function under `contracts/`.
- Member claims about `ERC20Repo._mint` and the empty Crane aware directory were re-checked only for the aware directory. The `_mint` path was not re-read in this coordinator pass. N-01 is not adopted as a defect, so that unread path does not carry a finding.
- No member ran the project tests. This draft does not treat that as a missing requirement of a document review.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| B-01 | defect | MiniMax, Grok | D1 and D11. Astra did not flag the cross-lock. |
| B-02 | defect | Grok, Astra | D7, D8, D13. D8 was raised by Grok only. |
| B-03 | consistent | all four | The empty no-event case stands. D10 covers the other branches. |
| B-04 | consistent | all four | No zero-liquidity denominator. |
| B-05 | defect in interaction | Astra, Grok | D2. MiniMax did not treat B-05 as a defect. |
| B-06 | defect | Astra, MiniMax, Kimi, Grok | D3 and D12. |
| B-07 | defect | Kimi, Grok, Astra | D15. |
| B-08 | incomplete for the stated use | MiniMax, Grok | D16. The lock itself is clear. |
| B-09 | consistent | all four | No sleeve fallback. |
| B-10 | defect | all four | D9, and D1 against B-01. |
| B-11 | defect | all four | D10. |
| Booking section | defect | Astra, Grok, MiniMax, Kimi | D2, D3, D4, D5, D17. |
| B-12 | consistent | all four | Copyable. |
| B-13 | lock consistent, surrounding text not | Grok for the lock; Astra and MiniMax for the gaps | D4 and D17. |
| N-01 through N-02, N-06, N-07 | not a defect | all four, with no conflict adopted | N-02 does not repair D1. |
| N-03 | defect | Grok | D6. |
| N-04 | defect on the result only | Astra, Grok, MiniMax | D12. Kimi's mechanism position is preserved. |
| N-05 | defect | Kimi, Grok | D14. |
| Matrix and audit table | defect | Grok, Kimi, MiniMax, Astra | D6 and D17. |
| PRD, as context | not a target | coordinator spot check | The invalidation table is partial. |

## Limits

- Static review of the blockers file. The PRD and the pretransfer directive were context. They were not edited.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- Advisory review of this draft has not happened. Silence is not approval.
- This draft does not authorize implementation and does not authorize the PRD edit.
