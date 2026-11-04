# Member feedback

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: grok
- Phase: advisory review
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: role not exposed; model not exposed; reasoning not exposed; task ID st_01a17d24; session ID not exposed
- Fresh or continued: continued
- Initial response path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/grok/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: b0a2c24b31c1ce1cb88e51306c5074631627f141b4839aacc44c363a36b29447
- Fingerprint independently computed: not computed
- Draft bytes opened: the assigned path, in full. The file's own identity line also records a different pre-insertion sha256, bda9c75f3016fa7b71467e69b193979c759f77a2e148adea5dac8c4b20111114. That value was not recomputed and is not treated as the frozen review identity.

The opened file's draft ID and path match the assignment. No hash command was run. The supplied frozen fingerprint is not independent proof.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The failed either-token grade fairly records this member's finding. The preserved response graded that need failed: entry pulls both pool currencies, a zero amount is allowed only when the tick already leaves that side unused, a zero `uReceived` reverts, and the specification refuses a vault swap on entry. The draft's Finding 1 says the same thing, adopts failed, and does not treat the out-of-range exception as meeting the need. That is a fair record. This feedback does not ask for that grade to be changed. It does not confirm the draft's account of any other member.

The partial fee grade misstates this member if it is read as this member's grade, and one adoption sentence misstates the reason. The preserved response graded the reserve need met. Fee escrow outside the share, and outside `getRate`, does not remove the position from the fee path. The stronger reading, that fees must sit inside the redeemable share, was rejected as not what the words require. The draft's disagreement table correctly records Grok as met. It then adopts partial "because of the uncomputable liability and the side-claim boundary." The side-claim boundary is why this member graded met. It is not a reason this member supplied for partial. The coverage table's bare "partial" and the opening line that the other three "must not be read as a clean pass" can be read as if that were Grok's grade. The liability-sum point was not this member's finding.

No finding invents code of this vault. Finding 2 says no implementation exists and does not review Wings or DETF as this vault. Finding 3's `floor(S * feePerShare / Q)` sentence is a hypothetical substitution an implementer might make. It is not a file that was read, and it is not presented as a contract that exists. Finding 4's V4 quoter and StateView sentence is attributed to another member, and the draft says that claim was not re-read. This member did not observe that code. It is not an invented implementation of this specification. It should stay labeled unre-read.

The quote and withdrawal grades in the draft stay met for the specification. That matches the preserved response. This feedback does not ask to change those grades.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Coverage table, fee row; opening paragraph, "must not be read as a clean pass"; Finding 3 adoption sentence; Preserved disagreements, fee-exposure row | The adopted partial fee grade is not this member's grade. The preserved response graded that need met. The side-claim boundary is the reason for met, not a ground for partial. Using that boundary as a reason partial was adopted misstates this member. The uncomputable-liability point may remain a coordinator adoption. It must not be written as Grok's finding. | Keep Grok at met. In the coverage table, label partial as a coordinator adoption, not as Grok's grade. Delete the side-claim boundary from the reasons partial was adopted. Do not fold this member's met grade into "must not be read as a clean pass." Do not change the failed either-token grade. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

This pass did not read peer responses or peer feedback. The draft's statements about Astra, Kimi, and MiniMax are not confirmed here and are not treated as support.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- The frozen sha256 was not computed. This disposition reviews the file opened at the assigned path. It does not prove those bytes are the frozen hash.
- response.md was not overwritten. The specification, draft, resolution, final, and RUN.md were not edited.
