# Astra — REQ-04 replacement-session targeted answer

This is a targeted readiness answer, not a new findings round. I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. I read the application PRD's current REQ-04 section at lines 124–134 and the relevant rounding and exact-output assertion bodies in all six cited behavior files. No other reviewers' notes were read.

## Answer

**One owner decision remains before the PRD can prescribe an unambiguous zero-output acceptance rule.** The file list and requirement for an exact SE-share debit are closed. The inspected tests and controlling section do not, by themselves, select whether a proven unrepresentable deposit must reject or may succeed while retaining its input and issuing zero shares.

The application section permits “the family's exact rounding error, or a measured successful zero-output and retained book.” That is a statement of allowable evidence shapes, not a per-family expected-outcome assignment. The current tests cannot supply that missing assignment without circularly treating the behavior under test as its own oracle:

- Weighted's `_roundingToZeroControl` at 210–240 says accepted deposits must issue a positive claim. Its explicit zero-preview branch expects `MinAmountNotMet(1, 0)`, but its failed-preview branch expects arbitrary preview revert bytes.
- The other five helpers accept named `InsufficientTokenOut()` or `ZeroAmount()` errors **or** the failed preview's selector; their successful branch also permits zero shares with input retained. None fixes which of these outcomes applies to each independently established rounding condition.
- A one-unit input is not itself proof that the output is unrepresentable for every underlying SE/decimal fixture. A positive representable outcome must not be misclassified as a zero-output case.

### The one owner question

> **When a supported deposit is independently shown to round to zero hook shares, must all six hook families reject it atomically, or is a successful zero-share deposit that retains the caller's input an intended outcome for any of those families?**

### One sentence that would close the question, if adopted by the owner

> For a supported deposit independently shown to round to zero hook shares, all six named families must reject atomically with the existing specific error for that proven branch and unchanged caller balances, hook custody, share supply and relevant books; successful zero-share retention is not an accepted rounding control, while independently representable positive deposits retain their funded success controls.

This is a proposed owner-adoption sentence, **not a selected product rule or authorization to change production**. It closes the rejection-versus-retention policy; the coordinator's later PRD/plan must then name the existing source-derived error and independent branch precondition for each fixture, not hand an error-selector choice or a search to the implementer. If the owner instead intends retention in a family, that family and its expected retained-book outcome must be explicitly identified before consolidation; the current broad alternative is not sufficient.

## Already closed: six-file scope and exact share assertions

All paths below are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`:

| Family | Exact relative behavior path | Rounding helper / preview-echo locations | Exact-output share assertion |
|---|---|---|---|
| Weighted | `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` | 212–240; 216–225 | 282: strict decrease |
| Dual CP | `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` | 299–339; 321–322 | 380: strict decrease |
| Single CP | `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` | 268–304; 286–287 | 345: strict decrease |
| Orbital | `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` | 290–326; 308–309 | 368: strict decrease on leg 0 |
| Balancer quad | `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` | 320–356; 338–339 | 397: strict decrease |
| Curve quad | `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` | 268–304; 286–287 | 345: strict decrease |

All six currently use `assertLt` for the SE-share debit in `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed`; none of these six assertions is already an exact reconciliation that should be cited as complete. The replacement requirement is exact equality between the measured output-leg SE-share debit and the independently established shares required by that route for its requested face output, accounting for the route's existing custody/residual preconditions. Do not compare it with `needIn` blindly: that variable is the hook swap's **input-token** quote, not necessarily the output-leg SE-share requirement. This unit/route reconciliation is an engineering specification to fix in the plan, not another economic owner decision.

The single non-CP behavior is excluded by the controlling section. Existing funded swap, exact-output payout, caller-refund, false-flag pull and code-less-caller assertions must remain. Removing a preview echo does not justify a bare expected revert, an arbitrary named-error alternative, or declaring a row compatible without proving the selected rounding branch.

## Limits

All six cited files were present. The targeted reads establish the current alternatives and six strict-decrease assertions; they do not determine each concrete matrix fixture's production rounding result or prove a runtime error path. No Forge, compiler, shell, delegation or external documentation tool was used. No source, test, PRD, configuration or instruction file was edited; only this assigned Markdown answer was written.

I did not run Forge.
