# Identity

- Run ID: apex-012-deposit-process-20261024
- Member label: astra
- Phase: advisory feedback
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/astra/feedback.md

# Draft reviewed

- Draft ID: draft-apex-012-deposit-process-20261024-r1
- Path: `docs/reviews/apex-012-deposit-process-20261024/coordinator/draft.md`

# Disposition

requested-changes

The Astra bullet captures my central proportional-addition argument, but the surrounding synthesis misstates the scope of the owner correction and omits qualifications material to my conclusion. I do not select an owner option.

# Concerns

1. **Do not turn the correction into a blanket rejection of a future entry swap.** The sentence "The owner has now rejected the entry swap those sentences were written to require" goes beyond the supplied correction. The owner rejected the premise that the existing deposit sells target and made the existing process the reference unless a preserved-ruling violation is demonstrated. The assignment expressly allowed a proposed swap after naming such a violation. Likewise, option 3's "despite the correction" wrongly implies that my conditional proposal disregards the correction. Separate the factual correction from the unresolved future design.

2. **My finding relies on explicit proportional addition, not merely on ownership of other token.** My initial response identifies PRD:24 as the decisive rule: deposits must add liquidity proportionally to existing positions and must not open a range. Fungible ownership alone does not prove a defect; every share can own the same fraction of a book even when contributions differ. The synthesis should preserve this distinction from the separate no-gift argument. My conclusion is conditional on PRD:24 remaining binding, and my response states that withdrawing it changes the contract.

3. **My smallest structural correction is not just a swap.** Existing placement independently maximizes affordable additions slot by slot, and deposit-triggered harvest can close and replace ranges. My proposal replaces that entry-path behavior with proportional additions to fixed existing ranges, accounts for owned idle balances, and mints from actual contributions. It introduces conversion only when the proportional contribution needs other token. Even an entirely target-only book still requires proportional allocation; its absence of other token does not establish that the unchanged greedy sequence is valid. The Astra summary should include these restrictions rather than leave the impression that buying the missing token alone repairs the process.

4. **Carry the limit on replacement validity into the synthesis.** I did not certify an unrestricted swap/add process against every preserved requirement. My response explicitly identifies the unresolved conflict between issuance from actual added liquidity and the temporary-liquidity nonincrease/equality requirements. Better swap execution can increase the funded contribution. The draft currently omits this reservation, making the structural proposal sound more complete than my conclusion. State that restoring proportional placement does not itself prove compliance with those issuance constraints.

5. **Correct the existing operation order.** Under "Agreed," the draft says `_deposit` "mints, credits the gross target." The examined code computes shares, checks the minimum/exact route, credits local target, then calls `_mint`, then `_place`. My initial response specifically distinguishes the calculation from the actual mint. Use that order when describing execution.

The owner options should be presented as possible requirement decisions, not as three already-validated implementations. In particular, neither a stored-counter denominator nor an entry swap alone establishes the proportional-addition invariant. This is a request to preserve the review's scope and uncertainty, not a selection among those options.

# Limits

Reviewed only the named coordinator draft in this advisory pass, against my initial response and the evidence already examined. No peer files read, no new source inspection, no runtime validation, no Forge, and no subagents. No changes to the original response, draft, source code, or peer files.
