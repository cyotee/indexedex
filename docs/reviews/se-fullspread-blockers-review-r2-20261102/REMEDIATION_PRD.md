# Blocker-report review, second pass

## Identity

- Run ID: se-fullspread-blockers-review-r2-20261102
- Profile: review
- Council kind: full
- Question: Is the current `IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?
- Target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`
- Context, not targets: the full-spread PRD, `docs/vaults/PRETRANSFER_DIRECTIVE.md`, and `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- Draft reviewed: `coordinator/draft.md`, ID `draft-se-fullspread-blockers-review-r2-20261102-r1`. That file was not edited after advisory. Fingerprint: not computed.
- Coordinator mode: invoking-agent. The coordinator is not an independent vote.
- Requested members: astra (`chatgpt-subscription/gpt-6-astra:high`), grok (`xai/grok-4.7:xhigh`), minimax (`minimax/MiniMax-M3`), kimi (`kimi-coding/k3.1-pro:high`). All four initial responses and all four advisory responses settled. Runtime identity beyond those requested strings was not exposed.
- Advisory: Kimi supported the draft. Astra, Grok, and MiniMax requested changes to its wording. None rejected the verdict.
- This report does not authorize implementation and does not authorize a PRD edit.

## Verdict

The blocker report is not ready to be the sole instruction for rewriting the PRD.

The large locks agree. The sleeve is gone. The fee comes out of the new shares, including the first deposit, and is clamped at 30%. A pass-through takes no fee. Shares are the raw liquidity number. `decimals()` returns 18 and does not scale them. A both-token donation or compound is a proportional deposit and does not swap. `reserves()` wraps the deployed token reads. The quote is the mathematical result. A locked owner sentence is not a defect because the PRD still says the old thing.

What cannot be copied yet is a set of procedures the locked sentences still leave open, plus PRD sentences the locks replace and do not name. This report names them. It does not choose the procedures.

## What can be copied

- There is no local liquidity sleeve and no sleeve-adjustment swap.
- The usage fee is taken from the shares a deposit mints. On the first deposit those shares, before the fee, are `added liquidity - 1,000`. The floor is separate. A pass-through, including an underlying-to-underlying `exchangeIn`, takes no fee.
- The stored share is the liquidity number. There is no share-side scale. `decimals()` returns 18 and is not an input to the mint.
- A one-token maintenance call may swap. A call that already holds both tokens does not. The deployed position is not swapped.
- A call with no fees, no donation, and no booked remainder returns unchanged and emits nothing. A booked remainder is still processed.
- A borrowed exit uses the open unlock and has no sleeve fallback.
- `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` have no other arguments.
- When a pretransfer maximum is within the unbooked balance, the refund is that maximum minus the amount used, in the provided token. The rest stays.
- Do not invent an unfinished-quote failure or a quoter-versus-planner product choice.

## Findings

Each fix direction is advice. None of it was applied. None of it chooses a procedure.

### F1. The overstated-maximum refund has no order

- Location: B-13, refund the unbooked balance when the maximum is larger. The same words are in `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- Requirement: one amount used, one refund, one recipient, and the same branch in previews and minimums.
- Impact: maximum 100 and unbooked 60 can mean return 60 and do nothing, or use part of the 60 and return what remains. Returning the original 60 after using part of it cannot be funded from that balance. The defect is the missing snapshot and the missing execution branch, not where the tokens came from. The chosen branch also has to cover a pretransferred donation and any bundle leg that admits pretransfer. Copying only the B-13 echo drops the directive's staging sentence and its swap-shape sentence. Those stay in force because B-13 incorporates the directive.
- Raised by: Astra, Grok, Kimi.
- Fix direction: say whether an overstated maximum is processed up to the unbooked balance or returned without processing. Name the snapshot, the recipient, and the preview. Do not pull the shortfall. This report does not choose.

### F2. A liquidity-adding user route has no fee sentence

- Location: B-02, a deposit, a withdrawal, and `exchangeIn` do not call `compound()`. The booking section says a withdrawal's `modifyLiquidity` collects fees and books them. It does not say whether a deposit, a bundle deposit, or a share-minting `exchangeIn` collects fees.
- Requirement: one disposition if those routes collect fees, and one statement if they do not.
- Impact: the file establishes collection on the withdrawal path only. It does not establish it on a deposit. If a deposit's liquidity change does collect earlier position fees, one implementor books them, another nets them into the position, another leaves them unbooked for a later pretransfer, and another credits or refunds them to the depositor. "Does not call `compound()`" is not that sentence. "Leave them unpaid" is a different state from fees already collected and then left unbooked. This report does not treat those as the same option.
- Raised by: Astra, Grok. MiniMax's "stay unpaid in the position" is not adopted as the answer.
- Fix direction: say whether a deposit, a bundle deposit, and a share-minting `exchangeIn` collect fees. If they do, name the disposition and keep the user's consumed input, refund, and share credit separate from those fees. This report does not choose.

### F3. The excess sentence can still be copied against the actual-balance sentence

- Location: booking section, the scarcer token is fully used and the excess is booked. The next paragraph books the actual held balance after the deposit.
- Requirement: one booked total after `donate` or `compound`, and one result when the permitted deposit adds no liquidity.
- Impact: the later sentence says to book the actual held balance, not a calculated leftover. Astra treats that as the lock. Grok treats the excess sentence as a second assignment that can still be copied: calculated excess only, replace each balance with the post-deposit balance, or increment and double-count. A naive increment is not a second economic rule if the required total is the actual balance. It is still a sentence a rewriter can copy. Separately, the file does not say what happens when the one permitted deposit adds no liquidity: book the inputs, or attempt a zero-liquidity action. Exact exhaustion can be read as a required result or as a sizing target. Astra raised that execution question. Grok did not.
- Raised by: Grok for the two assignments. Astra for exhaustion and zero added liquidity.
- Fix direction: say the later sentence governs the booked total, or say the excess sentence is the total. Say the zero-liquidity outcome. Keep no extra attempt and no swallowed failure. This report does not choose.

### F4. "Position ratio" is not one figure

- Location: booking section, the scarcer token is the proportionally smaller amount relative to the position ratio.
- Requirement: one ratio.
- Impact: pool price, current position amounts, and those amounts plus unpaid fees can pick different scarcer tokens. The sentence does not say the figure is the pool ratio used for a one-sided deposit.
- Raised by: Grok. Not Grok for the swap size.
- Fix direction: name the ratio. This report does not choose it.

### F5. The one-token swap size is not named

- Location: booking section, swap toward the position's ratio, as a one-sided user deposit does. PRD FS-OWN-33, read in the initial member pass and not re-read in finalization, says a one-sided share mint swaps about half of the excess. The blockers file does not replace that sentence.
- Requirement: one swap size, and one statement of whether "about half" survives.
- Impact: an exact-ratio swap and "about half of the excess" deposit different liquidity and leave different remainders. The rule that the remainder must be in the processed token has no rounding sentence.
- Raised by: MiniMax. Grok excluded this as a defect.
- Fix direction: name the amount swapped, and say whether FS-OWN-33 survives for user deposits, for maintenance, or for both. This report does not choose.

### F6. A one-token exit forbids a shortfall revert and names no residual

- Location: B-02, the withdrawn net is the principal fraction. The already-locked list says the redemption has no leftover shortfall revert.
- Requirement: if the swap does not convert all of the unwanted principal, one disposition.
- Impact: the no-revert sentence was written for the sleeve shortfall. Copied without that scope, it deletes every shortfall revert. The unconverted token can then be paid, booked, or left.
- Raised by: Grok only. The other three did not flag it.
- Fix direction: scope the no-revert sentence to the sleeve case, or name the residual. This report does not choose.

### F7. `Compounded()` has no predicate, and its amount rationale is false

- Location: B-11, emit when fees are compounded into the reserve, and amounts come from the PoolManager events. `donate()` also compounds.
- Requirement: one emission rule, and a rationale that is true.
- Impact: a later `compound()` of fees booked on an earlier withdrawal can emit or not. `donate()` can emit when it redeploys fees, or only `compound()` can emit. The no-argument signature stays. The amount rationale does not. `IPoolManager.ModifyLiquidity`, read in finalization, carries the liquidity delta and no token amounts. A both-token compound does not swap, so no `Swap` event carries those amounts either. Astra raised the predicate and did not verify the event fields. The event-field check is coordinator evidence.
- Raised by: Astra for the predicate. MiniMax for the amount rationale and the unnamed donation event.
- Fix direction: define the predicate for previously booked fees, a donation-only deploy, a mixed balance, and zero liquidity added. Replace the amount rationale. Do not add fields. This report does not choose the predicate and does not name a donation event.

### F8. The seven-address write is ambiguous

- Location: B-07, initialization writes the seven addresses into the Protocol Aware Repo, and the repo is not given a second per-vault copy.
- Requirement: one storage write.
- Impact: "second copy" can forbid the instance write the previous sentence requires, or forbid only a duplicate somewhere else.
- Raised by: Kimi.
- Fix direction: say the canonical write and what "second" refers to. This report does not choose a second storage home.

### F9. The Crane getters must replace an absence row, and that row is not cited

- Location: B-07, the Crane getters are callable, and a family-only `poolManager()` or `poolKey()` is not added. MiniMax cites PRD FS-A01 as asserting those selectors are absent. That absence clause was not in the slice re-read in finalization. It remains member-supplied.
- Requirement: the rewrite must restate the selector row so it matches the lock.
- Impact: the locked policy is that the Crane pairs serve the getters. An old absence assertion, if copied unchanged, fails that lock. That is a rewrite update, not evidence that the selector policy is undecided.
- Raised by: MiniMax.
- Fix direction: cite the absence row and replace it with the Crane-pair sentence already in B-07.

### F10. `donate` has a pretransfer rule and no signature that carries it

- Location: booking section, `donate()` uses tokens already transferred when `pretransferred` is set. The function review, read in the initial coordinator pass, says `donate(token, amount)` stays, with no flag.
- Requirement: one `donate` signature.
- Impact: one implementor adds the flag and changes the selector. Another keeps `donate(token, amount)` and has no input for the rule.
- Raised by: MiniMax only.
- Fix direction: name the signature, or say the flag is on the shared interface and does not change the family selector. This report does not choose.

### F11. The batch-swap sentence is not scoped

- Location: B-02, this vault can be included in a batch swap, and that is not a revert. PRD FS-A22, read in finalization, says `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked.
- Requirement: the owner's sentence must name the routes it covers.
- Impact: the owner removed the exclusion. That sentence is not rejected. Copied as written, it can reopen FS-A22 for bundle, donate, and compound, or apply only to `exchangeIn`. Grok did not file this finding and is not recorded as closing it.
- Raised by: MiniMax only.
- Fix direction: name the routes that may proceed inside a batch swap, and name the routes that still revert. This report does not choose and does not restore the exclusion.

### F12. Initialization sets the owner, and two later cases are unstated

- Location: B-02, set the owner at initialization to `feeTo()` from the Vault Fee Oracle.
- Requirement: the instruction is a value written at initialization. It does not say what happens if `feeTo()` later changes, or if it is `address(0)` at initialization.
- Impact: a live read on every call is not an equal reading of that instruction. A zero stored owner may make the owner check fail. The file also authorizes operators. This report does not claim those operator paths were checked, and it does not claim both functions are unreachable.
- Raised by: MiniMax only.
- Fix direction: say whether a later change of `feeTo()` moves the owner, and what the owner is when `feeTo()` is zero. This report does not choose.

### F13. "Deployed reserve" names two quantities

- Location: B-10, the deployed reserve is one raw liquidity number. B-06, `reserves()` wraps the deployed-reserve reads, which are token amounts plus unpaid fees.
- Requirement: two names.
- Impact: a rewriter can make `reserves()` return liquidity instead of token amounts.
- Raised by: MiniMax.
- Fix direction: call the share denominator deployed liquidity. Call the view's amounts deployed token reserves. This is a naming instruction, not a new economic choice.

### F14. The no-compound lock does not name the PRD sentences it removes

- Location: B-02, a deposit, a withdrawal, and `exchangeIn` do not call `compound()`. Its PRD line does not name the sentences below.
- Requirement: a pass that edits only the cited IDs leaves the old sentences in force.
- Impact: these sentences were re-read in finalization. FS-MONEY-01 says `unlockCallback` calls `_compound` before deposit and withdrawal, and `_withdraw` pays pro-rata idle. FS-A11 says withdrawal includes pro-rata idle and compound runs before deposit and withdrawal. FS-A33 says borrowed execution uses the same compound as the locked path. A rewriter who does not replace them ships a PRD that still compounds on the user path.
- Raised by: MiniMax. The other three did not file this list.
- Fix direction: the pass replaces those sentences with the B-02 lock. That is a rewrite instruction. It does not answer F2.

### F15. The 32-byte consumer list is pass work

- Location: B-08, the PRD pass enumerates the consumers. This lock does not make that list.
- Requirement: the tuple change is incomplete until the consumers are named. That naming is work of the comprehensive pass. It is not a gate before the pass starts, and it is not a defect in the hook-scenario lock.
- Impact: two editors can invent different lists and call the rewrite complete. This review did not make the list.
- Raised by: Grok. Astra did not treat the missing list as a defect inside B-08.
- Fix direction: the pass enumerates the consumers. Do not invent the list from this file.

## PRD sentences the pass must not leave standing

These were re-read in finalization unless a row says otherwise. A lock that differs from the PRD is not a defect. A sentence a lock replaces, and does not cite, is a rewrite defect.

| Sentence | Lock that replaces it |
| --- | --- |
| FS-MONEY-01, `unlockCallback` calls `_compound` before deposit and withdrawal | B-02. F14. |
| FS-MONEY-01, `_withdraw` pays pro-rata idle | Booking section. Principal only. F14. |
| FS-A11, pro-rata idle, and compound before deposit and withdrawal | B-02 and the booking section. F14. |
| FS-A33, borrowed execution uses the same compound | B-02. F14. |
| FS-A22, bundle, donate, and compound revert `ManagerAlreadyUnlocked` | F11. The batch-swap sentence does not yet say whether this row survives. |
| FS-OWN-33, about half of the excess | F5. Not replaced. Member-supplied; not re-read in finalization. |
| FS-A01, selectors absent | F9. Member-supplied absence clause; not re-read in finalization. |

This table is not every sentence in the PRD.

## Advisory dissent that remains

| Topic | Positions | Final |
| --- | --- | --- |
| Contradiction versus an underdetermined procedure | MiniMax says no two owner answers name opposite economics. Astra, Grok, and Kimi say several sentences still admit more than one procedure. | Both stand. F1 through F7 are open procedures, not reversals of an owner answer. |
| Deposit-side fees | Astra and Grok leave the disposition open. MiniMax's unpaid answer is not adopted. | F2 does not choose. |
| Booking total | Astra treats the actual-balance sentence as the lock. Grok treats the excess sentence as a second assignment. | F3 preserves both. It does not reverse the later sentence. |
| Exit residual | Grok alone. | F6. The other three are not support. |
| Consumer list | Grok treats the missing list as keeping that clause from being copied. Astra treats it as pass work. | F15. Not a start gate. |

## Coverage

| Item | Result |
| --- | --- |
| B-01 | Copyable |
| B-02 | F2, F6, F11, F12, F14 |
| B-03 | Empty call copyable. Not the source of F3 or F7. |
| B-04 | Copyable. No zero-liquidity denominator. |
| B-05 and booking | F3, F4, F5, F10 |
| B-06 | Wrap copyable. F13 is the name. |
| B-07 | F8 and F9 |
| B-08 | Hook scenarios copyable. F15 is pass work, not a defect in the lock. |
| B-09 | Copyable |
| B-10 | Copyable. F13 is the name. |
| B-11 | Empty signature copyable. F7 is the predicate and the rationale. |
| B-12 | Copyable |
| B-13 | Ordinary case copyable. F1 is the overstated case. |
| N-01, N-02, N-03, N-06, N-07 | Not a defect. N-01's mint-path citation was not re-read in finalization. |
| N-04 | Copyable. No unfinished-quote product case. |
| N-05 | Copyable. Field removed. |
| Audit table | Not re-verified against the full 45-ID council report in this pass. |

## Limits

- Static review. No project tests were run. Agreement is not proof that the locked economics execute.
- The draft was preserved. Changes after advisory are coordinator revisions, not member-approved text.
- The consumer list was not made. FS-A01's absence clause and FS-OWN-33 were not re-read in finalization.
- This report does not edit the blockers file or the PRD.
- This report does not authorize implementation.
