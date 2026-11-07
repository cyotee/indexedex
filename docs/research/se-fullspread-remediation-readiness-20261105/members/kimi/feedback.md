# Member feedback

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105
- Member label: kimi
- Profile: research
- Phase: advisory review
- Requested role: council-member
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: not exposed
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105/members/kimi/feedback.md`
- Peer responses or feedback read during this advisory pass: no
- Original `response.md` preserved: yes

## Draft under review

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r1
- Path: `docs/research/se-fullspread-remediation-readiness-20261105/coordinator/draft.md`
- Fingerprint: not computed

## Disposition

support-with-reservations

## Concerns

| Draft section | Why two readers could diverge | Requested change |
| --- | --- | --- |
| Proposed text, item 1, “Owner lock, Domain through Token1 in”; Preserved disagreements, “Symbol `n`” | The draft says downward gross rounding and upward fee rounding can make executable net input smaller than the root, then treats pricing from the root and pricing from that smaller net as two readings. The same item also quotes the constraint that planned `n` must not exceed the amount the pool applies. As written, it does not establish whether the smaller-net reading violates that constraint, makes the planned candidate infeasible, or is actually permitted by another lock sentence. Two readers can therefore diverge over whether this is an owner product ambiguity, an infeasible rounding construction, or an implementation check rather than an adopted product choice. | Before retaining item 1 as an adopted verdict blocker, state the precise rounding inequality and identify the lock wording that permits each proposed reading, distinguishing an infeasible candidate from two allowed behaviors. If that derivation is not available, keep Astra’s rounding concern as preserved disagreement rather than an adopted owner-choice blocker. This is advice, not an edit. |

## What was not adopted from others

- The draft accurately preserves my unnamed-six-routes and F7 capacity-override concerns as adopted choices.
- The draft does not adopt my unresolved-list scope concern as an owner question. Its explanation that “not a finding” can be copied without selecting new product behavior addresses the owner-choice part of that concern; I do not request its reinstatement as a verdict blocker.
- Astra’s outside-domain and zero-active-liquidity concern remains recorded as disagreement rather than an adopted choice. I did not independently adopt that concern initially and do not request a new blocker here.

## Limits

- Reviewed only the identified coordinator draft. No source locator was re-read and no fingerprint was computed.
- No peer response or peer feedback was read. No project source, tests, builds, installs, deployment, wallets, or Git actions were used.
- This feedback supports the proposed `not ready` verdict through the unnamed gas-route and F7 concerns, with the reservation above about item 1’s reasoning.
- This feedback does not replace the draft, rewrite the original response, or authorize implementation.
