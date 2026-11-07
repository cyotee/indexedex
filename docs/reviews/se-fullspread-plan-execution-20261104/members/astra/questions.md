# Identity

- Run ID: se-fullspread-plan-execution-20261104
- Follow-up ID: questions-se-fullspread-plan-execution-20261104-r1
- Member: astra
- Phase: clarification questions
- Fresh or continued: continued
- Actual runtime role, model, reasoning, task ID, and session ID: not exposed
- Peers read: not read

# Clarification questions

## Q1. F5 and Recommendations - Are all six infrastructure bindings required to contain code?

- **PRD section:** F5, Invariant or requirement and Fix direction; Recommendations, third bullet.
- **Reading one:** F5 adopts the coordinator's interpretation of “component,” so a later implementer must reject code-empty values for positionDescriptor, positionManager, quoter, stateView, reservesLens, and universalRouter.
- **Reading two:** F5's “if” condition and the recommendation to “Decide explicitly whether” leave that interpretation undecided; the implementer must not introduce those six rejections without an additional decision.
- **One answer needed:** Does the remediation require all six named bindings to have deployed code, with `InvalidComponent` for a code-empty binding?

This asks for the decision expressly named by the recommendation, not a new component-validation defect.

## Q2. F8 and Recommendations - Which weighted two-leg setup rule is the remediation target?

- **PRD section:** F8, Fix direction; Recommendations, fifth bullet.
- **Reading one:** Restore conformance to the supplied plan by removing the weighted two-leg `setUp` override and using inherited behavior setup.
- **Reading two:** Retain the override and seek an authorized amendment making that setup conformant; changing the test implementation is not the selected remedy.
- **One answer needed:** Which final rule is intended for the weighted two-leg row: inherited behavior setup without an override, or an explicitly amended rule permitting the override?

The PRD offers both remedies but does not select one. The question does not authorize either a source change or a plan amendment.

# Limits

- Question count: 2.
- Only `REMEDIATION_PRD.md` and `coordinator/questions-assignment.md` were read for this follow-up.
- These questions concern choices expressly left in the published recommendations. They do not add defects or ask to reopen the PRD's separately named unresolved items.
- No peer files, prior response or feedback files, project source, tests, or Git were accessed. No sub-agents were launched.
- Only this owned questions file was written.
- This file does not replace the PRD and does not authorize implementation.
