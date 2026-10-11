# Balancer SE liquidation implementation — complete

**Result: 2,041 passing tests / 0 remaining failures across 231 suites**, reconciled from the broad run and targeted follow-ups. All 30 former R23 failures are fixed. All eight invariant campaigns pass, each with 256 runs / 16,384 calls / zero reverts. Forty-eight new regression cases pass. No implementation or validation step remains pending for this scope.

## Owner decisions

- Keep StandardExchangeRateProvider protocol-agnostic. Quote the entire supply through the SE and normalize to a per-share rate.
- Implement liquidation semantics inside the SE. Full-reserve valuation may succeed even when the underlying protocol would reject execution at that size.
- Use native single-asset withdrawals, with bounded sequential native withdrawals for larger executable requests. No proportional-withdrawal/swap route was added.
- Successful same-state execution must equal its preview exactly. Preserve funding, fee and rounding rules, minimum-output/maximum-input enforcement, refunds, allowances and atomic rollback.
- Balancer-hosted DETFs remain owner-deferred.

## Completed coverage

| Component | Implemented behavior |
|---|---|
| `BalancerV3PoolStandardExchangeTarget` / `DefaultPoolInfoFacet` | Shared native liquidation route for the plain constant-product pool and six buffer families: single constant-product, MultiPair weighted, MixedLeg weighted, CommonBuffer weighted, CommonBuffer stable and MixedBuffer stable. |
| `BalancerV3SinglePoolStandardExchange` | Same route for external BPT, executed through the real router with exact funding/refunds and allowance cleanup. |
| `BalancerV3PoolStandardExchangeTransitionQuoteTarget` | Same route and projected state as live previews; virtual books, balances, fees and supply advance after each step. |
| Weighted and stable projected math | Project mutable virtual reserves and signed offsets using each family's actual representation; preserve native fee and rounding behavior. |
| Six family FactoryServices | Pass the CREATE3 factory into the artifact loader so the shared transition facet's libraries are linked. |
| V4 consumers and native SY | Regression coverage across 42 consumer rows and all seven native pool types. The V4 Balancer Quad hook uses Balancer math without BPT reserves; its compatibility is covered without adding BPT routing there. |

The generic rate-provider implementation was not changed by this follow-up. No storage layout or installed pool selector changed. Opaque projected quote state now includes the weighted virtual book and minimum invariant ratio; callers must obtain fresh snapshots after changing code versions.

## Implemented route

1. Snapshot actual Vault pool data, BPT supply, token scaling/rates, static and aggregate swap fees, minimum invariant ratio and the pool's virtual state.
2. Preserve a single native withdrawal when the input fits its current capacity. For larger exact-input amounts within the nine-step capacity, take up to eight capacity-sized steps and a final remainder.
3. Exact-input amounts beyond the bounded capacity use one native valuation step. Actual execution still calls the real Vault/router and propagates its rejection atomically. This avoids simulating unreachable intermediate stable states merely to obtain a full-supply rate.
4. Exact-output first evaluates a valid capacity-sized exact-input step. Consume that step if the requested output is at least its payout; otherwise invert the remaining output. Repeat within the nine-step bound. The total quoted BPT remains the actual pull budget.
5. Each step advances raw balances, aggregate fees, BPT supply, virtual balances and signed share offsets. Execution verifies each planned BPT/output amount against the actual Vault/router result.
6. At the whole-supply endpoint, the native single-token formula has zero remaining selected-token balance and zero non-proportional taxable amount. Quote that endpoint directly with native scaling and rounding. Locked BPT remains unspendable; underlying execution limits remain enforced.
7. Keep pinned weighted math within executable ratios. Beyond its lower exponent boundary, continue the same formula using an integer power and two half-fractional powers with conservative rounding. The external-pool adapter applies this only for the specific native `ProductOutOfBounds` error and reads weights from the pool itself. Other errors retain their payload.

## Findings resolved during validation

- Some weighted family interfaces are not registered through ERC165. Existing family views now identify the projected virtual book; regression controls require a nonempty book.
- A large stable exact-output inverse can underflow even when a sequence can pay the amount. Capacity-first planning avoids that invalid intermediate calculation.
- Full-supply sequences through highly imbalanced intermediate stable states can fail invariant convergence. Beyond bounded capacity, use the native valuation step directly.
- Near-total weighted reserves exposed the native lower power-domain boundary; the conservative valuation continuation handles it.
- Six FactoryServices omitted the factory argument needed to link the new libraries. All six helpers now deploy/link through CREATE3 and share the same facet identity.
- Twelve decimal reference-pool comparisons expected a scaled18 virtual reserve to be exactly fundable with 6- or 9-decimal raw tokens. They now assert exact equality to the representable virtual reserve. Production math and preview/execution assertions were not relaxed.

## Validation evidence

Logs, commands and source hashes are under `.scratch/errors-second-pass-2026-10-09/`.

| Run | Result and purpose |
|---|---|
| `r23-native-sequence` | One funded control passed before implementation: two 25%-of-current-supply native exits, each matching its live preview. |
| `r23-liquidation-focused` | First candidate: 120 passed / 16 failed; exposed virtual-book detection, stable inverse/intermediate-state issues and an unfunded adapter fixture. |
| `r23-liquidation-boundaries` | 5 passed / 1 failed; exposed the near-total weighted power-domain boundary. |
| `r23-liquidation-corrected` | 147 passed / 0 failed across 12 suites, including all 30 former R23 failures. |
| `r23-liquidation-broad` | 1,072 passed / 96 setup failures across 230 suites. All eight invariant campaigns and all 14 new native-SY cases passed; every setup failure had the factory-linking cause above. |
| `r23-liquidation-factory` | 957 passed / 12 failed across 97 suites. All setup failures resolved and the direct six-factory regression passed. Remaining failures were the decimal-reference assertions above. |
| `r23-liquidation-decimals` | 48 passed / 0 failed across all eight decimal combinations. Remaining assertions resolved. |

[Final suite reconciliation](../../.scratch/errors-second-pass-2026-10-09/r23-final-validation.json) selects the latest complete result for each suite: **2,041 passes / 0 failures / 231 suites**. All 27 source hashes match the final validation snapshot. This is a completed regression scope, not a fresh full-repository green run or an audit-readiness claim.

The 48 new cases cover whole-supply live/projected/rate equality, funded large exact-input and exact-output withdrawals, exact final projected state, atomic rollback, allowance cleanup, near-total reserves, supply below one share, real 6/18 and 9/6 token pools, every native-SY output and all six factory helpers.

## Runtime sizes

Final artifact measurements match the checked values; all fit the 24,576-byte limit.

| Component | Bytes |
|---|---:|
| DefaultPoolInfoFacet | 22,760 |
| Transition quote facet | 12,134 |
| Standalone BPT adapter | 13,764 |
| Liquidation library | 9,617 |
| Weighted projected-book library | 13,005 |
| Common stable pool facet | 14,072 |
| Mixed stable pool facet | 14,888 |

## Files and handoff

- Shared libraries: `BalancerV3PoolLiquidationLib.sol` and `weighted/BalancerV3WeightedBufferPoolQuoteLib.sol` under `contracts/protocols/dexes/balancer/v3/pools/`.
- Both BPT SE implementations, transition quotes and stable projected math use the implemented route.
- All six buffer-family FactoryServices link the shared transition facet through their CREATE3 factory.
- Test additions cover six-family liquidation behavior, the standalone adapter, a native sequence control, native SY and factory linking; the decimal comparison asserts representable reserves exactly.
- Pre-edit snapshots and the 25-file owned change manifest: `.scratch/r23-authorized-2026-10-10/`. The earlier, unauthorized three-file attempt was fully reverted before this authorized implementation and has separate snapshots.
- [Error handoff](ERRORS_HANDOFF_2026-10-10.md) and [durable evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json) record completion. Only the 17 owner-deferred Balancer-hosted DETF failures remain outside the completed error work.
- No changes committed, pushed or deployed.
