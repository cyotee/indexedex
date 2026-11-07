# Identity

- Run ID: `se-fullspread-plan-execution-20261104`
- Follow-up ID: `questions-se-fullspread-plan-execution-20261104-r1`
- Member: `kimi`
- Phase: clarification questions
- Fresh or continued: continued
- Requested role: `council-member`
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Peers read: not read

# Clarification questions

## Question 1 — F2: which paid amount carries the caller minimum?

- PRD section: F2, “A quoted exit pays the planned amount; a proceeds mismatch was not observed,” especially its conditional fix direction.
- Two readings: A later implementer could enforce `minAmountOut` against the pool swap proceeds before paying the recipient. Another could enforce it against the recipient's actual token receipt, or require separate checks on both values. F2 names these choices but does not select one.
- One answer that removes the split: State whether the required minimum applies to swap proceeds, recipient receipt, or both, and identify which value the public `amountOut` must return.

## Question 2 — F4: does the no-step-cap rule cover the one-sided sizing search?

- PRD section: F4, “The sizing search has a 96-step bound; that is not proof every input misses the greatest liquidity.”
- Two readings: One reader would remove or replace the 96-iteration horizon because section 10's no-step-cap sentence covers `_size`. Another would retain the horizon after demonstrating that the sentence applies only to swap projection, while separately addressing greatest-liquidity optimality. The PRD states the conditional but does not resolve it.
- One answer that removes the split: State explicitly whether section 10's no-step-cap requirement applies to the one-sided `_size` search, so the implementer knows whether the fixed horizon itself must change.

## Question 3 — F5: are the six infrastructure bindings components under the rejection rule?

- PRD section: F5 and the recommendation to decide explicitly whether the six infrastructure addresses are components that must be code-checked.
- Two readings: One reader would add code-empty rejection for `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, and `universalRouter`. Another would leave them unchecked because it reads the plan's component rejection as covering only facets and linked libraries. The PRD records both readings and makes no decision.
- One answer that removes the split: Confirm whether all six named infrastructure bindings are components under plan section 4's missing-or-code-empty rejection rule.

## Question 4 — F8: should the weighted row change, or should the plan be amended?

- PRD section: F8 and the recommendation to remove the weighted two-leg `setUp` override, or amend the plan.
- Two readings: One implementer would restore the inherited behavior setup to conform to the current plan. Another would preserve the custom setup and pursue a later admitted plan amendment, as suggested by the source comment. The PRD offers both paths without selecting the authoritative outcome.
- One answer that removes the split: Choose whether the required outcome is inherited behavior setup under the existing plan or preservation of the custom setup through an admitted plan amendment.

# Limits

- These questions only name decisions already surfaced by the published PRD. They do not add a defect or reopen an item confined to its “Unresolved, not adopted and not rejected” list.
- Only `REMEDIATION_PRD.md` and `coordinator/questions-assignment.md` were read for this follow-up. No peer file was read.
- This file does not replace the PRD and does not authorize implementation, a PRD edit, tests, or Git actions.
