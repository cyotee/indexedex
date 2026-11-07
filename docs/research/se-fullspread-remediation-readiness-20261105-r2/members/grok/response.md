# Member response

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105-r2
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-fullspread-remediation-readiness-20261105-r2/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

The member label is the caller's assignment. Runtime identity was not given. No task ID was invented. This self-description is not proof of the runtime model.

## Question and targets

- Question: Is `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, as now written, ready to be the source from which an implementation plan file is written, with no further owner product decision required?
- Required targets: `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, read whole, including the owner lock
- Optional context: the implementation plan, the family PRD, and `docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md`
- Admitted read scope: the required target, those three optional files, and the brief for this run

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Whole remediation PRD | `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md`, 248 lines, through the publication section | source observation | The current file includes the 2026-11-05 owner lock, findings F1-F11, the unresolved list, and the recommendations. |
| Sizing lock | Remediation PRD lines 24-50 | source observation | The 96-step search is not the method. Scope is a one-sided share mint and a one-token `donate` or `compound`. The quadratic, the fee constraint, the outside-position rule, and the segment cap are written in this file. |
| Five copied answers | Remediation PRD lines 52-58 | source observation | Infrastructure, two-leg `setUp`, exit receipt, rate tests, and the named gas routes are locked in this file. Item 5 names seven standalone routes and withdraws the count of six. |
| Exit and collapse directions | Remediation PRD lines 84, 93, 102, 111 | source observation | F1 keeps `AmountOutNotMet` and no burn. F2 copies the receipt basis. F3 returns a rejected candidate's input and keeps no selected swap. F4 is superseded by the lock. |
| Capacity and gas directions | Remediation PRD lines 138, 174, 222-229 | source observation | F7 assigns a parent check and does not order deletion. F11 and the recommendations point gas tests at the named standalone routes and the plan's composed rows. |
| Unresolved list | Remediation PRD lines 178-180 | source observation | Naming those items is not a finding that they are defects. |
| Prior open choices | `docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md` lines 36, 50-56 | source observation | That report's verdict was not ready. It named two open choices: the unnamed standalone gas set, and the missing outcome when the starting price is not strictly inside the position. It said F7 and the unresolved list are not owner questions. |
| Plan gas list and rows | Implementation plan lines 258, 389, and 494-496 | source observation | Section 12 labels row files. Section 13 names the same seven standalone routes. Section 16 item 4 still says to size one adapted Weir swap. Section 16 item 6 points at those seven routes and each section 12 row. |
| Public query | not used | source observation | No repository text was sent to a search or fetch service. |

The prior report is not this verdict. Its line numbers for the remediation PRD are not reused here. The current file was read on its own lines.

## Assumptions

- A preview of a one-sided share mint, or of a one-token `donate` or `compound`, quotes the route outcome in remediation PRD line 32. That line does not use the word preview. This assumption is inference, disclosed in Conclusions. It is not a second owner sentence.
- Starting active liquidity of zero is copied as the collapsed-candidate outcome in the same paragraph, not as a third unnamed product rule. That identification is inference, disclosed in Conclusions.

No required target is missing. These are readings of sentences that were read, not substitutes for an unread file.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` | required | examined | Read whole. The read ended at the publication section. The tool reported 248 lines. |
| `docs/research/se-fullspread-remediation-readiness-20261105/REPORT.md` | optional | examined | Read to identify the choices that report named as open, and to avoid treating a closed sentence as still open. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md` | optional | partially examined | Read section 2's gas bullet, section 12's opening and row labels, section 13's gas instruction, and section 16. Not every section was read. Read only to test whether "section 12 row named by the plan" and the copied owner answers still force an owner choice. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | optional | not examined | Not needed to test the two choices the prior report left open. The current lock states the call-time out-of-range outcome and names the standalone routes. No requirement was invented from this unread file. |

## Conclusions

Verdict: ready.

This is not a verdict that the code is ready to implement. It does not authorize implementation. It does not write the plan. Peers were not read. This is not council consensus.

Observation. The prior report, at lines 50-54, left two product choices open. The current remediation PRD closes both. A later author can write one plan file from this PRD, using the existing plan and family PRD only as the base this PRD amends, without asking the owner another product question. Two careful authors do not have to choose between contradictory sentences in this PRD.

The gas set is closed. Remediation PRD line 58 withdraws the count of six. It names the standalone routes: `exchangeIn` one-sided share mint, `exchangeIn` one-token exit, `exchangeIn` pass-through, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`. It says `setOperator` and `setOperatorFor` are appointment calls, not routes in that set. It says each section 12 row named by the plan has its own composed measurement. The ceilings stay 11,900,000, 12,000,000, and 5,000,000. An oversized route is unresolved, not passed. Line 174 and line 227 point the plan author at that named list and at the plan's composed rows. The implementation plan, at line 258, labels a section 12 row by file, and at line 389 names the same seven standalone routes. Inference: the author copies line 58 for the standalone set and takes the composed set from the rows the plan already names. That is use of the base, not an owner question. The prior unnamed "both shapes of `exchangeIn`" choice is not still open.

The out-of-range outcome is closed. Remediation PRD line 32 says: if `s` is not strictly inside the position, including a price exactly at `sL` or `sU`, do not use the quadratic. The position wants only one token. If the caller provided that token, add it with no swap and refund what the add does not take. If the caller provided the other token, do not swap it. A share mint refunds it. A donate or compound books it. No new error. Inference: that is the execution outcome the prior report asked for, and it is also the preview outcome, because the same sentence forbids the quadratic and forbids a new error and does not state a second preview rule. The missing word "preview" is not a remaining product choice.

Other product sentences in this file can be copied as written.

- Lines 24, 30, 34-48, 111, and 229: the sizing method is the locked quadratic, or the one segment-boundary cap when the solved price would leave the current constant-liquidity segment. Do not iterate. Do not walk ticks. Do not keep the 96-step search as the method. Line 30 already says the planned `n` must not exceed the amount the pool will apply for the rounded-down gross input, and that the pool rounds its fee up. That is a constraint on the amount, not a choice between the root and another execution price. Line 28 already points the following add at the price that swap produces.
- Line 54: the six named infrastructure bindings are components. A missing or code-empty value reverts `InvalidComponent` with no partial diamond.
- Line 55: keep the weighted two-leg `setUp` override. The older prohibition is withdrawn.
- Lines 56, 84, and 93: the one-token exit minimum and the returned `amountOut` are the recipient receipt, swap proceeds plus the withdrawn amount sent to the recipient. That is not the swap proceeds alone and not the pre-execution quote. Line 56 says this does not change F1's error. Line 84 maps the incomplete exit shortfall to `AmountOutNotMet` and does not burn.
- Line 57: do not add or keep an `exchangeRate` test. `getRate` stays uninstalled. FS-A01 through FS-A04 remain required. Rate rows use `IStandardExchangeRateProvider`.
- Line 32, line 102, and line 223: a collapsed candidate returns the input and does not keep a selected swap. Line 102 says that is not a new product rule.
- Line 129, as restated at line 225: remove the booked getter. Do not add a production booked view to satisfy a parent.

F7 is not an owner question. Line 138 says not to treat the empty capacity bodies as satisfying "not part of this fixture," and not to delete them until the parent requirement is checked. Line 225 says not to treat those overrides as if the plan omitted them. The prior report, at line 56, already classified that check as engineering against sentences already written. The current text still assigns the check to the plan author. This response does not reopen it.

The unresolved list is not an owner question. Lines 178-180 say naming those items is not a finding that they are defects. A plan author does not ask the owner to adopt or reject them before writing the plan file.

Observation, not a contradiction inside this PRD: the implementation plan at line 494 still says to size one adapted Weir swap. This PRD does not contain a Weir sentence. Its sizing source is lines 24-50. Inference: the author copies that lock into the new plan file. The author does not ask the owner to choose between Weir and the quadratic.

Inference, disclosed so it is not mistaken for a quotation: line 32 says zero active liquidity is not the outside-position case, and the next sentence says a collapsed candidate returns the input and does not keep a selected swap. The text does not say the words "when active liquidity is zero, return the input." It also does not state a third outcome, and it does not ask the plan author to choose one. I read the collapsed sentence as the outcome to copy for that exclusion. That reading does not leave two contradictory sentences. It is not a new product question.

No open, contradictory, or too-unclear product choice remains in the current remediation PRD.

## Limits

- Runtime or extraction proof: not exposed. No task ID was invented. Reading was static. No test, compile, gas measurement, install, deployment, or Git action was run.
- Not examined: the family PRD. Sections of the implementation plan other than the gas bullet, the section 12 opening and row labels, the section 13 gas instruction, and section 16. This run's peer responses.
- The prior report was examined only as optional context. Its not-ready verdict is not this verdict. Its remediation-PRD line numbers describe an earlier text and were not reused.
- Live files can change. This response is a reading of the files as opened in this pass, not an atomic snapshot.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
