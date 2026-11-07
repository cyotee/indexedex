# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r2-r1
- Path: docs/research/se-fullspread-remediation-readiness-20261105-r2/coordinator/draft.md
- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: the four settled initial responses and a coordinator re-read of the current owner lock

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra ready; grok ready; minimax ready; kimi ready
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which an implementation plan file is written, with no further owner product decision required?

## Proposed text

Proposed verdict: ready.

This is not a verdict that the code is ready to implement. It does not authorize implementation. It does not write the plan file. All four initial responses reached ready. That agreement is not proof. The prior report's not-ready verdict is not this verdict.

The coordinator re-read the current owner lock. Line 32 states the outcome when the price is not strictly inside the position, including a price exactly at `sL` or `sU`: do not use the quadratic, add only the one token the position wants, refund a share mint of the other token, book that token on donate or compound, and add no new error. Line 58 names the standalone gas routes: `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. It excludes `setOperator` and `setOperatorFor`. It keeps the three ceilings and a composed measurement for each section 12 row the plan names. Those are the two choices the prior report left open. The current text closes both.

The other copied rules remain closed: the exit error, the recipient receipt, the six infrastructure checks, the two-leg `setUp` override, no `exchangeRate` test, and the quadratic or segment cap instead of a search. F7 remains a parent-interface check, not an owner question. The unresolved list remains not a finding that those items are defects.

Grok disclosed two readings that are not open choices. The implementation plan still has a Weir sizing sentence. This PRD's sizing source is the lock, not that sentence. A plan author copies the lock. Zero active liquidity is excluded from the outside-position case, and the next sentence says a collapsed candidate returns the input and does not keep a selected swap. That is the outcome to copy. It is not a second product question.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| none | All four initial responses said ready. | Agreement is not proof. No member dissent was received. |

## Evidence gaps

- No member ran a test, compile, or gas measurement.
- The coordinator re-read the owner-lock sentences named above, not every finding body again.
- MiniMax disclosed that unread parts of the base plan or family PRD could still conflict with the lock. That residual is outside this PRD. It is not an open choice in the required target.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Current remediation PRD | examined | all four; coordinator re-read of lines 32 and 58 | Member citations of those lines match the re-read. |
| Prior report | optional | all four used it only as the old verdict | Not this verdict. |
| Implementation plan and family PRD | optional | used by members to test leftover choices | Not fully re-read by the coordinator. |

## Limits

- Static reading only. No runtime proof.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
