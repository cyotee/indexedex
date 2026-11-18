# Handoff: native sweep reverts RateProviderFailed

The hermetic and fork suites passed. There is no failing Foundry test to rerun. The failure is the native local lifecycle.

## What fails

`MigrationCoreLocalQA.exerciseAfterCliff` does not finish on a fresh nonforked Anvil after `deployAndIssue`.

Stage A mines, including the real 1-ether owner purchase. The measured 90-day cliff is mined. Activation and the compensation principal claim mine. The explicit `sweepDust()` then reverts `RateProviderFailed()`.

Two direct `sweepDust` transactions were mined under the node's 32,000,000 gas cap. Both reverted. One used 31,391,954 gas. The other used 31,483,922. Raising the cap is not allowed. Giving the transaction the largest limit still under 32,000,000 did not help.

The script simulation fails the same way before it can broadcast the rest of Stage B. Trace: `native-stage-b/simulation-500.log`. Receipt note: `native-stage-b/sweep-failure.md`.

## Why

`sweepDust` reaches `joinResidualAtomic`, which quotes `previewJoinUnbalanced` / `previewJoin` on the weighted buffer hook. That quote calls `getRateFailClosed` more than once.

The first rate read succeeds. The second does not have enough gas left to finish. The rate provider is `StandardExchangeRateProviderFacet`. Its `getRate()` prices the whole Standard Exchange book through `previewExchangeIn` on the Uniswap V3 full-spread vault. A completed call of that preview, earlier in the same quote, used 40,809 gas. The failing call reaches `previewExchangeIn` with about 15,779 gas left. The inner Uniswap V3 `positions()` read then runs out of gas (`MemoryOOG`).

The hook does not set a gas stipend. `_readRate` and `_getRateFailClosed` are bare `staticcall`s. A failed `getRate()` staticcall is converted to `RateProviderFailed` by `readCapturedRate`. The provider did not return zero or a wrong rate. The call reverted.

`previewJoin` itself was entered with only 181,740 gas because `joinResidualAtomic` was entered with 193,955, at the tail of a sweep that had already used about 31.48 million. Unused gas at the top of the transaction does not reach that inner preview.

## Not the cause

- Not the mixed-Solar artifact mismatch. That was a separate `test_fullSourceIdentifier` failure, fixed by removing a stale artifact. The rerun passed 28,667 hermetic tests.
- Not a stored-zero fee reading back as the 5% default. That was a fixture issue in the raw-hook comparison, already fixed.
- Not an assertion that the rate value is wrong.
- Not a missing owner purchase. Bonds 3 and 4 were queried after the mined purchase.

## Where to look

- `scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol`: `exerciseAfterCliff`, `_sweepOldDonations`.
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`: `_readRate`, `getRateFailClosed`, `readCapturedRate`.
- `contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol`: the other bare `staticcall`.
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`: `getRate` calls `previewExchangeIn` for the full share supply.
- The weighted hook's `previewJoin` / `previewJoinUnbalanced` path that calls `getRateFailClosed` twice inside one quote.

## Constraint

Do not raise the Anvil gas ceiling and do not present a simulation as a mined receipt. A fix has to make this `sweepDust` quote finish inside a transaction that fits in 32,000,000 gas, or show why that quote cannot.
