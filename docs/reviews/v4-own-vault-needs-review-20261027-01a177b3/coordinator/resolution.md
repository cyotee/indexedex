# Coordinator resolution

## Reviewed draft

- Draft ID: draft-v4-own-vault-needs-review-20261027-01a177b3-r1
- Path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/coordinator/draft.md
- Fingerprint at review: frozen-file sha256 b0a2c24b31c1ce1cb88e51306c5074631627f141b4839aacc44c363a36b29447
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Council kind and result label: full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking session, not a vote
- Actual coordinator role, model, reasoning, task ID, and session ID: invoking session; model not exposed; task ID none; session 01a177b3-f4ed-7770-9633-b5735573eb05
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: v4-own-vault-needs-review-20261027-01a177b3/coordinator/synthesis, attempt 1
- Owner or root session ID: 01a177b3-f4ed-7770-9633-b5735573eb05
- Identity source: PI_SESSION_ID and task host completion notices

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | members/astra/feedback.md | draft-v4-own-vault-needs-review-20261027-01a177b3-r1 | requested-changes | yes |
| grok | members/grok/feedback.md | draft-v4-own-vault-needs-review-20261027-01a177b3-r1 | requested-changes | yes |
| minimax | members/minimax/feedback.md | draft-v4-own-vault-needs-review-20261027-01a177b3-r1 | support-with-reservations | yes |
| kimi | members/kimi/feedback.md | draft-v4-own-vault-needs-review-20261027-01a177b3-r1 | support-with-reservations | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| ASTRA-ADV-01 | members/astra/feedback.md | Do not fail fee exposure because fees are a side claim | accepted | Specification grade is met. The side-claim boundary is not a failure of the stated need. |
| ASTRA-ADV-02 | members/astra/feedback.md | Liability sum is not a proved impossibility | accepted | It is an unresolved accounting gap. A wrong aggregate substitution is not required by the specification. |
| ASTRA-ADV-03 | members/astra/feedback.md | Storing an aggregate is not itself the fix | accepted | The final does not prescribe that store. `getRate` already excludes fees. |
| ASTRA-ADV-04 | members/astra/feedback.md | Do not claim no product anywhere can do these operations | accepted | The absence is no identified implementation of this specification. |
| G1 | members/grok/feedback.md | Partial fee grade misstates Grok if the side claim is the reason | accepted | Grok stays met. Partial is not adopted. |
| C1 | members/kimi/feedback.md | Do not call the liability sum a failure of the written fee need | accepted | Same split as ASTRA-ADV-01 and ASTRA-ADV-02. |
| C2 | members/kimi/feedback.md | The deposit fix is the zap the specification rejected | accepted | The final says adding that route is a product decision, not a silent repair. |
| C1 | members/minimax/feedback.md | Aggregate-liability fix can recreate the insolvency | accepted | That prescription is withdrawn. |
| C2 | members/minimax/feedback.md | The entry accepts either amount; success is tick-conditional | accepted | The impact is restated. The failed grade stays. |
| C3 | members/minimax/feedback.md | Amount-to-liquidity inversion is unnamed | accepted | Named, with the swap-capture caveat. |
| C4 | members/minimax/feedback.md | Say what the quote grade covers | accepted | Met covers the equation and revert set. The missing preview mechanism is named. |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Fee grade returned to met; accounting gap separated; deposit impact restated; zap labeled a product decision; quote grade scoped | REMEDIATION_PRD.md | no | coordinator revision |

The reviewed draft bytes were not changed.

## Missing responses

- Missing initial responses: none
- Missing feedback: none
- Treatment: not approval. Not consensus.

## Unresolved dissent

- Kimi and MiniMax still grade either-token deposit partial because one side can succeed when the tick already leaves the other unused. The final keeps failed.
- MiniMax still treats the missing preview mechanism as a specification partial on the quote. The final keeps the equation grade met and names the gap.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| v4-own-vault-needs-review-20261027-01a177b3/coordinator/synthesis | 1 | none | continued | synthesis | draft frozen, then this resolution and the final |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- This resolution does not authorize implementation.
