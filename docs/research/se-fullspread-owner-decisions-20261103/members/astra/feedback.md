# Astra advisory feedback

## Identity

- Member: astra.
- Profile: research.
- Phase: advisory feedback.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime role, model, reasoning setting, and provider/account route: not exposed.
- Context: continuation of this Astra conversation.
- Peer feedback read: no.

## Draft under review

- Draft ID: `draft-se-fullspread-owner-decisions-20261103-r1`.
- Exact file read: `docs/research/se-fullspread-owner-decisions-20261103/coordinator/draft.md`.
- Fingerprint: not computed. No hash was computed.
- The complete named draft was readable. No other file was read during this advisory pass.

## Disposition

requested-changes

The draft preserves much of my assessment, including the principal F1, F2, and F6 misunderstandings, F7's mixed-balance ambiguity, and my conclusion that F12 is an explicit policy change. It does not state my contribution fully accurately: F5's accepted-sentence defect is excluded using a narrower test than the assignment supplied; my F2 changed-recommendation classification is omitted; and F12 omits the internal operator-setter guard that made my implementation caveat concrete. Several synthesized questions also introduce alternatives the owner did not actually leave open.

## Concerns and corrections by draft section

### Proposed text / F1. Overstated maximum

The distinction between a declaration exceeding the caller's own transfer and one exceeding the aggregate unbooked balance accurately preserves my proposal. The final missing-fact question then blurs that distinction again.

If “another sitting balance” is unbooked input of the same token, it is already part of the aggregate used for the comparison. If it instead means booked holder backing, the draft introduces a different source of funds without evidence that the owner authorized using it. “Refund the total or get credit for another sitting balance” is therefore not the precise unresolved choice.

Correction: retain the missing fact from my contribution: whether an excess maximum makes the entire call refund-only before any leg is processed, including a mixed bundle. Do not portray the owner as having replaced the existing refund/no-shortfall-pull lock merely by accepting non-atomic staging risk.

### Proposed text / F2; Preserved disagreements; Coverage

The fee-collection explanation accurately states my substantive concern. The classification does not fully represent my proposal.

I recorded “Changed the recommendation: yes” for the literal “untouched” restatement, while explicitly distinguishing a textual change from an intentional policy change. The draft records “no” and preserves only Kimi's disagreement about the problem classification. That omits my separate classification disagreement.

Correction: either use a consistent definition of “Changed” that includes an incompatible operative restatement, or explicitly preserve my contrary classification as the draft already does for F6. The coordinator may choose another classification, but should not imply that my proposal also recorded “no.”

The missing fact is whether “untouched” means collected and booked but not redeployed. “Or is the fee delta left unaccounted?” introduces a possible implementation failure as though the owner had proposed it. Keep that consequence distinct from the clarification actually needed.

### Proposed text / F5; Preserved disagreements; Coverage

The draft accurately identifies my amount-definition objection but wrongly excludes it from the problem test merely because it originated in the recommendation.

The assignment expressly counts an accepted sentence that is still not copyable as a problem. The owner need not misunderstand the recommendation for that criterion to apply. An unqualified acceptance carries the sentence's unresolved distinction between swap input cost and the processed-token amount consumed by the subsequent add.

Correction: assess that wording defect on its merits under the accepted-sentence criterion. If the coordinator disagrees that it is ambiguous, explain why the two amounts are unambiguous; do not resolve it by narrowing the question to whether the owner added a defect. Preserve my missing fact: which amount the sentence means by “the amount that add requires.”

This is the most consequential mismatch between the draft's assessment method and my proposal.

### Proposed text / F6

The draft accurately preserves my entry-versus-exit distinction and explicitly records the classification disagreement. However, “The 48% figure also conflicts with the F5 acceptance” overstates the owner's tentative algorithm suggestion.

My proposal treated 48% as an idea to investigate, not a fixed algorithm that had been adopted. An unproven percentage cannot establish the required sizing behavior, but merely suggesting it for investigation does not yet replace F5's accepted objective.

Correction: distinguish the incompatible exit-remainder explanation from the tentative numerical suggestion. The missing fact remains whether the remainder discussion belongs only to deposits and maintenance adds, leaving the exit all-convert-or-revert rule intact.

### Proposed text / F7; Preserved disagreements; Coverage

My “Misunderstood: no” assessment is not preserved. I treated the reply as an intelligible, intentional rejection of the recommendation's event predicate. The recommendation did make newly collected fees a condition, even though it also required positive added liquidity. The owner can reject that condition in favor of actual fee deployment without misunderstanding a proposed claim-only mechanism.

Correction: preserve my disagreement with the draft's misunderstanding classification. The required yes/no field should not become “partly” without identifying the exact restatement that fails the assignment's misunderstanding test. If the draft maintains “yes,” distinguish that conclusion from my “no.”

The defensible problem is the unresolved difference between deploying any booked tokens and deploying an identifiable fee-origin amount. The draft's statement that the locked emission sentence “is not replaced on the record” should not become a separate defect merely because the owner did not use a formal replacement formula. The reply openly changes the recommendation and explains the desired deployment trigger. What remains unclear is the scope of that change, because booked balances contain more than fees.

The draft also cites blockers line 242 for the no-fee-compounding emission rule. My original contribution located the relevant fee-only emission text at lines 234-240, while line 242 described the no-input/no-remainder case. That earlier locator is carried from this conversation, not freshly verified here. Correct the attribution rather than equating “no fees” with “no fees, donation, or booked remainder.”

The absence of an existing `Donation()` event does not itself bear on whether the owner may request one. Preserve it only as a limited implementation observation, not as support for a decision defect.

### Proposed text / F12; Preserved disagreements; Coverage

The draft correctly records my no-problem position, but its competing missing facts are not established as ambiguities in the decision actually made.

The owner explicitly selected checks against the currently configured `feeTo()` and requested new ownership modifiers. Keeping the initialized address as a second owner is not an equally faithful execution of that instruction. A former owner might separately remain an authorized operator, but that is a different authority and does not mean stored ownership survives.

Likewise, “integrate the existing Operable repo if possible to implement the global and function level Operator authorizations” makes repository reuse conditional; it does not make the requested operator authorizations optional. The draft's final sentence conflates those two things.

Correction: do not manufacture a dual-owner choice or an optional-operators choice from this wording. If zero-address behavior remains a coordinator concern, explain why the selected current-address check plus operator authorization cannot be applied, rather than treating the absence of a repeated zero-address sentence as sufficient evidence of a problem. Do not choose a new operator-reset policy.

An omitted load-bearing part of my proposal is the guard inside the function-specific operator setter. My original response cited `lib/crane/contracts/access/operable/OperableRepo.sol:103-108`: replacing an outer modifier alone would still leave a stored-owner check inside that setter. The draft carries only the combined owner-or-operator guard. Restore the internal-setter caveat to explain precisely why unchanged reuse is insufficient while the requested integration remains feasible. This is an implementation constraint, not proof that the owner's decision cannot be performed.

### Proposed text / F3-F4, F8-F11, F13 through F15

These sections accurately preserve my substantive dispositions. In particular, F10 correctly keeps the F1 execution dependency separate from the signature decision, and F11 treats acceptance as adopting the explicitly stated single-output selector assumption. I identify no omitted load-bearing part in these sections.

## What was not adopted from others

I did not read peer responses or feedback in this advisory pass. The only representations of other members' positions considered here are those printed in the named draft.

I do not adopt the draft's exclusion of F5's inherited wording defect from the problem criterion, its suggestion that a tentative 48% algorithm already replaces F5, or its proposed dual-owner and optional-operator readings of F12. The coordinator may retain contrary conclusions, but should preserve the actual disagreements and their reasons.

## Limits

This feedback compares only the named draft with my contribution already present in this conversation. It does not independently revalidate source citations or the draft's claims about other members. No other files, peer feedback, or external sources were read; no hash, Forge command, test, install, Git operation, or sub-agent was used.

Only this assigned feedback file was written. The draft is not an owner lock. This feedback does not authorize implementation, does not authorize a PRD edit, and does not replace the draft.
