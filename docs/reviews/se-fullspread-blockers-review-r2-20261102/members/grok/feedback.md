# Advisory feedback

## Identity

- Run ID: se-fullspread-blockers-review-r2-20261102
- Member label: grok
- Profile: review
- Phase: advisory feedback
- Owned path: `docs/reviews/se-fullspread-blockers-review-r2-20261102/members/grok/feedback.md`
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Peers read before this feedback: no

## Draft under review

- Draft ID: draft-se-fullspread-blockers-review-r2-20261102-r1
- Path: `docs/reviews/se-fullspread-blockers-review-r2-20261102/coordinator/draft.md`
- Fingerprint: not computed. This pass did not compute a hash.
- The named file opened. This is not an unable-to-review.

## Disposition

requested-changes

The draft's answer matches mine: the file is not ready to be the sole instruction for rewriting the PRD, and the remaining defect is locked sentences that still admit more than one procedure. D1, D2's impact, D3's assignment fork, D4's ratio fork, D5, and D12 state findings I made. The draft does not choose the open procedures. That refusal is right. I do not choose them either.

The changes are attribution and wording. They are not product answers. D4's requirement and fix direction record a swap-size question I said was not a defect. D2's fix direction replaces my third procedure with a different one. The coverage table can be read as if I raised findings I did not raise.

## Whether the draft states my findings

Yes, for the findings I made, with the corrections below. No load-bearing finding I made is missing.

| My finding | Draft section | Stated accurately |
| --- | --- | --- |
| Overstated pretransfer maximum has no single refund | D1 | Yes, on the two procedures and the `msg.sender` collision. One copy hazard is not recorded. |
| Deposit and share-minting `exchangeIn` leave collected fees unspecified | D2 | The impact is accurate. The fix direction is not. |
| Booking records either the excess or the held balance | D3 | The assignment fork is accurate. Exact exhaustion is not my finding. |
| Scarce token has no position-ratio formula | D4 | The ratio fork is accurate. The swap-size fork is not my finding. |
| One-token exit forbids a shortfall revert and names no residual | D5 | Yes. |
| Preview consumers are required and not listed | D12 | Yes. |

## Corrections

### Proposed text

No change to the answer. I did not read the earlier review, so I do not adopt or dispute "closer than the first review."

The opening states the batch-swap sentence as a lock that can be copied, and D9 says that sentence is not scoped. I did not file D9. Do not read the opening as my closure of D9.

### D1. The overstated-maximum refund has no order

Accurate on the point that matters. Maximum above the unbooked balance can mean return the sitting balance and do nothing, or use part of it and refund only what remains. Refunding the original sitting balance after a nonzero use cannot be funded from that balance. Sending the whole sitting balance to the caller can take another party's tokens, which fights the sentence that the unbooked remainder is not sent to `msg.sender`. I do not choose which procedure.

Not recorded, and not a separate finding: B-13's echo drops the directive's within-case staging sentence and its swap-shape sentence. Those stay in force only because B-13 incorporates the directive. Copying only the echo loses them. Add that copy hazard to D1 if the final restates the finding. Do not treat it as a seventh procedure, and do not answer it here.

### D2. Fees collected by a deposit or a share-minting `exchangeIn` have no disposition

The impact states my finding. One implementor books the fees, as a withdrawal does. Another nets them into the position. Another leaves them unbooked, where the next pretransfer can use them. "Does not call `compound()`" is not that sentence. I do not choose among those three.

Change the fix direction. "Leave them unpaid" is not my third procedure. Unpaid fees are already the deployed-read case. My third procedure is fees collected by the liquidity change and then left unbooked. The draft says MiniMax's "stay unpaid in the position" is not adopted. The fix direction should not put that unadopted answer back under the name "unpaid."

The location line names a deposit and a share-minting `exchangeIn`. My finding also named a bundle deposit, because that route adds liquidity too. The fix direction's "while adding liquidity" covers it. Keep that breadth in the location line so a bundle deposit is not dropped.

### D3. "Book the excess" and "book the actual held balance" are two assignments

The assignment fork is mine and is stated accurately: calculated excess only, replace each recorded balance with the post-deposit balance, or increment and double-count. I do not choose the assignment. "Which balances are recorded" covers the non-vault-token question I raised. That question does not need its own section.

Exact exhaustion, dust as a revert or as a booked remainder of the one permitted attempt, is not a finding I made. Do not attribute that clause to me. I do not answer it, and I do not ask that it be deleted if another member raised it.

### D4. "Position ratio" and the one-token swap size are not one figure

Split this section. The ratio fork is my finding and is stated accurately: pool price, current position amounts, and those amounts plus unpaid fees can pick different scarce tokens. The both-token sentence says "position ratio" and does not say that figure is FS-OWN-33's "pool ratio." I do not choose the ratio.

The swap-size fork is not my finding. I wrote that FS-OWN-33's "about half" is a pre-existing PRD phrase the blockers file did not reopen, and that it is not the defect. D4's requirement, "one ratio and one swap size," and the fix direction that asks whether "about half" survives for user deposits, maintenance, or both, record a product question I excluded. The remainder-rounding sentence is not my finding either.

Raised by should not be "Grok, MiniMax" for the whole section. Grok for the scarce-token ratio. Not Grok for "about half," and not Grok for a rounding sentence. I do not answer whether "about half" survives.

### D5. A one-token exit forbids a shortfall revert and names no residual

Accurate. I raised it. The draft is right not to record the other three as support, and right not to choose. Scope the no-revert sentence to the sleeve case, or name the residual. I do not choose which.

### D6. `Compounded()` has a signature and not a predicate, and its amount rationale is false

Not my finding. The draft does not attribute it to me. That is correct. My response treated "emit when fees are compounded into the reserve" as the copyable predicate and did not file the undeployable case. Do not read D6 as a withdrawal of that reading, and do not read this feedback as an answer to the predicate or the amount rationale.

### D7. The seven-address write is still ambiguous, and the Crane getters fight an absence row

Not my finding. The draft does not attribute it to me. I do not answer the storage write or which absence row survives.

### D8. `donate` has a pretransfer rule and no signature that carries it

Not my finding. The draft does not attribute it to me. I do not answer the signature.

### D9. The batch-swap sentence is not scoped

Not my finding. The draft does not attribute it to me. My response adopted a narrower reading and did not file this. I do not withdraw that reading here, and I do not answer which routes the sentence covers.

### D10. `feeTo()` initialization does not say what happens later, or when it is zero

Not my finding. The draft does not attribute it to me. I do not answer whether the owner is stored once, read live, or replaced when `feeTo()` is zero.

### D11. "Deployed reserve" names two quantities

Not my finding. The draft does not attribute it to me. I do not answer the naming instruction.

### D12. The 32-byte consumer list is still pass work

Accurate. I treated the missing list as the reason the file is not a sufficient sole source for that clause, and as an acknowledged deferral rather than a contradiction inside the hook scenarios. "Not a gate before the pass starts" does not contradict me. Do not invent the list. I do not invent it here.

### Coverage adopted from responses

The B-02 row lists D2, D5, D9, and D10 under a row adopted from Astra, Grok, and MiniMax. I raised D2 and D5. I did not raise D9 or D10. The B-05 row lists D3, D4, and D8 under a row adopted from Astra, Grok, and MiniMax. I raised the D3 assignment fork and the D4 ratio fork. I did not raise D8. Change those rows so the final cannot be read as Grok raising D8, D9, or D10.

### Preserved disagreements

The four rows match what I can attest for my own side. I left the deposit-fee disposition open. I alone treated the exit residual as a copyability gap, as far as this draft records, and I did not read the others. I treated the missing consumer list as keeping the file from being a sole rewrite source. I do not attest the other members' positions.

## Omitted load-bearing findings

None. D1, D2, D3, D4, D5, and D12 are the six findings I made. The copy hazard under D1 and the bundle-deposit breadth under D2 are parts of those findings, not omitted findings.

## Open product questions

Not answered. This feedback does not choose the refund order, the deposit-fee disposition, the booking assignment, the ratio, the exit residual, the event predicate, the storage write, the `donate` signature, the batch-swap routes, the later `feeTo()` rule, or the consumer list.

## Limits

- This pass read only `docs/reviews/se-fullspread-blockers-review-r2-20261102/coordinator/draft.md`. The comparison is to the response already submitted in this conversation. This pass did not re-read that file, the blockers file, the PRD, the directive, or the function review.
- Peer feedback was not read. Peer responses were not read.
- Fingerprint: not computed. This pass did not compute a hash.
- No Forge, tests, installs, Git, or sub-agents.
- This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
