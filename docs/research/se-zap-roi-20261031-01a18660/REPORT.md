# Zap function ROI

Revision **se-zap-roi-20261031-01a18660-final**. Coordinator revision after one advisory pass on draft `se-zap-roi-20261031-01a18660-r1`. This is not member-approved text, not an implementation, and not a PRD lock.

## Question

Is the utilitarian value of each public function worth its incremental implementation cost?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | SUPPORT WITH CLARIFICATIONS |
| Grok | REQUESTED CHANGES, on attribution, not on the three verdicts |
| MiniMax | REQUESTED CHANGES, on the record, not on the three verdicts |
| Kimi | SUPPORT WITH PRECISION CORRECTIONS |

The three splits stay open.

## Answer

| Public function | Recommendation | Cost, if the premise holds | What it adds |
| --- | --- | --- | --- |
| `previewZapCredit` | Not settled. Three implement. One does not. | Low to moderate only if it reuses the planner `exchangeIn` already requires. A second planner is not justified. | The per-currency credit and uncredited split. `previewExchangeIn` does not return it. |
| `maxZapBps()` | Not settled. Two implement. Two do not. | A one-line read if the cap is already stored. | The configured fraction. Not the maximum deposit a caller can make now. |
| `maxZapTickMove()` | Not settled. Same two and two. | A one-line read if the cap is already stored. | The stored tick bound. The revert can already return that same number. |

The current PairToken preview calls the same `Planner.plan` the current `exchangeIn` path uses. That is evidence of shape. It is not a requirement to copy the stage-one residual policy or the compound quarter-cap.

### `previewZapCredit`

Astra, MiniMax, and Kimi would implement it. A caller can see how a one-sided deposit was funded across both currencies, and how much bought no shares, before sending the transaction. `previewExchangeIn` returns shares and a same-token refund. It does not return that split.

The cost is not a new swap engine if the entry route already computes those fields. Astra still rates the public work low to moderate: the five outputs need defined semantics, and the preview has to agree with execution. Kimi's implement verdict assumes the entry plan still has a credited-versus-uncredited distinction. If that distinction is removed, Kimi wants a fresh ROI decision. MiniMax's keep also thins if a later refund rule zeroes the uncredited pair. It flips only if the family then also judges the credit pair not worth a public home. If there is no one-sided entry route, there is nothing to preview.

Grok would not implement it. A small wrapper does not pass the value test. The four fields are residual accounting this family has not locked. Do not fold all four into "residual," and do not say the current `previewExchangeIn` already returns that refund. It returns one same-token amount.

### `maxZapBps()` and `maxZapTickMove()`

Astra and Kimi would implement both getters. The cost is very low if the values are already stored. The value is discovery, display, and filtering without a failed call. Astra accepts that `maxZapBps()` is not a maximum-input quote. Reserve basis, timing, rounding, and the other route checks still matter. Kimi says the tick getter is narrower than the size getter, and the low cost still clears the bar. Both keep any internal cap separate from the getter. Neither adopts the stage-one compound quarter-cap.

MiniMax would not implement either getter. The value fails even though the read is cheap. `maxZapBps()` publishes a fraction, not the reserve-relative maximum a revert already carries. An integrator who reconstructs that maximum from `IBasicVault.reserves()` is approximating, because the planner's reserves are not that view. `maxZapTickMove()` publishes the same number the tick-move revert already carries. It is also easy to misread as a depositor slippage bound. MiniMax would still keep both caps as internal configuration and planner enforcement, independent of the getters. A public getter would also have to promise or deny the stage-one coupling between the size cap and the compound cap. That coupling is a reason to skip the getter. It is not a requirement to copy the formula.

Grok would not implement either getter. Do not attribute a keep-the-cap recommendation to Grok. Whether a size cap or a tick cap exists internally is not his verdict. He also does not decide whether `compound()` uses a size cap.

## Limits

No implementation was run. This report does not edit the full-spread PRD or the function-review file. It does not authorize code changes.
