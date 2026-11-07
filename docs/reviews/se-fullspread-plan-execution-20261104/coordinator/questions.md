# Clarifying questions on the remediation PRD

- Run ID: se-fullspread-plan-execution-20261104
- Follow-up ID: questions-se-fullspread-plan-execution-20261104-r1
- Document: docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md
- Asked: astra, grok, minimax, kimi. All four settled. None wrote `none`.
- This list does not edit the PRD, does not answer the questions, and does not authorize implementation.

A preferred answer below is that member's own sentence. It is not a council decision.

## Q1. Are the six infrastructure bindings components that must contain code?

- PRD: F5 and the third recommendation.
- Raised by: astra, grok, minimax, kimi.
- Split: add `InvalidComponent` when `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, or `universalRouter` is code-empty, or leave those six unchecked because "component" means only the cut and the linked libraries.
- Answer that removes the split: say whether plan section 4 covers those six addresses, and whether F5 is a defect under that answer only or under either answer.
- Grok's preferred answer, not adopted: the six are within the component sentence and must be rejected when code-empty.

## Q2. Which weighted two-leg setup is the remediation target?

- PRD: F8 and the fifth recommendation.
- Raised by: astra, grok, kimi. MiniMax did not ask this.
- Split: delete the two-leg `setUp` override and use the inherited behavior setup, or keep the override and amend the plan.
- Answer that removes the split: pick one. This PRD does not amend the plan, and a source comment is not an amendment.
- Grok's preferred answer, not adopted: remove the override.

## Q3. Which amount carries the one-token exit minimum?

- PRD: F2 and the first recommendation.
- Raised by: minimax, kimi.
- Split: compare `minAmountOut` with swap proceeds, with the recipient's receipt, or with both, and say which of those the public `amountOut` returns.
- Answer that removes the split: name that one basis. The PRD asks the reader to choose and does not choose.

## Q4. Does the no-step-cap sentence cover the one-sided sizing search?

- PRD: F4.
- Raised by: kimi, grok.
- Split: remove the 96-iteration horizon because section 10 covers `Planner._size`, or keep it because that sentence does not cover the sizing search and F4 does not treat the horizon as a settled greatest-liquidity failure.
- Answer that removes the split: say whether section 10's no-step-cap rule applies to `_size`.
- Grok's preferred answer, not adopted: it does not cover `_size`, and the bound should not be removed as a settled failure.

## Q5. Does the package remediation include the rest of FS-A16?

- PRD: F9 and the sixth recommendation.
- Raised by: minimax only.
- Split: add only FS-A01 through FS-A04, leaving FS-A16's "issuance does not read `exchangeRate`" half uncovered, or also complete that half in `Package.t.sol`. The PRD names no other file for the missing half.
- Answer that removes the split: say whether this remediation includes that half, and if not, name the file that carries it.

## Q6. Which routes must the gas measurements cover?

- PRD: F11 and the sixth recommendation.
- Raised by: minimax only.
- Split: one standalone measurement per named money or maintenance route plus one composed case in `BufferHookIntegration.t.sol`, or one composed measurement per hook route in the section 12 row files as well.
- Answer that removes the split: list the standalone routes and say whether the composed measurement is one case or one per route, and name the file or files.

## Owner answers, 2026-11-05

These are the owner's words applied to the questions above. They are not a council vote. Q4 is not answered.

- Q1: yes. Check the six bindings for code and revert if none is present. The owner called them Uniswap V3 infrastructure and said the vault will not work if they are absent. Recorded in plan section 4 and section 16.
- Q2: edit the plan. The two-leg override stays. The older prohibition is withdrawn. Recorded in plan section 12 and section 16.
- Q3: the recipient receipt. Swap proceeds plus the withdrawn amount sent to the recipient. Recorded in plan sections 6, 9, and 16.
- Q4: decided. "Greatest liquidity" means the amount that can reliably be swapped while any needed refund stays in the provided token. It is not a search for the best split. Do not iterate. Size one adapted Weir swap to that rule.
- Q5: `getRate` and `exchangeRate` were dropped. Use `IStandardExchangeRateProvider` for tests. Drop all `exchangeRate` tests. Recorded in plan section 13 and section 16.
- Q6: gas tests for all supported routes, so the implementation can be shown to execute on mainnet under the existing ceilings. Recorded in plan section 13 and section 16.

## Not reopened

The PRD's unresolved list stays unresolved. That includes the exit projection, the zero-liquidity floor path, identity-bind tests, partial-consumption assertions, evidence classification, share-burn allowance, native credit receipt, repo-wide migration, index anchors, and the capacity-function parent. No member asked those again.
