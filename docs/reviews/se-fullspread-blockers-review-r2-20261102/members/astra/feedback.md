# Astra advisory feedback

## Identity

- Member: astra
- Profile: review
- Phase: advisory feedback
- Requested role: council-member
- Requested model: `chatgpt-subscription/gpt-6-astra:high`
- Runtime model, provider, reasoning setting, role, and task identity: not exposed
- Peer feedback read: no

## Draft under review

- Draft ID: `draft-se-fullspread-blockers-review-r2-20261102-r1`
- Exact file read: `docs/reviews/se-fullspread-blockers-review-r2-20261102/coordinator/draft.md`
- Fingerprint: not computed
- No hash was computed.

## Disposition

requested-changes

The draft preserves the central conclusion of my initial response: the principal owner choices should stand, but several procedures need clarification before the rewrite can be unambiguous. D1, D2, D3, and D6 correspond to my four findings. Their representation is partly accurate, with the qualifications below. No complete finding of mine is missing, but several load-bearing parts are omitted.

## Corrections by draft section

### D1. The overstated-maximum refund has no order

The balance-snapshot and execution-branch ambiguity is accurately represented, including the 100/60/40 example.

Remove or qualify the additional suggestion that returning the whole available unbooked balance necessarily conflicts with the prohibition on taking another party's tokens. The accepted pretransfer premise does not establish origin-based ownership credit. In the overstated case, the available unbooked balance is smaller than the caller's declared maximum. The relevant ambiguity is when that balance is measured and whether processing occurs, not whether a transfer came from another address. Booked balances and amounts beyond a declaration remain separate exclusions.

**Omitted load-bearing scope:** My finding also requires the chosen branch to be reflected in output, minimum-output handling, and previews, and to have a defined interaction with pretransferred donation's remainder-booking rule and any bundle leg admitting pretransfer. Include those consequences in D1's requirement or fix direction. This does not select either branch.

### D2. Fees collected by a deposit or a share-minting `exchangeIn` have no disposition

The missing deposit-side fee rule is accurately identified. The draft correctly declines to adopt the assertion that the fees simply stay unpaid.

However, the fix direction then lists "leave them unpaid" as a disposition of fees already described as collected. Those are different states. Distinguish a mechanism that prevents realization from a rule assigning tokens after realization. Do not present an unverified ability to leave collected fees unpaid as an established implementation option.

**Omitted load-bearing impact:** My finding specifically concerns applying the retained net-delta and positive-credit refund language to a deposit result containing earlier position fees. D2 lists booking, reinvestment, and leaving fees unbooked, but omits the possibility of crediting or refunding those fees to the depositing caller. Add the need to distinguish user-funded principal, consumed input, refund, and share-credit basis from realized fees. That accounting boundary, not merely the eventual location of the fees, was central to my finding.

This correction does not choose a fee disposition or change the liquidity-only issuance formula.

### D3. "Book the excess" and "book the actual held balance" are two assignments

D3 captures my concern about exact exhaustion versus actual residual booking, but broadens it into a different claim.

My initial response treated actual held balance, rather than calculated leftover, as an explicit lock. It did not treat calculated excess as an equally authorized booking basis. Reframe the issue around whether the scarcer-token exhaustion sentence is an exact postcondition or a sizing objective compatible with the permitted operation's actual residuals.

Likewise, replacement versus increment is not necessarily an unresolved product choice. Different implementations can update storage differently while producing the same required booked total. A naive increment that double-counts the old booking is not an alternative economic interpretation to preserve. If a distinct timing or accounting-state ambiguity is intended, identify that ambiguity rather than reopening the actual-balance basis.

**Omitted load-bearing case:** Restore the zero-added-liquidity outcome from my finding. The unresolved distinction was between retaining and booking the inputs without an addition and attempting a zero-liquidity action, alongside the treatment of a failed step. D6's zero-liquidity event case does not specify D3's execution outcome.

Keep the constraints against extra attempts, swallowed failures, and a new swap for an already two-token maintenance balance. I am not choosing the integer-boundary procedure.

### D6. `Compounded()` has a signature and not a predicate, and its amount rationale is false

The event-predicate part accurately preserves my finding. It includes historically booked fees, donation-only deployment, mixed balances, and zero liquidity added.

Separate the provenance of the two claims. Astra raised the predicate issue and explicitly did not independently verify PoolManager event fields. The event-amount claim is additional evidence attributed in the draft to the coordinator's source reading; it should not be presented as a source-verified Astra finding merely because both claims share one "Raised by" line.

I have not independently checked that additional source claim in this advisory pass. This is a provenance correction, not a request to restore the amount rationale or add event fields.

### D7. The seven-address write is still ambiguous, and the Crane getters fight an absence row

Distinguish the proposed storage-wording clarification from the selector migration.

The draft's own rule says a later owner lock is not defective merely because the PRD retains an older sentence. B-07's callable Crane getters versus an older absence row is therefore a required rewrite update, not by itself a new unresolved owner decision. Retain the reminder to update the selector manifest and acceptance row, but do not count the old PRD conflict as independent evidence that the locked selector policy is undecided.

I did not identify the second-copy wording as a defect in my initial response. It is another member's concern, not an omitted Astra finding. My position remains that duplicate family storage should not be invented from that wording.

### D10. `feeTo()` initialization does not say what happens later, or when it is zero

Separate the zero-address boundary question from the asserted equivalence between initialization and a live oracle read.

The quoted instruction names setting the owner at initialization. A continuously oracle-derived authority is not automatically an equally supported reading of that instruction. If the draft asserts a missing later ownership-transition requirement, identify that requirement rather than treating live synchronization as already implied by the lock.

Also qualify the assertion that a zero stored owner necessarily makes both functions unreachable. The policy expressly includes operators, and this advisory has no source evidence about operator initialization or management. The draft can describe the potential reachability problem without claiming that all authorized paths have been proved unavailable.

These are limits on the finding's evidence and wording. I do not select zero-address behavior, a substitute owner, or any later authority-transition policy.

### D12 and Coverage adopted from responses

D12 correctly records my position that consumer enumeration is work of the comprehensive pass, not a prerequisite to starting that pass. Align the coverage table's B-08 status with that distinction. "Incomplete for the stated use" under a defect-oriented table can make the deliberately deferred inventory look like a defect in the owner lock.

The coverage table also omits B-04 and N-01, N-02, N-03, N-06, and N-07. My original response covered them. Add their settled status or explicitly make this a selected-findings table with a clear reference to the full member coverage. In particular, omission must not make the closed zero-liquidity denominator or liquidity-only issuance question look unreviewed or open.

## Accuracy and omitted findings

| Initial Astra finding | Draft section | Assessment |
| --- | --- | --- |
| R2-A01: overstated-maximum branch | D1 | Core accurate; remove the origin-attribution implication and restore preview/minimum and donation/bundle scope. |
| R2-A02: deposit-side realized fees | D2 | Core accurate; restore the user-credit/refund accounting consequence and distinguish unrealized fees from already collected tokens. |
| R2-A03: integer exhaustion and booking | D3 | Partly accurate; actual-balance booking was already treated as locked. The zero-added-liquidity execution outcome is omitted. |
| R2-A04: historical and mixed-fee event predicate | D6 | Accurately preserved. Event-field verification is additional coordinator evidence, not an Astra-verified claim. |

There is no omitted fifth Astra finding. The omitted load-bearing parts are identified by section above.

## Other findings and limits

D4, D5, D8, and D9 are additional concerns from other members. Their presence in the synthesis is not evidence that I independently raised or verified them. D5 appropriately records its single-member origin. D11 can remain a terminology clarification without implying a new economic choice.

I read only the exact draft named above in this advisory pass. Comparison with my initial response uses this conversation's existing context, not a reopened file. I did not read peer feedback, the earlier review directory, source code, the blockers file, the PRD, or any alternative draft. I did not launch sub-agents or run Forge, tests, installs, Git, network research, or hash commands.

Only `docs/reviews/se-fullspread-blockers-review-r2-20261102/members/astra/feedback.md` was written. The open product questions remain unanswered here. This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
