# Research report

## Question

- Run ID: se-fullspread-remediation-readiness-20261105
- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, including the owner lock dated 2026-11-05, ready to be the source from which an implementation plan is written, with no further owner product decision required?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked this invoking session to have the council review the remediation PRD and confirm whether it is ready to write an implementation plan
- Admitted read scope: the remediation PRD, the implementation plan, and the family PRD, as named in the brief
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking session, not a vote | invoking session current model | not exposed | not exposed | continued | draft, resolution, and this report | process environment |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, high | st_01a1a98b | fresh, then continued for feedback | initial not ready; feedback requested-changes | task status |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, xhigh | st_01a1a98c | fresh, then continued for feedback | initial not ready; feedback support-with-reservations | task status |
| minimax | council-member | minimax/MiniMax-M3, admitted adaptive thinking | minimax/MiniMax-M3, reasoning not exposed | st_01a1a98d | fresh, then continued for feedback | initial ready; feedback requested-changes | task status |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high, high | st_01a1a98e | fresh, then continued for feedback | initial not ready; feedback support-with-reservations | task status |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

Verdict: not ready.

This is not a verdict that the code is ready or not ready to implement. It does not authorize implementation. It does not write the plan. MiniMax's initial verdict was ready. That dissent is carried. The other three initial verdicts were not ready. Feedback did not produce agreement.

The remediation PRD does close these product splits. A later plan can copy them without asking the owner again:

- An incomplete one-token exit raises `AmountOutNotMet` and does not burn.
- The exit minimum and the returned `amountOut` are the recipient receipt: swap proceeds plus the withdrawn amount sent to the recipient.
- The six named infrastructure bindings must have code. A missing or code-empty value reverts `InvalidComponent` with no partial diamond.
- The weighted two-leg row keeps its `setUp` override.
- Do not add an `exchangeRate` test. FS-A01 through FS-A04 remain.
- One-sided sizing is the locked quadratic or the current-segment cap, not a 96-step search.
- The planned swap amount must not exceed the amount the pool applies after the fee is rounded up. The quadratic root is the solver input. Execution follows the price the swap produces, which is the sentence at remediation PRD line 28. That reading is a coordinator revision of the draft's first blocker. It is not a new owner answer, and it was not reviewed by the members.

Two product choices remain open. Either one is enough for this verdict.

1. Owner lock item 5 does not name the six standalone gas routes, and it does not define "both shapes of `exchangeIn`." Plan line 374 puts that unnamed phrase in the same cell as FS-A05 through FS-A08. Those rows, re-read in the family PRD, are the first deposit, the bundle deposit and redeem, the entry refund, and the one-token exit. They do not enumerate six gas routes. The family money facet lists five money selectors. Plan line 94 installs seven money-facet selectors, including the two operator appointment calls. Kimi also read locked and unlocked `exchangeIn` dispatch as shapes. MiniMax inferred one list of six. That inference is not the text. A later author cannot copy one standalone gas list without choosing the set.

2. The lock's domain is a starting price strictly inside the position. It does not state the execution or preview outcome when the starting price is not strictly inside that range. Family PRD FS-OWN-22 accepts any initialized hookless pool and has no inherited-domain check. FS-PKG-02 says not to reject a pool outside an inherited domain, and says the first depositor creates the position. Those sentences govern installation, not the call-time outcome. A collapsed candidate that cannot add liquidity is a different case: F3 and recommendation line 221 say return the input and do not keep a selected swap. That does not state what happens when the formula's domain assumption is false at the start. A later author would have to choose that route outcome.

F7 is not an owner question. Line 136 says not to treat the empty capacity overrides as satisfying "not part of this fixture," and not to delete them until the parent requirement is checked. Plan line 217 says those functions are not part of the fixture and not to add a sleeve capacity gate. The plan author checks the parent. If the parent forces the functions, keep empty overrides that add no gate. If it does not, omit them. That is engineering work against sentences already written. The unresolved list at lines 176-188 is not an owner question. The PRD says naming those items is not a finding that they are defects.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Closed splits | Remediation PRD lines 24-55, 80-82, 107-109 | source observation | The copied product rules |
| Symbol `n` and execution price | Remediation PRD lines 28-42 | source observation | Why the root is not a second execution price |
| Unnamed six routes | Remediation PRD line 56; plan lines 94, 374, and 389; family PRD money-facet table and FS-A05 through FS-A08 | source observation | The first open choice |
| Out-of-range starting price | Remediation PRD lines 30 and 95-102; family PRD FS-OWN-22 and FS-PKG-02 | source observation | The second open choice |
| Capacity procedure | Remediation PRD lines 131-138; plan line 217 | source observation | Why F7 is not an owner question |
| Member verdicts | the four `response.md` files and four `feedback.md` files | source observation | Participation and dissent |

Public query: not used. No private excerpt was sent to a search service.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Remediation PRD | required | examined | Read for the lock, F1 through F11, the unresolved list, and the recommendations. Members reported reading it whole. |
| Implementation plan | optional | partially examined | Re-read the selector cut, the capacity sentence, and the gas table cell. Not every section 12 row body was re-read by the coordinator. |
| Family PRD | optional | partially examined | Re-read FS-OWN-22, FS-PKG-02, the money-facet selector table, and FS-A05 through FS-A08. |
| Peer originals and feedback | required for this synthesis | examined | All four initials and all four feedback files were read. |

## Disagreement and missing responses

- Disagreement: MiniMax's initial verdict is ready. Astra, Grok, and Kimi said not ready. Feedback dispositions were requested-changes, support-with-reservations, requested-changes, and support-with-reservations. MiniMax's feedback attacked the draft's reasons and did not withdraw the ready verdict.
- Dissent carried into this report: yes. MiniMax ready. Grok and Kimi treated F7 as an open choice; this report does not.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r1
- Draft path: docs/research/se-fullspread-remediation-readiness-20261105/coordinator/draft.md
- Resolution path: docs/research/se-fullspread-remediation-readiness-20261105/coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok support-with-reservations; minimax requested-changes; kimi support-with-reservations
- Post-review wording changes: the final drops the symbol-`n` blocker and the F7 owner-choice blocker, splits zero liquidity from the out-of-range starting price, and attributes the locator offset to Grok
- Those changes are member-approved: no

## Recommendations

- Before a plan is written, name the six standalone gas routes and the two shapes of `exchangeIn`.
- Before a plan is written, state the one-sided execution and preview outcome when the starting price is not strictly inside the position.
- Do not ask the owner to choose between the quadratic root and the pool-applied amount. Line 30 already forbids the planned amount from exceeding the pool-applied amount. Line 28 already points the add at the price the swap produces.
- Do not ask the owner to choose the capacity-override end state. Check the parent interface and follow line 136 and plan line 217.

## Limitations

- Static reading only. No forge test, compile, gas measurement, install, or deployment was run.
- The fixture parent interface was not read. The F7 conclusion is a reading of the written sentences, not a reading of that parent.
- The reviewed draft bytes were not changed after review. The verdict wording in this report is a coordinator revision.
- This report does not edit the remediation PRD, the implementation plan, or the family PRD.
- MiniMax adaptive thinking was admitted and was not exposed on the status line.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md
- Cooperative update: none. The remediation PRD was not edited.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
