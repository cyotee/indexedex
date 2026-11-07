# Coordinator draft

- Draft ID: draft-se-fullspread-remediation-readiness-20261106-r1
- Path: docs/research/se-fullspread-remediation-readiness-20261106/coordinator/draft.md
- Run ID: se-fullspread-remediation-readiness-20261106
- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which one remediation implementation plan file is written, with no further owner product decision required?
- This draft is not the final. It does not authorize implementation. It does not write the plan.

## Verdict

not ready

Two careful authors of a plan would not copy one disposition for wanted-token dust on a boundary `donate` or `compound`. That is the only open product choice this draft adopts. The other examined locks are closed.

## Participation

| Label | Initial verdict | Response |
| --- | --- | --- |
| astra | not ready | members/astra/response.md |
| grok | not ready | members/grok/response.md |
| minimax | ready | members/minimax/response.md |
| kimi | ready | members/kimi/response.md |

All four initial responses settled. None is missing. MiniMax and Kimi did not name the boundary-dust split. That dissent is carried. It is not a vote that closes the split. The coordinator is not a fifth vote.

## The open choice

Location: remediation PRD, Owner lock, 2026-11-06, Rule and Boundary. Re-read by the coordinator after the initial pass.

Scope includes a one-token `donate` or `compound`.

Rule says a donate or compound remainder is booked.

Boundary, wanted token, says add it with no swap and refund what the add does not take. That sentence does not say it applies only to a share mint.

Boundary, other token, says a share mint refunds it and a donate or compound books it. That sentence does not state the wanted-token dust.

What the add does not take is a remainder. One sentence refunds it. Another books a donate or compound remainder. A plan author cannot copy both.

The family PRD `FS-OWN-33` repeats both sentences and does not add a third that ranks them. Family plan section 9 says not to refund a donation or compound remainder. That older sentence does not delete the Boundary refund sentence in the current remediation lock.

Share-mint dust is not this split. Rule and Boundary both refund a user-deposit remainder. The other-token maintenance case is not this split. Boundary books it.

## Closed by the current text

These are not open product choices. MiniMax and Kimi are right that the current lock closes them.

- Sizing is 49% of the processed input. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks. The removed sizing method is not required.
- A collapsed candidate returns the input and keeps no swap. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund. Zero active liquidity is not the boundary case.
- The one-token exit receipt is swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn.
- The six infrastructure checks, the weighted two-leg `setUp`, the withdrawn `exchangeRate` test, and the named gas routes and ceilings are stated.
- This pass does not walk or certify the preview-consumer index. The family plan still requires that migration.
- F7 is a parent-interface check. The unresolved list is not a finding that those items are defects.

## Limits

- Static reading of the remediation PRD and the cited family sentences. No forge run.
- This draft does not choose whether the wanted-token maintenance dust is refunded or booked.
- Agreement is not proof. This draft is not member-approved text.
