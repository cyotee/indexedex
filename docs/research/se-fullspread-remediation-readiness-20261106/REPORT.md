# Research report

## Question

- Run ID: se-fullspread-remediation-readiness-20261106
- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which one remediation implementation plan file is written, with no further owner product decision required?
- Profile: research
- Council kind: full
- Result label: full

## Conclusions

Verdict: not ready.

This is not a verdict that the code is ready to implement. It does not authorize implementation. It does not write the plan. The prior readiness report is not this verdict.

One product choice remains open. At a price that is not strictly inside the position, including exactly at either boundary, a one-token `donate` or `compound` of the token the position wants can leave dust the add does not take. Owner lock, 2026-11-06, Rule says a donate or compound remainder is booked. Boundary says add that token with no swap and refund what the add does not take, and it does not limit that refund to a share mint. Two plan authors can copy different dispositions. The owner must say which one applies to that dust.

Booking is the base-preserving reading. Family PRD FS-OWN-32 says a donation or compound remainder is booked, not refunded. The Entry remainder row says the same. Family plan section 9 says not to refund a donation or compound remainder. Refunding this dust would be a carve-out from those three sentences. The same-day Boundary sentence can still be read as the later specific instruction. Precedence ranks a 2026-11-06 lock over an older sentence. It does not rank two sentences inside that lock against each other.

A narrower reading would confine Rule to the 49% swap path, because that paragraph opens on the swap and the boundary path performs no swap. On that reading, Boundary governs alone and refunds the dust. The lock does not say Rule stops at the boundary. Both readings are available. That is why the text is not ready.

Share-mint dust is not this choice. Rule and Boundary both refund a user deposit. The other token is not this choice. Boundary books a donate or compound of that token. A collapsed candidate is not this choice. A share mint refunds that input and mints nothing. A donate or compound books that input and does not refund it. A first deposit that does not add more than 1,000 liquidity still reverts `MinLiquidityNotMet`. That is not a refund.

These locks are closed. A plan author can copy them without another owner question.

- Sizing is 49% of the processed input when the price is strictly inside the position. Do not iterate. Do not size an exact output. Do not solve a closed-form root. Do not walk ticks. The removed sizing method is not required.
- The one-token exit receipt is the swap proceeds, the withdrawn requested-token principal, the requested-token fee portion, and the requested booked claim. An incomplete exit raises `AmountOutNotMet` and does not burn.
- A missing or code-empty infrastructure address reverts `InvalidComponent`. The weighted two-leg `setUp` stays. Do not add an `exchangeRate` test. The named gas routes and ceilings stay.
- This pass does not walk or certify the preview-consumer index. The family plan still requires that migration.
- F7 is a parent-interface check. The unresolved list is not a finding that those items are defects.

## Participation

| Participant | Requested model | Initial verdict | Feedback | Task ID |
| --- | --- | --- | --- | --- |
| Coordinator | invoking session, xai/grok-4.7, xhigh | not a vote | draft, resolution, and this report | not exposed |
| astra | chatgpt-subscription/gpt-6-astra:high | not ready | support | st_01a1aed5 |
| grok | xai/grok-4.7:xhigh | not ready | requested-changes | st_01a1aed6 |
| minimax | minimax/MiniMax-M3 | ready | support-with-reservations | st_01a1aed7 |
| kimi | kimi-coding/k3.1-pro:high | ready | support | st_01a1aed8 |

- Coordinator mode: invoking-agent
- Missing initial responses: none
- Missing feedback: none
- MiniMax's ready verdict treated the Boundary paragraph as one specified outcome. It was not a missed corner. The advisory pass accepts that the collision makes not ready correct while the text is unchanged.
- Kimi's feedback says the initial ready assessment is superseded for this report. The original response remains ready.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Rule and Boundary | Remediation PRD, Owner lock, 2026-11-06 | source observation | The open dust disposition |
| Collapsed candidate | Same lock | source observation | Why that path is not the open choice |
| Donation booking | Family PRD FS-OWN-32 and the Entry remainder row | source observation | The base-preserving reading |
| Plan booking sentence | Family plan section 9 | source observation | The same base rule |
| Member verdicts | the four response files and four feedback files | source observation | Participation and dissent |

- Specification fingerprint, coordinator-supplied: `93907efa35b135f33f3c893390fcc2154bae1f011d1f74718f1a245a51853d07`
- Draft fingerprint, coordinator-supplied: `7de78ac3f367b07c4e005441f6fb9fe66ad7801f27a61c861718388eb45973f6`
- Draft bytes changed after review: no
- Members were not asked to recompute either fingerprint.

## Disagreement

- Initial verdicts split: astra and grok not ready; minimax and kimi ready.
- Advisory feedback did not produce a ready verdict. Astra, Grok, and Kimi support the not-ready finding. MiniMax accepts the collision and reserves on how the choice is framed. Those reservations are applied in Conclusions. They are not member-approved text.
- Dissent carried: yes. The original ready responses remain.

## Recommendations

- Say whether wanted-token dust on a boundary `donate` or `compound` is refunded or booked. One sentence removes the split.
- Do not ask the owner to reopen sizing, the exit receipt, the infrastructure checks, the gas list, or the migration scope.
- Do not write the plan until that dust sentence exists.

## Limitations

- Static reading only. No forge test, install, deployment, or Git action was run for this review.
- This report does not choose the dust disposition.
- Agreement among respondents is not a correctness guarantee.

## Publication

- Publication state: published
- Final path: docs/research/se-fullspread-remediation-readiness-20261106/REPORT.md
- Cooperative update: none. The remediation PRD was not edited by this report.
- Implementation authority: none
