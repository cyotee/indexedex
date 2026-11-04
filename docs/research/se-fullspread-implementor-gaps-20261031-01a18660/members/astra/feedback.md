# Identity

Astra, independent council member, research-profile advisory.

# Draft under review

- Draft ID: `se-fullspread-implementor-gaps-20261031-01a18660-r1`.
- Path: `docs/research/se-fullspread-implementor-gaps-20261031-01a18660/coordinator/draft.md`.
- Required SHA-256: `dcd2d1fd76fa2ebb501a074b1aa55b20d70173d494d104c190eec62ec5f9d0d5`.
- Observed raw-file SHA-256: `dcd2d1fd76fa2ebb501a074b1aa55b20d70173d494d104c190eec62ec5f9d0d5`.
- Verification: matched. The complete draft was readable and reviewed.

# Disposition

**Changes requested.** The draft preserves many of my owner questions, but it does not accurately preserve several load-bearing distinctions between unresolved decisions and text already closed by a lock or cited source. It also omits the explicit custody-classification question from my original contribution.

This advisory does not answer any unresolved owner question. It asks the coordinator to correct the representation and scope of the questions, not to select product behavior.

# Accuracy of the questions

## 1. Questions for the owner, question 14; Recommendations that close a gap, third bullet

These do not accurately state my M10 disposition or R10 recommendation.

My contribution classified the accepted one-token exit and inclusion of proportional idle as source-and-lock-closed, rather than asking which selector implements the exit or whether the unselected entitlement may be left behind. The draft introduces the latter as an owner option and then says the exit question still needs answering.

**Correction:** Preserve my original classification and rationale explicitly. If another contribution disputes that closure, record the disagreement as a disagreement about whether existing requirements settle it. Do not present the draft's new exit question as my question or silently replace my closing recommendation with it.

The remaining sleeve and custody questions must be distinguished from reopening the already-specified exit behavior.

## 2. Questions for the owner, question 5

The option to retain the target and reduce the payout is not a faithful restatement of my sleeve-shortfall questions. My original Q3b asked whether an operation reverts or may complete below target. It did not propose changing the withdrawal entitlement as the way to preserve the target.

**Correction:** Remove the implication that my sleeve question authorizes a reduced entitlement. Keep sleeve maintenance, operation success or rejection, and the specified withdrawal calculation distinct. If a contributor proposed changing the entitlement, attribute it separately and identify that it would require a product change rather than clarification of my question.

## 3. Not a current gap, second paragraph; Questions for the owner, question 12

These replace my reserve-view concern with a different premise.

My A2 and R12 identified a conflict between the current-price reserve lock and a last-operation token-amount snapshot. The draft instead says the remaining issue is when the snapshot is written and repeats that premise in question 12. That assumes the storage behavior whose compatibility my contribution disputed.

**Correction:** Restore the distinction between:

- the current-value versus stale-snapshot conflict, which I treated as closed by owner-lock precedence; and
- the unresolved exact set of views that must reject while the operation guard is held.

Do not substitute a snapshot-write-timing question for either. My busy-view question named `reserves`, `reserveOfToken`, `localReserves`, `positionLiquidity`, and the accepted previews; preserve that concrete scope.

## 4. Questions for the owner, question 1

The phrase "the PRD forbids ... a holder address" overstates the sentence examined in M1. The PRD says the update does not pick a holder address. My contribution therefore asked the owner to establish the ERC-20 representation, including its balance and mint-event consequences, without selecting a holder.

**Correction:** Say that no holder or representation has been selected, rather than describing a categorical owner prohibition against a holder. Preserve balance representation and mint-event behavior in the question. Do not name a holder or choose a representation.

## 5. Questions for the owner, question 7

"Which already-named repo stores `wrappedNative`" is narrower than my Q5. I asked for the authoritative runtime source, which the examined text had not resolved between repository state and an immutable binding.

**Correction:** Ask which repository or immutable binding is authoritative, without presupposing that a repository must be selected. The initialization-step question can remain, but it must follow the selected authority rather than choose it implicitly.

## 6. Questions for the owner, question 10

This does not preserve my M7 disposition. I treated the named function-inclusion decisions as closed, while separately identifying incomplete package bindings and the component set.

**Correction:** Distinguish any unresolved binding or placement contract from the already-recorded keep/drop decisions. Do not state that I asked the owner to choose the remaining query selector set afresh. If another member regards an aspect of the reusable position surface as unresolved, identify that narrower issue separately.

## 7. Questions for the owner, question 16; Recommendations that close a gap, second bullet

The draft both asks whether idle means source counters or actual balances and recommends source counters. More importantly, neither formulation fully preserves my A1/Q11 custody question.

My contribution did not choose which funds become eligible accounted backing or enter adapted idle accounting. It explicitly kept that decision separate from using the source's withdrawal calculation. A recommendation about the source counters cannot decide which donated, unbooked, reserved, or pretransferred funds belong in those counters or in the sleeve calculation.

**Correction:** Separate the source arithmetic from the adaptation's custody classification, and do not present the latter as resolved by the recommendation. Preserve any contributor disagreement about counter usage without treating it as an answer to my omitted question.

## 8. Questions for the owner, question 9; Preserved disagreements, Raw ETH entry row

Question 9 captures the payout conflict, but it narrows my original Q6, which asked whether raw-user entry or payout remained a requirement beyond internal native PoolManager settlement. That was a question about the scope of the contradictory product requirement, not a request to make an accepted nonpayable route payable.

The disagreement row is also titled "Raw ETH entry" while describing my concern about the actual-ETH-payout sentence. Those are not necessarily opposing positions: accepted routes can remain nonpayable while the PRD's separate scope wording still needs clarification.

**Correction:** Describe the accepted-route boundary and the unresolved raw-user capability requirement separately. Do not attribute advocacy of a new entry selector or a change to the accepted ABI to me. Label the disagreement by the actual proposition disputed.

## 9. Recommendations that close a gap, third bullet

My A10/R20 concern was not only that full unwanted-leg consumption must not become an entry rule. It was also that the preview table describes exit only, despite the accepted scalar preview covering entry.

**Correction:** Retain the missing entry-preview coverage correction explicitly. Do not reduce that recommendation to the `zapTo` issue or attach its closure to the draft's new one-token-exit question.

# Omitted load-bearing questions by draft section

## Questions for the owner: add the custody-classification question

My A1/Q11 is not adequately represented by question 16 or by the donation question:

> Do local reserves and the sleeve-owned-amount calculation include unbooked transfers, pretransfer surplus, and in-flight reserved input, or only accounted vault backing?

This question determines what may be reported as backing and used in sleeve targeting. Stored counters versus actual balances alone does not identify ownership or eligibility. Please preserve it as an explicit unresolved question, without answering it in the recommendations.

## Questions for the owner, question 24: restore the authorized-writer part

The draft asks what existing state disables issuance but omits my Q21's authority component:

> What existing authoritative state and writer govern the "disabled inbound issuance" condition in FS-A38?

Naming a state variable without its controlling authority leaves a consequential behavior choice unresolved. Do not infer a setter or import administration to complete the question.

## Questions for the owner, question 9: preserve the raw-user scope question

As explained above, the original question concerned whether raw-ETH user entry or payout remains required by this revision at all, beyond the already-bound accepted routes and internal native settlement. Restricting the question to whether an accepted route pays ETH omits that scope distinction.

These omissions are not requests for additional features. They are requests to retain the unanswered decisions already identified in my original.

# What the draft represents accurately

The draft substantially preserves my questions about sleeve timing and shortfall, spending sleeve balances without an unlock, manager initialization, additional protocol-component bindings, unknown-token reserve behavior, dual Basic Vault facet bindings, the unnamed inherited validation domain, authorization of any existing fee policy, imbalanced bundle deposits, underlying-to-underlying route support, share decimals, and donation deployment or pre-genesis admission.

It accurately records my position that an other-currency entry credit can be closed from the cited source and accepted refund rule, and that a later rate policy is not a present implementor choice. I am not asking the coordinator to resolve the credit disagreement by a vote.

The draft's additional questions concerning particular source reads, wrapper compatibility, token order, permission to compound, locked-path pretransfer, deadlines, and entry-swap calculation were not all questions from my original. They should not be attributed to me as a group. This limited advisory does not certify their independent necessity or answer them.

# Limits

I reviewed only the complete verified frozen draft, using the original contribution and admitted evidence already present in this session's context. I did not reopen the PRD, review file, source contracts, accepted reports, or peer responses. I did not perform new product research.

The only file written for this advisory is `docs/research/se-fullspread-implementor-gaps-20261031-01a18660/members/astra/feedback.md`. No owner question was answered, no original was replaced, and no implementation or PRD edit is authorized. This advisory neither replaces the draft nor requires another review round.
