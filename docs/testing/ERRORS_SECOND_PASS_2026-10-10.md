# Remaining-error implementation and validation — 2026-10-10

Status: **all 1,505 in-scope original failures and all 30 additional R23 failures pass; 17 Balancer-hosted DETF failures remain deferred.** Final Balancer validation reconciles **2,041 passing tests / 0 remaining failures across 231 suites**, including eight invariant campaigns. Completed second-pass evidence contains **9,100 distinct passing tests**, retaining earlier passes unless superseded. Current checklist: [handoff](ERRORS_HANDOFF_2026-10-10.md). Per-test results: [second-pass evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json).

## Decisions applied

- Value the entire outstanding share supply, including projected SE supply. Do not substitute a small trade quote, halve until a quote succeeds, or omit the last share.
- Reject a user deposit that cannot mint one vault-share unit. Reject a direct BPT deposit that cannot mint BPT. Use an explicit minimum error before taking custody.
- Keep otherwise representable, undeployed residual capital locally booked; retry deployment on later operations. Do not donate it to the underlying hook without receiving LP.
- Reject genuinely unattainable alignment at the offered price and deposit size. Preserve holder-protection bounds and exact same-state quote/execution checks.
- Continue deferring the 17 Balancer-hosted DETF failures. Balancer SEs, hooks and rates remain in scope.

## Implemented mechanisms

| Groups | Change | Validated coverage |
|---|---|---|
| R18, R20, dependent R22 | The DETF residual orchestrator previews the complete proposed join mode, tries the supported single-asset alternative after a zero proportional quote, removes the ten-native-unit cutoff, retains booked unmintable leftovers, and requires execution to match a positive quote. Removed dead donation fallbacks. | Original lifecycle, ownership, custody, decimal, donation and reentrancy cases across all four V4 DETF families. |
| R05, rate portion of R03 | Standard rates quote total supply once; wrapped rates convert total wrapper supply once and value the resulting exact SE claim. Normalize once with upward rounding. Full-quote failure returns zero without sampling. | Full-supply call expectations, one-unit supply, final rounding, live/projected contexts, actual Morpho and wrapped integration. |
| R04 | Native BPT preview mirrors pinned unbalanced-add rounding while returning zero for a non-increasing invariant. Execution rejects a zero quote before custody changes and still uses the actual Vault math. | Seven pool configurations, exact neighboring payable boundary and atomic rejection. |
| R15 | Uniswap V2, Camelot and Aerodrome vault zap-in routes preflight share mintability, preserving true-flag funding checks. Single wrapper and weighted join commits explicitly reject zero-share issuance. | Matrix zero-output controls, exact error, unchanged payer balance, supply and local book; positive controls. |
| R19 | Orbital checks the forward SE quote for the actual rounded partial intake. If it is infeasible, use the already radius-capped offered amount only when its forward quote is positive, then recompute LP issuance. Preserve the exact quoted SE minimum. | Original mixed-decimal and Morpho/V4 product-law witnesses, plus residual lifecycle coverage. |
| R07 | Replace a fixture's arbitrary `> 10` dust premise with positive retained balance and a proven zero forward quote; require a later funded sweep to consume retained input and increase reserve LP. | Original H6 product-law suite. |
| R21 | Move random-sequence action-count requirements into deterministic money-path witnesses; retain accounting/custody invariants and fail-on-revert behavior. | Normal configured invariant campaigns and deterministic witnesses. |
| R17 | Reuse existing redemption implementations: the exact-input delegates for V3/V4 FullSpread and the installed output/withdrawal implementations for Aerodrome, Orbital, Balancer Quad and Curve Quad. Authorization, reentrancy and applicable operation scope stay on the SY facet; execution helpers are not installed on the vault. | Runtime sizes of every component, exact held-share redemption, direct implementation rejection and absent proxy selectors. |

## Evidence location

Commands, complete logs, snapshots before each edit, source hashes and the reconciliation script are in [`.scratch/errors-second-pass-2026-10-09/`](../../.scratch/errors-second-pass-2026-10-09/). The directory date records when this pass started.

The completed broad batch passed **7,127 tests** and failed **30 R23 tests** across **320 suites**. It reran all **1,505 in-scope original failures successfully**, including all 1,389 R18 cases, ten R19 cases, 16 R17 cases, both R21 cases and all three R22 cases. The 17 Balancer-hosted DETF failures remain excluded. This is historical broad evidence; the later funding and Balancer runs supersede affected results in the per-test reconciliation.

## Outstanding boundaries

- All seven formerly oversized components and their reused execution implementations pass the production-only bytecode size gate. Functional regression validation passed in the broad run; deployment-size assertions remain unchanged. Curve query-only token enumeration and synthetic claim normalization now reuse its existing external claim library; its geometric-mean calculation uses the existing math library, with unchanged arithmetic.
- Additional Orbital/Curve Quad funding fixes are complete: all ten regressions and the 3,738-test affected batch pass.
- A positive quote followed by a different execution result remains a production error; do not reclassify it as acceptable dust or loosen assertions to close a test.
- No full-repository green run or security-audit readiness is claimed by this pass.

## R23 — Full-supply BPT valuation boundary — fixed

**Fixed and verified across the broad regression scope and targeted follow-ups.** The generic rate provider correctly requests `previewExchangeIn(BPT, totalSupply, selectedAsset)`. The old SE routed this valuation through a single-token execution bound, returning no usable rate at full supply. The trace confirms `InvariantRatioBelowMin(0, 700000000000000000)` for its pool; the consumer then rejected `RateProviderFailed()`.

The owner chose SE-owned native liquidation valuation, including quotes beyond executable size, while keeping the rate provider protocol-agnostic. The native BPT target, external-pool adapter and projected-state quotes now share a bounded native withdrawal planner. Executable sizes use at most nine native steps; larger exact-input requests use the native valuation formula directly. Actual Vault/router calls retain the underlying limits and revert atomically. Whole-supply valuation includes locked BPT without making it spendable.

Weighted virtual books are projected through existing family views; stable virtual books use the pool-owned quote interface. Raw balances, rates, aggregate fees, supply and signed offsets advance after each step. The near-total weighted numeric boundary has a conservative mathematical continuation outside the executable range. Successful same-state execution is still required to match the quote exactly.

All five formerly failing tests pass in each of the six affected weighted-hook rows: CommonBufferMultiVaultStablePool, CommonBufferMultiVaultWeightedPool, MixedBufferMultiVaultStablePool, MixedLegWeightedBufferPool, MultiPairStandardExchangeBufferPool and StandardExchangeBufferPool. The 147-test focused run also covers projected-state equality, exact funding, rollback, mixed decimals, small supply and near-total quotes. The seven checked runtime components fit EIP-170.

The broader scope covers 165 Balancer pool test files, 42 SE consumer rows and two native-SY files, including the plain constant-product pool. Its 96 setup failures were corrected by passing the CREATE3 factory into all six transition-facet artifact loaders. Follow-up execution exposed twelve reference-pool reserve assertions that ignored raw-token quantization; these now require the exact representable reserve. Successful preview/execution equality remains unchanged.

Final reconciled result: **2,041 passing tests / 0 remaining failures across 231 suites**. All eight invariant campaigns pass with 256 runs / 16,384 calls each / zero reverts. Forty-eight new regression cases pass, including native-SY full-supply and large funded redemptions and all six factory helpers. All 27 validation source hashes match the final snapshot; seven runtime sizes remain within EIP-170. No pricing decision or SE validation remains pending. See the [implementation report and evidence](BALANCER_SE_LIQUIDATION_IMPLEMENTATION_PLAN_2026-10-10.md).

## Broad-run runtime size gate

Fresh production artifacts from the `runtime-final` build fit the 24,576-byte runtime limit. This is a deployment-size result; functional tests remain a separate gate.

| Formerly oversized component | Runtime bytes |
|---|---:|
| V4 Hookless OutMultiQuery | 21,517 |
| V4 Pons OutMultiQuery | 21,486 |
| V3 FullSpread OutQuery | 23,585 |
| Aerodrome OutQuery | 24,494 |
| Orbital SE | 22,862 |
| Balancer Quad Query | 21,889 |
| Curve Quad LiquidityFacetExt | 24,041 |

The reused V4 input delegates remain close to the limit (24,549 / 24,533 bytes). Aerodrome's query facet also has limited headroom. All supporting implementation/library measurements are recorded in [`runtime-final-bytes.json`](../../.scratch/errors-second-pass-2026-10-09/runtime-final-bytes.json). No compiler-profile or optimizer-policy changes were used.

The broad command selects 286 test roots, covering all **1,505 non-deferred original failures**, plus neighboring tests and new regression controls. The 17 Balancer-hosted DETF failures are excluded. It uses four threads and 128 fuzz runs; each invariant suite retains its configured campaign settings. The source snapshot is recorded in `broad-source-hashes.json`.

## Funding follow-up — complete

- Curve Quad uses its existing external pull library for active funding paths, with checked Permit2 amounts and exact receipts.
- Orbital checks receipts on direct, allowance, signature-batch, flexible and single-asset deposit paths; allowance-transfer casts are checked.
- Eight public-path regressions failed before the production changes. All ten final regressions pass, including two additional related deposit paths and funded positive controls.
- Refreshed production artifacts and **3,738 tests across 119 suites passed**, with no failures or skips. This reruns **772 original failures** affected by the latest changes.
- All **37 measured runtime components** fit EIP-170. No storage, installed selectors, compiler profiles or optimizer policy changed.
- `git diff --check` passed for the funding source and test files; all 49 tracked source/test hashes match the validation snapshot.

Evidence: [before-fix log](../../.scratch/errors-second-pass-2026-10-09/funding-variants-before.log), [completed follow-up log](../../.scratch/errors-second-pass-2026-10-09/funding-after.log), [runtime sizes](../../.scratch/errors-second-pass-2026-10-09/runtime-funding-bytes.json), and [per-test evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json).

The earlier broad run also validated the normal invariant campaigns: DETF accounting **256 runs / 16,384 calls / 0 reverts**; Wings custody **16 runs / 128 calls / 0 reverts**.

R23's 30 failures and broader compatibility validation are complete. The 17 Balancer-hosted DETF failures remain owner-deferred.
