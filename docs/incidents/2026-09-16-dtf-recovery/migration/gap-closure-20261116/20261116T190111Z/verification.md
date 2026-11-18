# Gap-closure verification - 2026-11-16

No commit was made. This is not deployment approval, a public-execution approval, or a claim that every gap closed.

## Results

| Gate | Command result | Closure |
| --- | --- | --- |
| F1 hermetic sweep | `c2.log` exited 0. 40 tests passed, including the no-second-release, pre-live, rollback, and reentry witnesses. | Not closed. The native `sweepDust` receipt failed. |
| F2 owner purchase | `c5.log` exited 0. 14 tests passed. Stage A mined compensation bond 3 and paid bond 4 for the dev account. | Not closed. `exerciseAfterCliff` did not finish. |
| F3 metadata | `c3.log` exited 0. 19 tests passed. Post-claim SVGs were rendered for bonds 3 and 4. | Not closed. The captures are after the claim and before the failed sweep. No pre-cliff URI was saved. |
| P1 raw-hook comparison | `c4.log` exited 0. 39 tests passed. `pricing-parity.md` records the observed hook comparison. | The hermetic comparison passed. It does not prove the native lifecycle. |
| Integrated hermetic | `c6-build.log` exited 0. `c6-hermetic.log` exited 0: 28,667 tests passed. An earlier mixed-Solar artifact failure is preserved in `c6-hermetic-mixed-solar.log` and is not this result. | Passed for the non-fork suite. |
| Fork | `c6-fork.log` exited 0: 184 tests passed. This was an in-process fork, not a public broadcast. | Passed for the pinned fork suite. |
| Native sweep | Two mined `sweepDust` transactions reverted `RateProviderFailed()` under the 32,000,000 gas cap: `0xf21e2f52d87ba937ae4b5b42bb9258298c96f18b1fc778f0460ca2a5af5fe439` used 31,391,954; `0xc91925c928944848c78533e66932e55c530bff6a81d2422e5834321ace7a4c79` used 31,483,922. | Failed. The node cap was not raised. |

## Measured local gas

The largest capped Stage A transaction used 29,857,962 gas. The failed sweep used 31,483,922 gas and still reverted. Those figures are local Anvil measurements, not ArbOS fee estimates. Historical task-11 limits remain historical.

## Unresolved limit

The native two-stage lifecycle is not complete. Activation and the principal claim mined. The explicit old-donation sweep did not. Donation inventory for the paid token was still 50 ether after the failed sweep. Do not infer native success from the hermetic or fork logs.
