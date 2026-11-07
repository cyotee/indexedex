# Initial independent response

## Identity

- Member: grok
- Phase: initial independent response
- Role: council-member
- Requested model: xai/grok-4.7:xhigh
- Runtime identity: not exposed
- Task ID: not exposed

## Question and targets

Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which one remediation implementation plan file is written, with no further owner product decision required?

Required target: that file. Read whole, including the 2026-11-06 owner lock. No older copy was reviewed.

Specification fingerprint, coordinator-supplied: `93907efa35b135f33f3c893390fcc2154bae1f011d1f74718f1a245a51853d07`

Independent fingerprint: not computed

## Verdict

not ready

## Open product choice

### Owner lock, 2026-11-06 — Boundary, against Rule in that same lock

The lock's scope includes a one-sided share mint and a one-token `donate` or `compound`. It excludes a bundle deposit and a one-token exit.

The share-mint sentences in that lock agree with each other. A user-deposit remainder is refunded. At the boundary, the wanted token is added with no swap and what the add does not take is refunded. The other token is not swapped, and a share mint refunds it.

The one-token `donate` or `compound` case does not have one disposition when the price is not strictly inside the position, including exactly at either boundary, and the caller provided the token the position wants.

- Rule: a donate or compound remainder is booked.
- Boundary, wanted token: add it with no swap and refund what the add does not take. That sentence does not exclude `donate` or `compound`.
- Boundary, other token: a donate or compound books that token. That sentence is a different case. It does not state the disposition of wanted-token dust.

What the add does not take is a remainder. One sentence refunds it. Another books a donate or compound remainder. A later author cannot copy both. This response does not choose a disposition.

Optional context does not close it. Family PRD `FS-OWN-33` repeats the wanted-token refund sentence and the donate-or-compound booking sentence. It does not add a sentence for this case. Family plan section 9 says not to refund a donation or compound remainder. That sentence does not delete the Boundary refund sentence in this remediation PRD.

## Closed by the current text

These are not open product choices. Naming them does not reopen them.

- Sizing is 49% of the processed input. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks. The removed sizing method is not required.
- Zero active liquidity is the collapsed case, not the boundary case. If the 49% swap cannot be formed, or the following add cannot consume its output, keep no swap. A later share mint refunds that input and mints nothing. A donate or compound books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.
- The one-token exit minimum and the returned `amountOut` are the recipient receipt: swap proceeds, withdrawn requested-token principal, requested-token fee portion, and requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn. That does not change F1's error.
- The six infrastructure bindings, the weighted two-leg `setUp` override, the withdrawn `exchangeRate` test, and the named standalone gas set are stated. Each section 12 row the family plan names is a composed measurement. This pass does not certify the preview-consumer migration.
- F7 remains a parent-interface check the text assigns to the plan author. The unresolved list is not a finding that those items are defects.

## Coverage

| Target | Status | Reason |
| --- | --- | --- |
| Remediation PRD | examined | Read whole |
| Family PRD | partially examined | Read to test whether this PRD still needs an owner choice. Precedence, FS-OWN-14, FS-OWN-21, FS-OWN-30, FS-OWN-32, FS-OWN-33, and FS-A01 through FS-A16 were read. Not every section. |
| Family plan | partially examined | Read to test the same question. Sections 1, 2, 7, 8, 9, 10, 12, and 16 were read. A term search covered the file. Not every section. |
| `docs/research/se-fullspread-remediation-readiness-20261105-r2/REPORT.md` | examined | Not this verdict |
| Peer responses | not examined | Not read |

## Limits

- This verdict is not a verdict that the code is ready to implement.
- This response does not write the plan.
- This response does not authorize implementation.
- The coordinator-supplied fingerprint was not recomputed.
- No tests, installs, Git, or sub-agents were run.
- Public query: not used.
