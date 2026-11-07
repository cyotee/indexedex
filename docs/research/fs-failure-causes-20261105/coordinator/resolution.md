# Coordinator resolution

## Reviewed draft

- Draft ID: draft-fs-failure-causes-20261105-r1
- Path: docs/research/fs-failure-causes-20261105/coordinator/draft.md
- Fingerprint at review: 26c3a0f02241d084d81ed8ccdc3953d49c5d720b21888b546041a953d1c05e7e
- Draft bytes changed after review: no
- Members asked to review: astra, grok, minimax, kimi
- This resolution supersedes stale status lines in the draft: yes

## Participation and identity

- Run ID: fs-failure-causes-20261105
- Council kind and result label: full
- Coordinator mode: invoking-agent
- Requested coordinator role and model: invoking agent, invoking session model
- Actual coordinator role, model, reasoning, task ID, and session ID: not exposed
- Coordinator fresh or continued: continued
- Coordinator logical assignment and attempt count: fs-failure-causes-20261105/coordinator/synthesis, 1
- Owner or root session ID: not exposed
- Identity source: task spawn IDs recorded in RUN.md. Model prose is not identity.

## Feedback disposition

| Label | Feedback path | Draft ID named by member | Disposition | Initial response present |
| --- | --- | --- | --- | --- |
| astra | docs/research/fs-failure-causes-20261105/members/astra/feedback.md | draft-fs-failure-causes-20261105-r1 | requested-changes | yes |
| grok | docs/research/fs-failure-causes-20261105/members/grok/feedback.md | draft-fs-failure-causes-20261105-r1 | support-with-reservations | yes |
| minimax | docs/research/fs-failure-causes-20261105/members/minimax/feedback.md | draft-fs-failure-causes-20261105-r1 | support-with-reservations | yes |
| kimi | docs/research/fs-failure-causes-20261105/members/kimi/feedback.md | draft-fs-failure-causes-20261105-r1 | support | yes |

## Concern map

| Concern ID | Source | Concern | Disposition | Reason |
| --- | --- | --- | --- | --- |
| A1 | astra feedback, section 1 measurement | The displayed `SizeReject` operands are about 99.845 ether, so they do not corroborate a named 1 ether preview. | accepted | The final keeps the numbers only as an incompletely identified one-unit shortfall, not as proof of the 1 ether case. |
| A2 | astra feedback, partial consumption | Constant-product partial-consumption fails at seed with `InsufficientLpOut`. Other families use different refund predicates. | accepted | The final separates that seed failure from the refund assertions. |
| A3 | astra feedback, orbital | The draft omitted the valuation-fallback, zero-share buffer, then effective-reserve sequence, and treated `R == 0` as an observed alternative. | accepted | The final restores that sequence as member-read inference and does not claim `R == 0` was observed. |
| A4 | astra feedback, locators | Behavioral claims need full paths, and coverage should name every failing file. Coordinator-rechecked locators must be marked. | accepted | The final carries those paths and marks which locators the coordinator rechecked. |
| M1 | minimax feedback, predicate | `applied < n` is unreachable when gross already exceeds the input, so the supplied runtime cannot support that exit for a 1 ether offer if the operands are about 99.845 ether. | accepted | Same revision as A1. The predicate disagreement stays open. |
| G1 | grok feedback, section 4 locator | The cited 280-299 range includes success-path approvals after the catch `return`. | accepted | The final cites the catch `return` separately and says the later approvals are not on the rejection path. |
| G2 | grok feedback, orbital seed | "The seed accepts a zero quote" was stated as observed. | accepted | The final labels that sentence as an inference from the supplied `NotLive` rather than a seed trace. |

## Coordinator revisions

| Change | Where applied | Reviewed by members | Label |
| --- | --- | --- | --- |
| Withdraw the 1 ether association of the `SizeReject` operands | REPORT.md, cause 1 | no | coordinator revision |
| Separate constant-product partial consumption from refund assertions | REPORT.md, causes 2 and 3 | no | coordinator revision |
| Restore the orbital valuation sequence and mark seed acceptance as inference | REPORT.md, cause 2 | no | coordinator revision |
| Split the dual catch `return` from the unreachable success-path approvals | REPORT.md, cause 4 | no | coordinator revision |
| Name each failing file and mark coordinator-rechecked locators | REPORT.md, coverage | no | coordinator revision |

## Missing responses

- Missing initial responses: none
- Missing feedback: none
- Treatment: not approval. Not consensus. Not filled by a later advisory file.

## Unresolved dissent

MiniMax does not adopt `applied = n - 1` as established for the current exits, and does not adopt the stale-route reading as identifying the short spender. The final carries both gaps. Astra, Grok, and Kimi do not ask for those gaps to be closed by another predicate. No received feedback demands another review round.

## Synthesis attempts

| Logical assignment | Attempt | Task ID | Fresh or continued | Reason | Outcome |
| --- | --- | --- | --- | --- | --- |
| fs-failure-causes-20261105/coordinator/synthesis | 1 | not exposed | continued | synthesis | final written |

## Limits

- Original responses and feedback files remain unchanged.
- No implementation, reviewed-project tests, installs, or Git actions.
- Agreement among respondents is not a correctness guarantee.
- Inherited permissions are not confinement evidence.
