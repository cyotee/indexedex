# Coordinator draft

## Draft identity

- Draft ID: se-zap-roi-20261031-01a18660-r1
- Path: docs/research/se-zap-roi-20261031-01a18660/coordinator/draft.md
- Run ID: se-zap-roi-20261031-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: Astra st_01a192d3, Grok st_01a192d4, MiniMax st_01a192d5, Kimi st_01a192d6
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

For `previewZapCredit`, `maxZapBps`, and `maxZapTickMove`, is the utilitarian value of the public function worth the incremental implementation cost?

## Proposed text

These are recommendations. They do not lock the PRD and do not authorize implementation. The owner has already locked the drop of `previewWithdrawalMode` and the family `wrappedNative()` getter. That lock is not reopened.

All four originals separate the public function from any internal cap. No original says that dropping a getter removes a cap. No original adopts the stage-one residual formula or the compound quarter-cap as the reason to implement or skip the public function.

The current PairToken `previewZapCredit` is a view over the same planner the share-out preview already calls. The two getters are one-line reads of stored config. That shape is evidence. It is not a requirement to copy the current residual policy. If the full-spread entry plan does not already compute the four credit fields, `previewZapCredit` is not a free wrapper.

The three public verdicts are not settled. See the disagreement table.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| `previewZapCredit` | Astra, MiniMax, and Kimi: implement. The per-currency credit and uncredited amounts are not returned by `previewExchangeIn` or a revert. The cost is low only if it reuses the entry planner. A second planner would not be justified. MiniMax's keep thins if a later refund rule makes the residual `amountRefunded`. Grok: do not implement. The wrapper can be small, and the value test still fails. Shares and same-token refund are already on `previewExchangeIn`. The four-way split is stage-one residual accounting this family has not locked. | Whether the diagnostic split is worth a public selector before a residual policy exists. |
| `maxZapBps()` | Astra and Kimi: implement. A caller can read the configured size bound without a failed call. The getter is very cheap if the cap is already stored. MiniMax and Grok: do not implement the getter. Keep any size cap as internal configuration and enforcement. MiniMax adds that the revert already returns the operative maximum, and the getter would publish a fraction rather than that maximum. | Whether discovery of a stored cap is worth a permanent getter when a revert already carries the exceeded bound. |
| `maxZapTickMove()` | Same split as `maxZapBps()`. Astra and Kimi: implement. MiniMax and Grok: do not implement the getter. Keep any entry tick-movement cap internal. MiniMax adds that integrators may misread the getter as a depositor slippage bound. Kimi says its value is narrower than the size getter, and the low cost still clears the bar. | Same open question as the size getter. Grok does not decide whether `compound()` uses the size cap. |

## Evidence gaps

- No original executed the functions. The cost claims are readings of the current PairToken bodies.
- Whether this family will store and enforce either cap is not locked. The ROI split assumes that question is separate.
- The full-spread PRD was not an admitted target for this pass.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Public preview versus internal plan | Read | All four | No conflict on the separation. Conflict on whether the public selector is worth it. |
| Cap getter versus internal cap | Read | All four | No original removes the cap by dropping the getter. 2-2 on the getter. |
| Stage-one formulas | Read | All four | Not adopted as the implementation requirement. |

## Limits

- Static reading only. No execution was run for this draft.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- The coordinator did not vote on the three splits.
