# se-fullspread-plan-execution-20261104 — grok questions

## Identity

- Run ID: se-fullspread-plan-execution-20261104
- Follow-up ID: questions-se-fullspread-plan-execution-20261104-r1
- Member label: grok
- Phase: clarification questions
- Fresh or continued: continued
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Task ID: not exposed
- Session ID: not exposed
- Peers read: not read

This file does not replace the PRD and does not authorize implementation.

## Questions

### Q1. F5 and Recommendations — infrastructure code check

PRD section: F5, and the Recommendations sentence "Decide explicitly whether the six infrastructure addresses are components that must be code-checked."

Two readings: A later reader adds `code.length` checks for `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter` before they are stored. Another leaves the constructor unchanged because the fix direction is conditional and the dissent says those addresses are not the plan's component reject.

Answer that removes the split: Those six addresses are within the plan's component sentence. A later implementation must reject a code-empty value for each of them before it is stored.

### Q2. F8 and Recommendations — two-leg setup

PRD section: F8, and the Recommendations sentence "Remove the weighted two-leg `setUp` override, or amend the plan."

Two readings: A later reader deletes the two-leg `setUp` override and uses the inherited behavior setup. Another leaves the override and treats a later plan amendment as the remediation.

Answer that removes the split: Remove the two-leg `setUp` override. This PRD does not amend the plan, and a source comment is not that amendment.

### Q3. F4 — whether the quote-engine step-cap sentence covers the sizing search

PRD section: F4. The fix direction says that if the section 10 no-step-cap sentence covers this search, remove the fixed horizon or show why it is not a step cap. The Recommendations list does not mention the horizon.

Two readings: A later reader removes the 96-iteration bound because section 10 forbids a step cap. Another leaves the bound, because F4 says the bound is not a settled failure to produce greatest liquidity and the no-step-cap sentence is section 10, not section 2.

Answer that removes the split: Section 10's no-step-cap sentence does not cover `Planner._size`. Do not remove the 96-step bound as a settled failure.

## Limits

- Items the PRD already names as unresolved were not reopened. That includes the identity-bind tests, the single-row partial-consumption assertions, evidence classification, share-burn allowance, native credit receipt, repo-wide migration, index anchors, and the unverified capacity-function parent.
- No project code, test, or Git action was taken.
- This file does not replace the PRD and does not authorize implementation.
