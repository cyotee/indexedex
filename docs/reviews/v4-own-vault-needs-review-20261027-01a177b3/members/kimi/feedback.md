# Member feedback

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: kimi
- Phase: advisory review
- Owned path: members/kimi/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: role council-member as assigned; task ID st_01a17d26 as given in the assignment; model, reasoning, and session ID not exposed
- Fresh or continued: continued
- Initial response path: members/kimi/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: b0a2c24b31c1ce1cb88e51306c5074631627f141b4839aacc44c363a36b29447, as given in the assignment
- Fingerprint independently computed: not computed. The assignment forbade running a hash command.
- Draft bytes opened: yes, the full file at the path above. Its own identity lines name this draft ID and path. The draft header also carries a different value labeled "pre-insertion sha256" and states the frozen review identity lives in RUN.md, which I did not open.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

Answers to the two questions put to me:

Does the failed either-token grade fairly record my partial grade? Yes. The draft attributes the partial grade to Kimi and MiniMax in Finding 1's impact paragraph and again in the Preserved disagreements table, with the reason I gave: one side works when the tick already leaves the other unused. It then states plainly that the failed grade is the adopted one and why. My dissent is recorded, not absorbed or silently overwritten. I maintain the partial grade as recorded dissent; the adoption of failed is a transparent coordinator call, and the draft's framing sentence "the depositor cannot choose either token" is a defensible reading of the need as worded. I do not request a change to the adoption.

Does any finding invent code? No. Finding 1 quotes the specification and gives a fix direction explicitly labeled as not implementation authorization. Finding 2 reports absence, which matches my own repository search. Finding 4 quotes sections 5 and 7 of the specification and attributes the V4Quoter and StateView observation to MiniMax, with the coordinator's Evidence gaps section disclosing it was not re-read. Finding 3 reasons from the specification's terms-table definitions; its counterexample is disclosed as unexecuted. No finding fabricates contract code for this vault or reviews unrelated Wings code as this vault.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Finding 3, Impact paragraph, final sentences | "That sum is not a stored total ... It is not yet a payable on-chain rule" treats an unspecified storage detail as a failure of the written accounting. The specification defines `liability_i` mathematically as a sum over accounts and does not prescribe iterating holders; the impossibility of a holder loop is an implementation constraint, not a sentence the specification got wrong. The underlying warning is valid: an implementer who substitutes `floor(S * feePerShare / Q)` for the per-account floor sum overstates liability, and the draft's own Evidence gaps disclose that MiniMax's counterexample was not executed. | Reword the failure claim to: the specification does not state how `liability_i` is aggregated on-chain, and an implementation must not approximate the per-account floor sum with `floor(S * feePerShare / Q)`. Keep the dust and remainder warning. Drop or soften "not yet a payable on-chain rule." |
| C2 | Finding 1, Fix direction | The proposed either-token entry that swaps only the required amount is materially the zap route the specification explicitly rejected as member dissent, and the specification also warns that a deposit swap must not be described as closing the swap-capture result. The draft repeats the swap-capture caveat but does not flag that the advice overrides the specification's stated rejection. | Add one sentence to the fix direction noting that this route is the one the specification rejected, so adopting it is a product decision that overrides that rejection, not a repair of an oversight. |

## What was not adopted from others

- Peer responses read: not read. Peer positions are known to me only through the draft's own quotations of them.
- Peer feedback read: not read
- Unread members treated as support: no

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
