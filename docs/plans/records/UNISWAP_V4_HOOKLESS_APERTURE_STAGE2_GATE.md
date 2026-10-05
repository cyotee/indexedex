# Stage 2: Hookless analytic composition

Gate M was removed by the owner on 2026-10-04. It is not a status here.

## Dispatch

`TransitionPlanner._composition` calls `AnalyticComposition._plan` with a live overlay. Work-limit maps to `QuoteWorkLimit`. Other analytic failures try one zero-swap certification, because a price already at the swap limit has no positive root and the existing route still admits that deposit. There is no amount search.

`_plan` and `_candidate` are public so their bytecode is not inlined into the planner. That keeps deployed runtimes under 24,576 bytes.

## Runtime size (`forge build --sizes`, 2026-10-04)

| Contract | Runtime | Margin to 24,576 |
|---|---:|---:|
| AnalyticComposition | 20,502 | 4,074 |
| AnalyticSwapMath | 8,621 | 15,955 |
| TransitionPlanner | 12,964 | 11,612 |
| DFPkg | 14,466 | 10,110 |
| InFacet | 24,099 | 477 |
| InExecutionDelegate | 23,700 | 876 |
| OutFacet | 24,571 | 5 |
| OutExecutionDelegate | 19,362 | 5,214 |

`_zeroSwap` was added after this measurement. The planner had 11,612 bytes of margin before that function.

A pre-change gas baseline was not frozen. The planner was already edited when measurement started.

## Tests

Passed before the consumer command was cut off at 15 minutes:

- Analytic math, corpus, traversal, certification, and executor settlement.
- `QuoteExecutionParity` (6) and `TransitionLifecycleClosure` (9).
- Orbital SeMatrix against the FullSpread vault (10).
- Hookless and Pons consumer burn gates.
- `test_noDirectionalRoomRetainsValidZeroSwapBothExtremes` after the zero-swap certification.

Named failures in that run:

- `OrbitalV4PositionFundedBindingTest`: `testFuzz_bindingPositionShareDepositWithinChainGasLimit`, `test_bindingPositionShareGasCounterexample`, `test_bindingPositionShareInputsRedeemThroughEveryNativeSyOutput`, `test_bindingV4LpPaymentKeepsBufferAssetsAndFitsChainGasBudget`. These reverted. The orbital hook sources were already dirty in the worktree and were not edited by this refactor.

The locked consumer command did not print a final tally. The agent set its own tool timeout to 900000 ms and the shell was stopped when that elapsed. That timeout was not set by the user or the plan. Do not treat the partial log as a finished Stage 2 pass.
