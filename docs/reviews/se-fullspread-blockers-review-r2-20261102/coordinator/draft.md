# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-blockers-review-r2-20261102-r1
- Path: `docs/reviews/se-fullspread-blockers-review-r2-20261102/coordinator/draft.md`
- Run ID: se-fullspread-blockers-review-r2-20261102
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

Is the current `IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?

## Proposed text

The file is closer than the first review, and it is still not ready to be the sole instruction for rewriting the PRD. The large locks agree. The sleeve is gone. The fee is taken from new shares and clamped at 30%. A pass-through takes no fee. Shares are the raw liquidity number, and `decimals()` returns 18 without scaling them. `reserves()` wraps the deployed token reads. The vault can be included in a batch swap. `PkgInit.wrappedNative` is removed. A locked owner sentence is not a defect because the PRD still says the old thing.

The remaining defect is that several locked sentences still admit more than one procedure. A rewriter who copies them will ship two vaults or leave a PRD sentence the lock was meant to replace. This draft does not edit the blockers file or the PRD, and it does not choose the open procedures.

### Consistent enough to copy

- Sleeve dropped. No sleeve-adjustment swap. No `liquidReservePercentageOfVault` target.
- Usage fee taken from the new shares, including genesis `added liquidity - 1,000`. Floor is a separate mint. Pass-through, including underlying-to-underlying `exchangeIn`, takes no fee. Clamp is 30%.
- Share unit is raw liquidity. No share-side scale. `decimals()` returns 18 and is not an input to the mint.
- Both-token donation or compound is a proportional deposit and does not swap. One-token maintenance may swap. The deployed position is not swapped.
- Empty maintenance call returns unchanged and emits nothing. A booked remainder is still processed.
- Borrowed exit uses the open unlock and has no sleeve fallback.
- `PairDeposited` and `PairRedeemed` have only the indexed caller.
- B-13's ordinary case is copyable: within the unbooked balance, refund maximum minus used, in the provided token, and leave the rest. The overstated case is D1.
- The quote is the mathematical result. Do not invent an unfinished-quote failure or a quoter-versus-planner product choice.

### D1. The overstated-maximum refund has no order

- Location: B-13, the sentence that refunds the unbooked balance when the maximum is larger. The same words are in `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- Requirement: one amount used, one refund, and one recipient.
- Impact: maximum 100 and unbooked 60 can mean return 60 and do nothing, or use 40 and return 20. Returning the original 60 after using 40 cannot be funded from that balance. "Do not refund maximum minus used" does not choose between those two. Sending the whole sitting balance to the caller can also take another party's tokens, which fights the sentence that the unbooked remainder is not sent to `msg.sender`.
- Raised by: Astra, Grok, Kimi.
- Fix direction: say whether an overstated maximum is processed up to the unbooked balance or returned without processing. Name the snapshot and the recipient. Do not pull the shortfall. This draft does not choose.

### D2. Fees collected by a deposit or a share-minting `exchangeIn` have no disposition

- Location: B-02, those routes do not call `compound()`. Booking section, a withdrawal's `modifyLiquidity` books collected fees and pays only principal. No matching sentence for a deposit or a share-minting `exchangeIn`.
- Requirement: every liquidity change that collects fees needs one disposition.
- Impact: one implementor books those fees, as a withdrawal does. Another nets them into the position. Another leaves them unbooked, where the next pretransfer can use them. "Does not call `compound()`" is not that sentence.
- Raised by: Astra, Grok. MiniMax's fix direction says the fees stay unpaid in the position. That answer is not adopted.
- Fix direction: one sentence for fees collected while adding liquidity. Book them, redeploy them in that call, or leave them unpaid. This draft does not choose.

### D3. "Book the excess" and "book the actual held balance" are two assignments

- Location: booking section, the scarcer token is fully used and the excess is booked, then the next paragraph books the actual held balance after the deposit.
- Requirement: one assignment of the booked remainder after `donate` or `compound`.
- Impact: one reader books only the calculated excess. Another replaces every token's booked amount with the post-deposit balance, including dust the scarcer-token sentence said was fully used. A third increments, which double-counts a balance that still contains the old booking. Exact exhaustion is also unstated: dust can be a revert or a booked remainder of the one permitted attempt.
- Raised by: Grok, Astra.
- Fix direction: say whether exact exhaustion is a required result or only the sizing target. Say which balances are recorded, and whether the record replaces or increments. Keep no extra attempt and no swallowed failure. This draft does not choose.

### D4. "Position ratio" and the one-token swap size are not one figure

- Location: booking section, swap toward the position's ratio, as a one-sided user deposit does. B-05 uses the same phrase. PRD FS-OWN-33, read in this pass, says a one-sided share mint swaps about half of the excess so the deposit matches the pool ratio. The blockers file does not replace that sentence.
- Requirement: one ratio and one swap size.
- Impact: pool price, current position amounts, and those amounts plus unpaid fees can pick different scarcer tokens. "About half of the excess" and an exact-ratio swap are different sizes. The remainder-in-the-processed-token rule has no rounding sentence that produces it.
- Raised by: Grok, MiniMax.
- Fix direction: name the ratio and the amount swapped. Say whether FS-OWN-33's "about half" survives for user deposits, for maintenance, or for both. This draft does not choose.

### D5. A one-token exit forbids a shortfall revert and names no residual

- Location: B-02, the withdrawn net is the principal fraction. Already-locked list, the redemption pays that fraction and has no leftover shortfall revert. PRD FS-A08, cited by Grok and not re-read in this coordinator pass, is said to pay only the selected token or revert.
- Requirement: if the swap does not convert all of the unwanted principal, one disposition.
- Impact: the no-revert sentence was written for the sleeve shortfall. Copied without that scope, it deletes every shortfall revert. The unconverted token can then be paid, booked, or left. Those are different movements.
- Raised by: Grok only. The other three did not flag it.
- Fix direction: scope the no-revert sentence to the sleeve case, or name the residual. This draft does not choose, and it does not count the other three as agreement.

### D6. `Compounded()` has a signature and not a predicate, and its amount rationale is false

- Location: B-11, emit when fees are compounded into the reserve, and amounts come from the PoolManager events. `donate()` also compounds.
- Requirement: one emission rule, and a rationale that is true.
- Impact: a later `compound()` of fees booked on an earlier withdrawal can emit or not. `donate()` can emit when it redeploys fees, or only `compound()` can emit. The no-argument signature stays. The amount rationale does not. `IPoolManager.ModifyLiquidity`, read in this pass, carries the liquidity delta and no token amounts. A both-token compound does not swap, so no `Swap` event carries those amounts either.
- Raised by: Astra, MiniMax.
- Fix direction: define the predicate for previously booked fees, a donation-only deploy, a mixed balance, and zero liquidity added. Replace the amount rationale. Do not add fields. This draft does not choose the predicate and does not name a donation event.

### D7. The seven-address write is still ambiguous, and the Crane getters fight an absence row

- Location: B-07, initialization writes the seven addresses into the Protocol Aware Repo, and the repo is not given a second per-vault copy. The Crane getters are callable. Do not add a family-only `poolManager()` or `poolKey()`. PRD FS-A01, cited by MiniMax, asserts those selectors are absent. That absence sentence was not re-read in this coordinator pass.
- Requirement: one storage write, and one statement of which selectors exist.
- Impact: "second copy" can forbid the instance write the previous sentence requires. An implementor who follows the absence row fails a test that B-07 requires to pass.
- Raised by: Kimi for the second copy. MiniMax for the selector row.
- Fix direction: say the canonical write, and say the selectors are served by the Crane pairs. What is absent is a full-spread-only implementation. This draft does not choose a second storage home.

### D8. `donate` has a pretransfer rule and no signature that carries it

- Location: booking section, `donate()` uses tokens already transferred when `pretransferred` is set. The function review, read in this pass, says `donate(token, amount)` stays, with no flag.
- Requirement: one `donate` signature.
- Impact: one implementor adds `pretransferred` and changes the selector. Another keeps `donate(token, amount)` and has no input for the flag the booking rule requires.
- Raised by: MiniMax only.
- Fix direction: name the signature, including where the flag sits, or say the flag is on the shared interface and does not change the family selector. This draft does not choose.

### D9. The batch-swap sentence is not scoped

- Location: B-02, this vault can be included in a batch swap, and that is not a revert. PRD FS-A22, read in this pass, says `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked.
- Requirement: the owner's sentence must name the routes it covers.
- Impact: the owner removed the exclusion. That sentence is not rejected. Copied as written, it can be read as reopening FS-A22 for bundle, donate, and compound, or as applying only to `exchangeIn`. "The earlier exclusion is removed" also depends on a sentence that is no longer in the file.
- Raised by: MiniMax only.
- Fix direction: name the routes that may proceed inside a batch swap, and name the routes that still revert. This draft does not choose, and it does not restore the exclusion.

### D10. `feeTo()` initialization does not say what happens later, or when it is zero

- Location: B-02, set the owner at initialization to `feeTo()` from the Vault Fee Oracle.
- Requirement: one owner value after initialization, including when `feeTo()` is `address(0)`.
- Impact: one implementor stores the address once. Another reads the oracle on every call. A zero `feeTo()` makes `compound()` and `donate()` unreachable if the stored owner is zero. An implementor may substitute another address. That is an authority choice.
- Raised by: MiniMax only. A coordinator reading in the previous turn, that a later change does not move the owner, is not an owner lock and is not adopted here.
- Fix direction: say whether the owner is the stored initialization value or a live read, and what happens when `feeTo()` is zero. This draft does not choose.

### D11. "Deployed reserve" names two quantities

- Location: B-10, the deployed reserve is one raw liquidity number. B-06, `reserves()` wraps the deployed-reserve reads, which are token amounts plus unpaid fees.
- Requirement: two names.
- Impact: a rewriter can make `reserves()` return liquidity instead of token amounts.
- Raised by: MiniMax.
- Fix direction: call the share denominator deployed liquidity. Call the view's amounts deployed token reserves. This is a naming instruction, not a new economic choice.

### D12. The 32-byte consumer list is still pass work

- Location: B-08, the PRD pass enumerates the consumers. This lock does not make that list.
- Requirement: the tuple change is incomplete until the consumers are named. That naming is work of the comprehensive pass. It is not a gate before the pass starts.
- Impact: two editors can invent different lists and call the rewrite complete. The file does not contain the list. This review did not make it.
- Raised by: Grok. Astra recorded the migration obligation and did not treat the missing list as a defect inside B-08.
- Fix direction: the pass enumerates the consumers. Do not invent the list from this file.

### Not a defect

- A locked owner sentence is not a defect because the PRD still says the old thing.
- MiniMax found no pair of owner answers that name opposite economics. That is preserved. It does not close D1 through D6. Those sentences admit more than one procedure.
- The unfinished-quote case stays rejected. The share unit stays raw liquidity. The pass-through fee exclusion stays. The `wrappedNative` removal stays.
- This draft does not choose the refund order, the deposit-fee disposition, the booking assignment, the ratio, the exit residual, the event predicate, the `donate` signature, the batch-swap routes, or the later `feeTo()` rule.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Internal contradiction versus underdetermined procedure | MiniMax says no two locked owner sentences contradict. Astra, Grok, and Kimi say several sentences still admit more than one procedure. | Both can be true. D1 through D6 are underdetermined procedures, not reversals of an owner answer. |
| Deposit-side fees | Astra and Grok leave the disposition open. MiniMax's fix says the fees stay unpaid in the position. | D2 does not adopt the unpaid answer. |
| Exit residual | Grok alone treats the no-shortfall-revert sentence as unscoped. | D5 adopts the copyability gap. The other three are not recorded as support. |
| Consumer list | Grok treats the missing list as keeping the file from being a sole rewrite source. Astra did not treat it as a defect inside B-08. | D12 keeps it as pass work, not a start gate. |

## Evidence gaps

- The consumer list was not made.
- FS-A01's absence sentence and FS-A08 were not re-read in this coordinator pass. They are member-supplied where cited.
- `ModifyLiquidity` and FS-A22 were re-read. The function-review `donate(token, amount)` sentence was re-read.
- No member ran the project tests. This draft does not treat that as a missing requirement of a document review.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| B-01 | consistent | all four | Pass-through exclusion stands. |
| B-02 | defect | Astra, Grok, MiniMax | D2, D5, D9, D10. |
| B-03 | consistent on the empty call | Astra | D3 and D6 cover the remainder boundary. |
| B-05 and booking | defect | Astra, Grok, MiniMax | D3, D4, D8. |
| B-06 | naming defect | MiniMax | D11. The wrap itself stands. |
| B-07 | defect | Kimi, MiniMax | D7. |
| B-08 | incomplete for the stated use | Grok | D12. The hook scenarios stand. |
| B-09 | consistent | all four | No sleeve fallback. |
| B-10 | consistent | all four | Raw liquidity. D11 is the name. |
| B-11 | defect | Astra, MiniMax | D6. The empty signature stands. |
| B-12 | consistent | all four | Copyable. |
| B-13 | ordinary case consistent, overstated case not | Astra, Grok, Kimi | D1. |
| N-04 | consistent with the owner's rejection | all four | No unfinished-quote product case. |
| N-05 | consistent | all four | Field removed. |

## Limits

- Static review of the current blockers file. The PRD, the directive, and the function review were context. They were not edited.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- Advisory review of this draft has not happened. Silence is not approval.
- This draft does not authorize implementation and does not authorize the PRD edit.
