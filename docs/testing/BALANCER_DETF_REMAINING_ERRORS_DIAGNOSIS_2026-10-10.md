# Balancer DETF remaining failures — diagnosis, 2026-10-10

## Resolution

The owner subsequently authorized the fixes. All 17 cases are now fixed and verified; **875 tests passed / 0 failures across 87 suites**. See [implementation and validation](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md). The diagnosis below describes the pre-fix code.

## Scope

Source diagnosis of the 17 owner-supplied failures. No production or test changes; no fresh test run in this diagnosis. The supplied failures are consistent with the current code paths below. Functional fixes remain unapplied.

## 15 stale preview assertions

| Cases | Family | Cause | Recommended test correction |
|---:|---|---|---|
| 2 | MixedBuffer stable routes, base and native matrix | Buffer-token → DETF exact-output preview is unsupported and explicitly returns zero | Assert exact zero; separately require execution to revert InvalidRoute with the actual token addresses and preserve balances/supply |
| 9 | MultiVault weighted mint/burn, base and eight decimal variants | SE-share → DETF exact-output preview is unsupported and explicitly returns zero | Same correction in base and shared decimal behavior |
| 1 | Composed stable exchange-in preview | Reserve-dependent preview explicitly returns zero before reserve activation | Assert zero, and retain a separate execution negative |
| 3 | Composed stable exact-output previews | Unsupported input, unsupported output, and inactive reserve each return zero | Assert zero for each condition; test unsupported output both before and after activation so liveness cannot mask route validation |

The first 11 cases are not decimal arithmetic failures. Their shared query targets support exact-output direct DETF/staked-DETF conversions only; reserve routes retain exact-input support. A successful low-level preview call means the query returned normally, not that the route is executable. The tests currently assert that the low-level call itself failed.

Sources:

- [MixedBuffer query target](../../contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol:45): unsupported preview returns zero; execution rejects the route at entry.
- [Weighted query target](../../contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeQueryTarget.sol:44): same policy.
- [Composed exchange-in preview](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenPricingTarget.sol:53): inactive reserve returns zero, except direct staking conversions.
- [Composed exchange-out preview](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol:21): explicit input/output/liveness checks return zero.

## 2 execution failures: missing entry validation in composed exact-output flow

Both occur in `ComposedStableCommonDetfExchangeOutQueryFacet.exchangeOut`.

Execution calls the nonreverting preview and receives zero for an unavailable route or inactive reserve. It only checks whether that quote exceeds the caller's maximum. Zero passes that check. Execution then performs the funding step with amount zero and continues into `_executeExactOutExit`, which selects the exit again without the preview's route/liveness checks.

### Unsupported output: ExchangeOutNotAvailable instead of InvalidRoute

For output address `0xBAD`, the preview returns zero. The later `_selectExactOutExit` calls `_previewMostLiquidUnwindSelection`; no route is eligible, so that helper reverts `ExchangeOutNotAvailable`.

The error-selector mismatch alone would not establish an accounting defect: this request does revert. The code confirms an entry-validation gap, however, and exact-input execution already explicitly rejects unsupported family outputs with `InvalidRoute`. Recommended correction: validate supported execution input/output routes before funding and preserve an explicit `InvalidRoute` contract for this case.

### Inactive reserve: MaxOutRatio instead of ReservePoolNotInitialized

Before bootstrap, the reserve-dependent preview returns zero. Execution nevertheless tries to price the requested WETH exit. The inner pools are initialized by the fixture, but the DETF's weighted reserve has not been activated/funded. `_previewReserveDetfInForPoolBptOut` reaches weighted exact-output math with an empty output reserve. A positive requested amount exceeds the maximum output fraction of a zero balance, so `WeightedMath.computeInGivenExactOut` reverts `MaxOutRatio`.

Recommended correction: require the reserve to be live before quoting or executing any reserve-dependent exact-output route. Reuse `_requireReservePoolInitialized` and retain the test's specific expected error. The existing exact-input flow already applies this guard. Preserve direct DETF/staked-DETF conversions, which deliberately have a separate 1:1 path.

Sources:

- [Execution entry](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol:33).
- [No eligible unwind route](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:393).
- [Weighted reserve exact-output quote](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:754).
- [Exit execution reselects route](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:917).
- [Existing exact-input guards](../../contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol:40).
- [WeightedMath output-ratio guard](../../lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol:222).

## Recommended resolution order

1. Correct the 15 preview assertions to exact zero and make execution negatives separate assertions/tests.
2. Add route and reserve-state validation to composed exact-output execution before funding; reject a remaining zero-input quote for a positive-output request with an explicit unavailable-route error.
3. Check both funding flags, unchanged payer/recipient balances and supply on rejection, valid direct staking conversions, and exact preview/execution parity for valid reserve exits. Preserve positive-amount and deadline error precedence.

These failures do not call for changed pool pricing, looser rounding assertions, or implementation of previously unsupported reserve exact-output routes.
