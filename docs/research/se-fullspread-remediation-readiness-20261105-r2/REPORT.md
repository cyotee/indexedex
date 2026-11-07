# Research report

## Question

- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which an implementation plan file is written, with no further owner product decision required?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked whether the council now thinks the remediation PRD is ready to write the plan file
- Admitted read scope: the current remediation PRD, the implementation plan, the family PRD, and the prior readiness report, as named in the brief
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking session, not a vote | invoking session current model | not exposed | not exposed | continued | draft, resolution, and this report | process environment |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, high | st_01a1a9bc | fresh, then continued for feedback | initial ready; feedback requested-changes | task status |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, xhigh | st_01a1a9bd | fresh, then continued for feedback | initial ready; feedback support-with-reservations | task status |
| minimax | council-member | minimax/MiniMax-M3, admitted adaptive thinking | minimax/MiniMax-M3, reasoning not exposed | st_01a1a9be | fresh, then continued for feedback | initial ready; feedback support-with-reservations | task status |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high, high | st_01a1a9bf | fresh, then continued for feedback | initial ready; feedback support | task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

Verdict: ready.

This is not a verdict that the code is ready to implement. It does not authorize implementation. It does not write the plan file. The prior report's not-ready verdict is not this verdict. All four initial responses said ready. Feedback did not withdraw that verdict. Agreement is not proof.

A later author can write one implementation plan file from the current remediation PRD, using the existing plan and family PRD only as the base this PRD amends, without asking the owner another product question.

The two choices the prior report left open are closed.

The standalone gas set is named. The count of six is withdrawn. The routes are `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. `setOperator` and `setOperatorFor` are appointment calls, not routes in that set. Each section 12 row the plan names has its own composed measurement. The ceilings stay 11,900,000, 12,000,000, and 5,000,000.

The out-of-range starting price has one route outcome, scoped to a one-sided share mint, a one-token `donate`, or a one-token `compound`. It is not a one-token exit rule. The one-token exit stays with the base plan. If the price is not strictly inside the position, including exactly at `sL` or `sU`, do not use the quadratic. The position wants only one token. Those are exclusive branches. If the caller provided that token, add it with no swap and refund what the add does not take. If the caller provided the other token, do not swap it. A share mint refunds that other token. A donate or compound books that other token. No new error. The lock does not state a second preview outcome. The plan author does not ask the owner for one.

The other copied rules stay closed. An incomplete exit raises `AmountOutNotMet` and does not burn. The exit minimum is the recipient receipt. The six infrastructure bindings must have code. The weighted two-leg row keeps its `setUp` override. Do not add an `exchangeRate` test. One-sided sizing inside the position is the locked quadratic or the segment-boundary cap, not a search. The planned amount must not exceed the amount the pool applies after the fee is rounded up. The quadratic root is the solver input. The add uses the price the swap produces.

Zero active liquidity is not the outside-position branch. A collapsed candidate returns its input and does not keep a selected swap. Those are separate sentences. This report does not prove that every zero-liquidity state is a collapsed candidate. That classification is engineering work, not an owner question. A deposit that cannot meet the liquidity floor remains the written rejection, not a refund invented by this report.

F7 remains a parent-interface check. The unresolved list remains not a finding that those items are defects. A Weir sentence still in the existing plan is not the sizing source. The author copies this PRD's lock.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Gas list | Remediation PRD owner lock item 5 | source observation | The closed gas choice |
| Outside-position branches | Remediation PRD owner lock, Outside the position | source observation | The closed route outcome |
| Lock scope | Remediation PRD owner lock, Scope | source observation | Why the sentence is not an exit rule |
| Planned amount | Remediation PRD owner lock, Domain | source observation | Why the root is not a second execution price |
| Member verdicts | the four `response.md` files and four `feedback.md` files | source observation | Participation |
| Prior report | docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md | source observation | What this verdict replaces. It is not this verdict. |

Public query: not used.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Current remediation PRD | required | examined | Members reported reading it whole. The coordinator re-read the owner-lock sentences this verdict uses. |
| Implementation plan | optional | partially examined by members | Used to test leftover choices. Not fully re-read by the coordinator for this final. |
| Family PRD | optional | partially examined by members | Same limit. |
| Prior report | optional | examined by members | Not this verdict. |
| Peer originals and feedback | required for this synthesis | examined | All four initials and all four feedback files were read. |

## Disagreement and missing responses

- Disagreement: no member said not ready. Feedback dispositions were requested-changes, support-with-reservations, support-with-reservations, and support. The requested changes were wording, not a different verdict.
- Dissent carried into this report: no verdict dissent. The wording fixes are in Conclusions.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r2-r1
- Draft path: docs/research/se-fullspread-remediation-readiness-20261105-r2/coordinator/draft.md
- Resolution path: docs/research/se-fullspread-remediation-readiness-20261105-r2/coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok support-with-reservations; minimax support-with-reservations; kimi support
- Post-review wording changes: the outside-position sentence is restated as two exclusive branches, scoped off the one-token exit, and separated from zero liquidity and from the deposit floor
- Those changes are member-approved: no

## Recommendations

- Write the plan file from this PRD. Copy the lock. Do not ask the owner another product question named in the prior report.
- Do not treat this report as authority to implement the vault.

## Limitations

- Static reading only. No forge test, compile, gas measurement, install, or deployment was run.
- The fixture parent interface was not read.
- The reviewed draft bytes were not changed after review. The wording in this report is a coordinator revision.
- This report does not edit the remediation PRD, the implementation plan, or the family PRD.
- MiniMax adaptive thinking was admitted and was not exposed on the status line.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/se-fullspread-remediation-readiness-20261105-r2/REPORT.md
- Cooperative update: none. The remediation PRD was not edited.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
