# Member feedback

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: astra
- Phase: advisory review
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/astra/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, and session ID: not exposed
- Task ID: st_01a17d23
- Fresh or continued: continued
- Initial response path: members/astra/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: sha256 b0a2c24b31c1ce1cb88e51306c5074631627f141b4839aacc44c363a36b29447
- Fingerprint independently computed: not computed
- Draft bytes opened: yes; read the complete text at the assigned path. Its draft ID and path match the assignment. Byte identity against the supplied fingerprint was not independently verified.

The draft contains a different fingerprint explicitly labeled pre-insertion. I did not treat that earlier fingerprint as the frozen-file fingerprint, run a hash command, or open RUN.md. This review concerns only the assigned [draft](../../coordinator/draft.md).

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

**The failed either-token grade fairly records my finding.** Finding 1 correctly distinguishes a general deposit of either currency from the exceptional case where the position already needs only the supplied currency. Its proposed separate route also preserves minting from liquidity actually received. The recorded disagreement does not obscure the adopted conclusion.

**The partial fee grade is not my grade.** The draft accurately attributes my original grade as met and preserves that attribution in its disagreement table, so it does not directly misquote me. I disagree with the coordinator's adopted partial grade and its supporting wording. My pass concerned the stated need for a reserve exposed to trading fees, not proof of implemented fee-accounting solvency. The position and separate fee claims meet that specification-level need. Separating historical fee credits from the redeemable share is a disclosed product boundary, not by itself a failure of that need.

**No finding identifies invented Solidity as an observed implementation.** Findings 2 and 4 explicitly acknowledge that the implementation is absent. Finding 3's substituted aggregate formula is introduced as something an implementer might do, not something existing code does. However, it then promotes an unverified implementation concern into a categorical specification failure. That evidentiary overreach needs correction; it should not become a claim that an existing `claimFees` implementation has been shown to revert.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| ASTRA-ADV-01 | Coverage table; Finding 3; Preserved disagreements, fee-exposure row | Adopting partial "because of the uncomputable liability and the side-claim boundary" combines an accounting-feasibility concern with a stronger economic requirement the draft itself says the user did not impose. My met verdict does not endorse an implementation or prove accounting solvency. | Keep fee exposure met at specification level, with code absent, and report the accounting concern separately. If the coordinator retains partial, explicitly identify the additional acceptance criterion and supporting evidence, preserve my dissent, and do not use the side-claim boundary itself as a failure. |
| ASTRA-ADV-02 | Finding 3, "That sum is not a stored total," "uncomputable liability," and the hypothetical substituted formula | A mathematical sum over account claims is not automatically a stored aggregate, but that does not prove it is uncomputable. Efficient on-chain maintenance remains an implementation obligation. Showing that an implementer could substitute an incorrect aggregate formula does not show the specification requires that substitution. The draft does not provide the cited three-holder example or independently verified derivation. | Describe the current evidence as an unresolved efficient-accounting specification/implementation gap, not a proved impossibility or observed claim failure. To retain a stronger finding, include the precise invariant, arithmetic witness, and explanation of why the required rules themselves fail. Label any witness static and any hypothetical substitution as non-required behavior. |
| ASTRA-ADV-03 | Finding 3, Fix direction | "Store the aggregate unsettled liability" does not explain how a fee-index increase updates an exact sum of per-account rounded claims without visiting accounts. Defining remainder from only a stored claim total may also omit unsettled claims included in the original liability definition. The advice therefore risks presenting the unresolved accounting step as its own solution. The suggested disclosure that `getRate` excludes fees is already present in the specification examined during my initial pass. | Request a concrete accounting design that reconciles collected tokens, crystallized claims, unsettled claims, and rounding remainder at each operation, rather than assert that storing a total alone fixes it. Acknowledge the existing quote exclusion instead of presenting it as missing text. |
| ASTRA-ADV-04 | Finding 2, "nothing can be deposited, withdrawn, or quoted today" | The intended subject is this new vault, but the sentence is broader than the scoped repository absence evidence. No runtime or deployment inventory was reviewed. | Say that no identified implementation of this specification supplies these operations, and retain the search-scope limitation. Do not turn repository absence into a claim about all deployed products. |

I support the specification-level withdrawal and quote grades with the stated limits. The missing implementation does not erase their specified behavior, and their specified behavior does not establish working software. I also support retaining the no-implementation coverage finding.

The draft's secondary assertion about V4Quoter and StateView is explicitly listed as not re-read by the coordinator. I have not independently verified it and do not endorse it as an established tool limitation. It is unnecessary to my conclusion that this vault has no identified implementation.

## What was not adopted from others

- Peer responses read: not read. Only their positions and claims as summarized in the assigned draft were visible.
- Peer feedback read: not read.
- Unread members treated as support: no.
- The attributed liability counterexample and quoter claims were not adopted as independently verified evidence. My own initial response remains preserved and is not replaced by this feedback.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- Reviewed only the assigned draft for this advisory pass, using the retained context of my initial review. Did not edit the specification, draft, resolution, final, RUN.md, initial response, or peer files.
- No hash command, project tests, builds, deployments, commits, or implementation work were performed.
