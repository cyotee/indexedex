# Failure diagnosis and resolution plan — 2026-10-09

This report preserves the initial diagnosis of `ERRORS.log` and tracks subsequent fixes separately below. The [triage report](ERRORS_TRIAGE_2026-10-09.md) remains the complete, per-test inventory: **1,522 failures across 316 suites and 288 files**, organized into R01–R22. Group IDs below refer to that inventory. A shared error selector alone is not evidence of a shared root cause.

## Current implementation status — 2026-10-10

**Latest authorized follow-up:** all 17 previously deferred Balancer DETF failures are fixed (15 R02 test corrections and 2 R16 execution guards). Validation: **875 tests passed / 0 failures across 87 suites**. This closes the original 1,522-case inventory across the completed passes. See [implementation report](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md) and [evidence](BALANCER_DETF_REMAINING_ERRORS_EVIDENCE_2026-10-10.json). Earlier deferral statements below describe historical scope.

**Previous follow-up (historical scope):** the owner supplied 15 additional active failures plus the same 17 deferred DETF cases. All 15 active failures are now fixed through test corrections (buffered-output rounding, residual-route expectations, implementation-only selector metadata). The full affected run passes **301 tests / 0 failures across 9 suites**. See [R24 diagnosis and fixes](ERRORS_THIRD_PASS_2026-10-10.md) and [per-test evidence](ERRORS_THIRD_PASS_EVIDENCE_2026-10-10.json).

The earlier broad run validated **all 1,505 then-in-scope original failures**. At that time, **17 Balancer-hosted DETF failures remained owner-deferred**. Broad results: **7,127 passed / 30 failed across 320 suites**; the 30 newly exposed R23 BPT-rate failures were subsequently fixed. Final Balancer validation reconciles 2,041 passing tests / 0 remaining failures across 231 suites, including eight invariant campaigns.

Eight additional Orbital/Curve funding regressions reproduced failures and are fixed. All ten final funding regressions and the full affected batch pass: **3,738 tests / 0 failures across 119 suites**. The production build and all 37 measured runtime sizes pass. Completed second-pass evidence now contains **9,100 distinct passing tests**, including all 30 R23 cases. These retain earlier results unless superseded; this is not a new whole-repository run.

Use [the handoff](ERRORS_HANDOFF_2026-10-10.md) for the current fixed/remaining checklist, [the second-pass report](ERRORS_SECOND_PASS_2026-10-10.md) for changes, and [the second-pass evidence](ERRORS_SECOND_PASS_EVIDENCE_2026-10-10.json) for completed results. The first-pass counts and initial diagnoses below are historical.

## First-pass implementation status (historical)

The [confirmed-error implementation plan](ERRORS_IMPLEMENTATION_PLAN_2026-10-09.md) is complete for its first bounded pass: **all 56 targeted original failures are fixed and validated**. Across the completed production and test-correction runs, **165 distinct targeted tests across 53 suites pass**. This is focused validation, not a rerun of all 1,522 original failures or a declaration of audit readiness.

| Group | Logged failures closed | Current status |
|---|---:|---|
| R01 | 25 | Fixed: contract callers preserve authorization and internal-share inventory assertions |
| R02 | 14 active | Fixed active portion: zero previews with exact execution negatives; 15 Balancer DETF cases remain deferred |
| R03 | 4 | Fixed non-rate portion: live pricing / zero exact-input previews; valid malformed exact-output reverts retained. Three rate-context cases remain open |
| R06 | 1 | Fixed: extension selector ownership and proxy installation verified |
| R08 | 1 | Fixed: insufficient share credit checked before payout pricing |
| R09 | 2 | Fixed logged weighted-hook cases: checked Permit2 narrowing and exact receipts |
| R10 | 3 | Fixed: taxed staking/reward inputs rejected with rollback |
| R11 | 1 | Fixed: executable Morpho redemption cap with next-share boundary check |
| R12 | 1 | Fixed: Aave next-state supply headroom, including treasury accrual and exact rounding |
| R13 | 3 | Fixed: independently measured protocol consumption and exact local-book reconciliation |
| R14 | 1 | Fixed: one native unit of funded face-token dust is booked through a normal operation; subsequent caller cannot consume it |

The [implementation evidence index](ERRORS_IMPLEMENTATION_EVIDENCE_2026-10-09.json) maps every closed original failure to its latest passing result and records exact commands, source hashes, log hashes, and runtime sizes. The production batch passed 95/95. The first substantive test-correction batch passed 59/70; the focused refinement run passed 12/13, and the final Camelot rerun passed 1/1. An earlier command matched zero tests and is explicitly excluded as evidence.

Validation caught a missed inline SE funding path, an overbroad zero-preview expectation, the transfer wrapper's exposed error, and ineffective Camelot deposit seeds. The final implementation corrects all four. The raw weighted liquidity facet is 23,971 bytes after extracting signed-batch funding into the existing 3,727-byte pull library; both are below the 24,576-byte limit. This does not close R17's separate deployment blockers.

For the eight inactive-LP bond variants, execution stops at `TransferFromFailed()` because the preactivation LP payment is unfunded. The tests also establish zero previews, absence from accepted bond tokens, unchanged LP custody, and an inactive reserve. They do not claim a funded LP payment reaches the deeper activation guard. Curve Quad and Orbital cast variants remain open caller-limit investigations.

**At the end of the first pass, 1,466 original failures remained unclosed**, including the 17 owner-deferred Balancer DETF failures; 1,449 remain active. The remaining groups, whole-supply rate work, dust accounting, executable residual planning, runtime partitioning, and vault-specific alignment decisions stay open as detailed below and in the plan. The historical diagnosis/evidence is preserved.

## Scope and intended behavior

The owner's decisions govern the recommendations:

- Rate providers value the **entire share supply**, including projected supply when quoting a projected state.
- Ordinary undeployed dust remains locally accounted for with shares when the outer vault claim is representable. A user deposit that cannot mint one vault-share unit, or a direct BPT deposit that cannot mint BPT, must revert with an explicit minimum error. Withdrawals of a locally held token use that local balance first. Accumulated residual dust is invested when an executable deposit becomes possible.
- Deploy all eligible reserves unless the particular vault explicitly maintains a liquidity sleeve. A fixed small balance is not automatically uninvestable dust.
- The latest owner decision supersedes the earlier discussion requirement: genuinely unattainable alignment must revert with an explicit alignment error at that price and deposit size. Do not loosen holder protection or interpret a positive quote for one amount as proof that a different amount is feasible.
- Balancer-hosted DETFs are deferred: **17 failures** (15 in R02 and both R16 failures). Balancer Standard Exchanges, buffer hooks, and rate providers remain in scope. The initial active scope contained **1,505 logged failures**; **all 1,505 passed the later broad validation run**.
- Existing contract-only pretransfer, exact transfer accounting, funded staking, quote/execution parity, and runtime-size requirements remain in force.

## Evidence and reproducibility

The input log SHA-256 is `eee9ca37b2e651ca797ceecf8e142b56e3373967b96fee12cc4ebd5172d7b95a`. Diagnosis started at HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` in an already modified checkout; HEAD alone does not identify its full source state. Existing production and test edits were preserved.

Diagnostic commands, selected witnesses, environment overrides, raw traces, and runtime-size measurements are under [`.scratch/errors-diagnosis-2026-10-09/`](../../.scratch/errors-diagnosis-2026-10-09/). `manifest.json` records the exact command. The repository artifact helper refreshes runtime deployment artifacts before tests. The selected run uses one fuzz case per selected test; invariant runs/depth are reduced for diagnostic replay, **not release validation**. A short campaign cannot satisfy minimum successful-action coverage requirements by itself.

The completed offline batch reproduced **all 34 selected failing witnesses**. Its shared name filters also exercised neighboring tests: **54 tests across 33 suites, 35 failed and 19 passed**. A separate existing deterministic invariant lifecycle test also reproduced `ZeroAmount()`. These are diagnostic reproductions, not a rerun of all 1,522 logged failures. The [evidence index](ERRORS_DIAGNOSIS_EVIDENCE_2026-10-09.json) records each selected test, original failure, replay result, trace range, runtime sizes, and 61 source hashes; all 61 sources were unchanged at the end of the initial diagnostic pass.

Forge was version `1.5.1-stable` (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`). An initial artifact-refresh command compiled successfully but matched no tests, and a sandbox retry hit a macOS system-configuration crash; neither is counted as test evidence. The subsequent ordinary and offline diagnostic batches completed. The offline log is the canonical trace index; a few detailed references below also identify the ordinary retry log. No production or test source was edited during that initial diagnostic pass.

Evidence labels used below:

- **Source-confirmed:** the offending calculation, guard, or fixture assumption is directly visible in inspected source and explains the logged symptom.
- **Trace-confirmed:** a current replay identifies the failing call and its inputs.
- **Open:** a narrower reproduction or policy decision is still needed. An open item is not a proposed assertion relaxation.

## Resolution order

This is an implementation-effort order, with dependency and security exceptions called out separately.

| Order | Groups | Recommended work | Expected effort |
|---|---|---|---|
| 1 | R01, R02 active, R03, R06, R07, R13, R14 | Correct callers, preview expectations, selector partition assertions, and fixture capabilities | Small, shared test/base edits |
| 2 | R08, R11 | Resolve credit-check precedence and redeem-cap rounding | Small to medium production/test changes |
| 3 | R09, R10 | Enforce exact delivered funding and checked Permit2 narrowing | Medium; security priority ahead of cosmetic test repairs |
| 4 | R05, R12 | Whole-supply rate valuation; Aave capacity at execution state | Medium; numerical and integration tests required |
| 5 | R04, R15, R20 | Dust accounting, executable minimums, local-first withdrawals, and reinvestment | Medium to large across adapters |
| 6 | R17 | Split/reuse oversized production components without altering proxy behavior | Large; deployment blocker |
| 7 | R18 | Repair distinct zero-amount paths, then reclassify the large dependent population | Shared-path investigation first; total effort uncertain |
| 8 | R19, R21, R22 | Vault-specific alignment, invariant witnesses, and restored reentrancy positive controls | Research and dependent validation |
| Deferred | R02 Balancer DETFs, R16 | Separate Balancer DETF redesign | Excluded |

R18 should be investigated early despite its placement by total resolution effort: it accounts for 1,389 logged failures and can prevent security tests from reaching their assertions. R09/R10 deserve early remediation because they demonstrate accounting based on undelivered tokens. R17 prevents normal production deployment.

## Initial diagnoses (historical; current closure above)

### R01 — Positive pretransfer tests use EOAs (25)

**Source-confirmed test implementation defect.** `NativeStandardYieldTarget.redeem` requires a contract caller when `internalBalance_` is true. Tests transfer shares to the vault and then impersonate a named EOA as a supposed router. Naming an address does not give it code, so `EOAPretransferNotAllowed()` is the intended guard.

Use the existing `AtomicPretransferCaller` contract to transfer and redeem in one call. Preserve the prior-inventory and declared-credit assertions, and retain separate EOA rejection tests. Do not remove the caller guard or count previously stranded shares as the current caller's credit.

Sources: [NativeStandardYieldTarget.sol](../../contracts/vaults/standard/sy/NativeStandardYieldTarget.sol), [AtomicPretransferCaller.sol](../../contracts/test/stubs/AtomicPretransferCaller.sol), representative [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol).

### R02 — Preview-return policy mistaken for execution-revert policy (29; 14 active)

**Source-confirmed stale test expectations.** Invalid/inactive preview paths now return zero; tests install `expectRevert` immediately before the preview. They consequently fail before testing whether execution rejects an invalid route or inactive reserve.

Change those preview assertions to exact zero (or an all-zero tuple for `previewBond`). Keep the subsequent execution negative, exact error, and unchanged custody/supply checks. For virtual-buffer routes, a zero quote does not authorize taking assets. The 15 Balancer DETF cases remain deferred.

Sources: [NativeStandardYieldTarget.sol](../../contracts/vaults/standard/sy/NativeStandardYieldTarget.sol), [UniswapV4DetfQueryTarget.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryTarget.sol), [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol).

### R03 — FullSpread tests conflate pricing with immediate settlement capacity (7)

**Source-confirmed stale expectations, with a related production rate-policy issue in R05.** The shared FullSpread tests expect a live preview to reject insufficient local cover or malformed vectors where the intended preview contract returns a price or zero. The rate-context helper also reasons about a one-token sample and avoids quoting the full supply, contrary to the owner's clarified policy.

Follow-up validation refined this diagnosis: malformed **exact-input many-to-one** previews return zero, while malformed **exact-output one-to-many** previews retain `ExchangeOutNotAvailable()`. Their expectations must remain distinct.

Validate pricing at the same pre-state and requested amount independently from whether that route can settle immediately. Preserve actual unfunded/invalid execution rejections. For feasible settlement, assert exact preview/execution equality and actual input/output custody changes. Rewrite rate-context comparisons around whole-supply valuation, after R05 is corrected; do not force production back to sampled rates to satisfy the old test.

Sources: [TestBase_UniswapV4FullSpreadRateContext.sol](../../contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol), [TestBase_UniswapV4FullSpreadG3RouteFunding.sol](../../contracts/test/bases/TestBase_UniswapV4FullSpreadG3RouteFunding.sol).

### R04 — Panic matching hides a dust-policy problem (12)

**Source-confirmed matcher defect; underlying dust behavior also needs resolution.** The shared matrix helper extracts only `bytes4(previewRet)` from a failed preview. Weighted execution returns the complete panic payload; single-hook execution additionally wraps it in PoolManager's `WrappedError`. The failure display `NH{q` is the panic selector, not a different economic error.

The native BPT adapter calls Balancer `BasePoolMath.computeAddLiquidityUnbalanced`. That routine deliberately subtracts the rounded-up old invariant from the rounded-down post-fee invariant using checked arithmetic; its own comment says an input too small to overcome rounding may revert. The single CommonBufferMultiVaultStable replay confirms the old invariant is **2,199,954,397,522,062,696,803**, while the post-fee invariant is **2,199,954,397,522,062,696,742**: subtraction underflows by 61. Thus the matrix's one-unit control reaches a real minimum-deposit boundary, not evidence that normal-sized deposits are broken. The weighted witness also reproduces the panic/matcher failure.

Do not finish this group by merely matching the wrapper. These are one-unit dust controls. Under the clarified policy, inspect why the preview panics, make unsupported underlying deployment a defined non-deployment outcome, and preserve credited local assets/shares where representable. Once intended behavior is implemented, test the exact successful accounting or the specifically justified boundary error. For genuine operative failures, match the complete direct/wrapped error and verify rollback.

Sources: [single matrix behavior](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol), [weighted matrix behavior](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol).

Underlying sources: [BalancerV3PoolStandardExchangeTarget.sol](../../contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol), [BasePoolMath.sol](../../lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol).

### R05 — Rate providers sample part of the book instead of the full supply (8)

**Source-confirmed production policy mismatch; several test assumptions must also change.** Both provider families cap probes at `supply - 1`, usually sample one token, and use half the supply for a small book. Failed probes shrink; zero-output probes grow only within the cap. Fixed-output fixtures therefore produce a doubled normalized rate when the sampled input halves; a quote that becomes payable only at the full supply is never reached. Integer rounding also makes a sampled-and-scaled rate differ from the full-book rate.

Replace sample recovery with a single canonical whole-supply valuation contract. For a live book, value all subject shares; for a projected book, use projected supply and assets from the same state. For a wrapper, convert its entire outstanding supply through the wrapper and value the resulting underlying claim. Normalize only after obtaining the full claim value, with one documented rounding rule. Preserve the explicit initial-rate rule for an empty book.

Some vaults prohibit physically redeeming the last share. A whole-supply **valuation** must still be defined; using `supply - 1` silently changes the owner's intended price. Route valuation through an appropriate full-book quote rather than executing a prohibited full exit or retrying smaller samples. Update amount/call-count tests to the actual full supply and add supply=1, non-unit decimals, large supply, projected state, and wrapper rounding cases.

Sources: [StandardExchangeRateProviderFacet.sol](../../contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol), [WrappedStandardExchangeRateProviderTarget.sol](../../contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol).

### R06 — Selector asserted on the wrong facet (1)

**Source-confirmed test defect.** `previewExchangeIn` belongs to `ERC4626StandardExchangeInFacetExt`, while the test requires it in `ERC4626StandardExchangeInFacet.facetFuncs()`.

Check each facet's actual partition and the installed proxy's union of selectors. Keep a real proxy call to catch missing installation. Do not duplicate the selector on the main facet just to satisfy the old partition assertion.

Sources: [main facet](../../contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol), [extension](../../contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacetExt.sol).

### R07 — The residual fixture no longer reaches its claimed boundary (1)

**Source-confirmed fixture defect.** The H6 scenario leaves six native units but requires more than ten before proceeding. It never reaches the intended retained-residual/retry assertions.

Construct a scenario whose residual is actually uninvestable at that state and later becomes investable. Assert the reason using the relevant quote/execution boundary, not an arbitrary number greater than the current hardcoded floor. R20 separately investigates whether that floor is itself appropriate.

Source: [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol).

### R08 — Exhausted custody reaches a numerical guard before the credit guard (1)

**Source-confirmed error precedence mismatch.** After the first redemption drains the vault, the second call computes assets from virtual assets/shares. That amount exceeds the zero real asset book, so `NumericDomainExceeded()` fires before `takeShares` can report `TransferDeltaInsufficient(requested, 0)`.

The replay does not show reusable credit or a successful second withdrawal. Prefer validating the caller's funded/pretransferred share credit before evaluating the payout, so the exact security error describes the actual invalid input. If the API intentionally gives the domain error precedence, document that and assert it exactly while proving balances and supply remain unchanged. Do not use an arbitrary-revert assertion.

Source: [RebasingAwareERC4626Common.sol](../../contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol), `executeRedeem`, `assetsForRedeem`, and `takeShares`.

### R09 — Permit2 truncates a credited uint256 amount to uint160 (2)

**Source-confirmed production funding defect.** Weighted hook funding casts the requested amount to `uint160` without checking its range. A request of `2**160 + 100 ether` transfers only `100 ether`, while the accounting path uses the large uint256. The tests first prove the normal Permit2 payment succeeds, then expose the mismatch.

Reject values above `type(uint160).max` before any Permit2 call. On both ERC20 and Permit2 branches, measure and require the exact balance increase before issuing shares or updating reserves. Reuse the repository's secure-pull convention. Test maximum representable values, one above the maximum, wrapping values, and fee-on-transfer delivery.

Variant review is necessary: unchecked narrowing also appears in the Curve Quad pull library and Orbital `_pullSeFunding`. This is a source-level variant lead, not a claim that every route is exploitable; inspect each caller's existing limits. The Balancer Quad pull library already demonstrates a checked cast plus balance-delta validation.

Sources: [weighted SE pull library](../../contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPullLib.sol), [raw weighted liquidity target](../../contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookLiquidityTarget.sol), [Curve Quad pull library](../../contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPullLib.sol), [Balancer Quad pull library](../../contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPullLib.sol).

### R10 — TokenStaking credits requested amounts without checking delivery (3)

**Source-confirmed production accounting defect.** `_pullStakingToken` checks transfer success, but not received quantity. `stake` credits the requested stake; `notifyRewardAmount` funds a reward schedule from the requested amount. A 10% transfer tax therefore leaves liabilities funded by only 90% of the credited assets.

Measure receipt and reject anything other than the full amount on both direct and Permit2 paths. Keep the existing untaxed positive control and the exact `TransferDeltaInsufficient` assertions. Verify stake totals, reward schedule, custody, and allowances roll back on failure. Fee-on-transfer support is not a design option under current product law.

Source: [TokenStakingTarget.sol](../../contracts/protocols/staking/token/TokenStakingTarget.sol).

### R11 — Morpho `maxRedeem` loses a share through a floor/floor round trip (1)

**Source-confirmed production limit calculation defect.** `maxWithdraw` floors the owner's shares into assets; `maxRedeem` converts that asset value back to shares with another floor. A small donated asset amount changes the ratio enough that the advertised maximum is one share below a full redemption that execution accepts.

Return the owner's full balance when its previewed redemption is within available cash. When liquidity constrains the answer, solve for the greatest share amount whose actual redemption preview fits the cash bound, using the same integer conversions as execution. Do not blindly replace floor with ceil: test the next-share boundary so the advertised cap cannot exceed executable liquidity.

Source: [MorphoBlueERC4626Target.sol](../../contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueERC4626Target.sol), `maxWithdraw` and `maxRedeem`.

### R12 — Aave supply capacity omits treasury accrual realized during supply (1)

**Source-confirmed state-projection mismatch.** `tokenASupplyCapacity` uses the current normalized income but the stored `accruedToTreasury`. Aave's `executeSupply` first calls `updateState`, which accrues new treasury shares, then validates the cap against the updated treasury and next liquidity index. After the fixture's year of interest, the adapter's headroom can exceed the pool's executable headroom.

The replay confirms normalized income **1.0005625 ray**, 100 scaled aTokens, and a 200-token supply cap. The adapter attempts **99.94375 tokens** and receives `SupplyCapExceeded()`. Its subtraction accounts for indexed existing aTokens but omits the treasury accrual realized by that supply.

Compute capacity against the exact state and scaled-unit rounding used by the pool's next supply, including pending treasury accrual. Preserve the explicit cross-version vault rule that cap-limited principal remains locally held and receives shares. Avoid an arbitrary percentage haircut or swallowing an operative revert. Validate non-unit indices, elapsed interest, reserve-factor zero/nonzero, exact cap, and one unit above the executable boundary.

Sources: [CrossVersionLoopExecutor.sol](../../contracts/protocols/lending/aave/cross-version/CrossVersionLoopExecutor.sol), local Aave port [SupplyLogic.sol](../../lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/SupplyLogic.sol), [ReserveLogic.sol](../../lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/ReserveLogic.sol), [ValidationLogic.sol](../../lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/logic/ValidationLogic.sol), [TokenMath.sol](../../lib/crane/contracts/protocols/lending/aave/v3.6/protocol/libraries/helpers/TokenMath.sol).

### R13 — Requested fixture allowance is treated as actual protocol consumption (3)

**Source-confirmed shared test defect.** The weighted matrix asserts `booked = inputUsed - allow`, assuming every fixture consumes exactly `allow`. EtherFi's `limitCapacity` instead pauses the pool for any argument; the Lido WETH route books on its sleeve regardless of the stake limit; V3 deliberately sets pair-side excess to approximately 99% of `allow`.

Make fixture capabilities explicit: full closure, partial capacity, and intentional sleeve are different scenarios. Reconcile actual caller debit, actual underlying deployment, local book increase, and credited shares. Test the advertised sweep trigger for each family. Do not impose full immediate investment on a documented sleeve route, or describe a paused pool as consuming the requested allowance.

Sources: [weighted matrix behavior](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol), [EtherFi fixture](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_EtherFiFixture.sol), [Lido fixture](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_LidoFixture.sol), [V3 fixture](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol).

### R14 — Camelot fixture does not produce the unpaired reserve being tested (1)

**Source-confirmed fixture prerequisite failure.** Camelot's `limitCapacity` only records intent; it does not constrain the AMM. The scenario leaves zero reserved face tokens, and the test fails its positive-reserve assertion before testing whether an unrelated token can consume that reserve.

Use a real imbalance or exact-out remainder that demonstrably leaves a booked face balance, then exercise the unrelated-token operation and its conservation assertions. Keep the positive prerequisite. Do not change the test to accept zero, which would make its security assertion vacuous.

Follow-up implementation: a funded donor transfers one native unit of face-token dust, an ordinary SE deposit books that prior balance, and a subsequent unrelated-token caller must preserve it. The nonzero prerequisite and conservation assertion both pass. The deposit-only seed attempts did not produce the required face balance.

Source: [SeMatrix_CamelotFixture.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CamelotFixture.sol).

### R15 — One-unit dust enters AMM swaps that cannot produce output (3)

**Production/test contract mismatch; adapter-specific execution diagnosis required.** The shared dust control calls execution when preview succeeds, including when preview is zero. The AMMs then reject a zero effective swap input/output (Camelot insufficient output; Uniswap V2 insufficient input; Aerodrome `InsufficientOutputAmount()`, whose selector is `0x42301c23`). A zero preview alone is insufficient to conclude that the external AMM call is executable.

Implement dust retention at the vault/accounting layer before calling an unexecutable AMM route. Mint the depositor's appropriate claim on the retained asset, include it in subsequent quotes, use it first for same-token withdrawals, and sweep combined balances when deployable. Update the helper's current acceptance of zero shares for a taken deposit to reflect the clarified ownership requirement. See the discussion list for the separate case where even the vault's smallest share unit cannot represent the deposit.

Sources: [single matrix behavior](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol), [weighted matrix behavior](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol).

### R16 — Balancer DETF execution errors (2)

Fixed and verified after the owner's subsequent authorization; see [implementation and validation](BALANCER_DETF_REMAINING_ERRORS_FIXES_2026-10-10.md). Pre-fix diagnosis: Composed exact-output execution continues after a zero unavailable/inactive preview without repeating route and reserve-liveness validation. Unsupported output falls through to `ExchangeOutNotAvailable`; an inactive weighted reserve reaches `MaxOutRatio`. Recommended correction is explicit execution-entry validation, preserving zero-return previews and direct staking conversions. See [the detailed 17-case diagnosis](BALANCER_DETF_REMAINING_ERRORS_DIAGNOSIS_2026-10-10.md).

### R17 — Seven production components exceed the deployed runtime limit (16)

**Artifact-confirmed packaging defect.** The sizes below match the supplied failures and the inspected production runtime artifacts; test contract sizes are excluded. They are runtime sizes, not constructor/initcode sizes.

| Production component | Runtime bytes | Excess over 24,576 |
|---|---:|---:|
| `UniswapV4StandardExchangeBalancerQuadStableBufferHookQueryFacet` | 26,624 | 2,048 |
| `UniswapV4StandardExchangeOrbitalBufferHookSeFacet` | 28,000 | 3,424 |
| `UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacetExt` | 28,288 | 3,712 |
| `AerodromeStandardExchangeOutQueryFacet` | 30,531 | 5,955 |
| `UniswapV4FullSpreadPonsFamilyHookOutMultiQueryFacet` | 30,615 | 6,039 |
| `UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiQueryFacet` | 30,646 | 6,070 |
| `UniswapV3FullSpreadStandardExchangeVaultOutQueryFacet` | 31,843 | 7,267 |

Reduce duplication or partition selectors into existing/new appropriate facets or delegates. Assess delegate storage/caller semantics and guard coverage. Rebuild every affected installed component and deploy through the real registry/factory path; keep selector-union, access-control, quote, and runtime assertions. Raising the test VM's size limit does not resolve production deployability. The selected runtime refresh does not certify every artifact outside its dependency closure.

### R18 — Large `ZeroAmount()` population (1,389)

**Trace-confirmed shared residual-route incompatibility.** `_tryJoinResidual` first invokes `_joinResidualUnbalanced`, which constructs a **one-token** vector and calls the hook's `joinUnbalanced`. In the single-CP hook this is a two-sided proportional deposit: `_deposit` requires both currency amounts to be nonzero, and `_depositWithSeShares` likewise requires both raw and SE inputs. Its preview returns zero for the missing leg. A one-sided residual therefore reaches `ZeroAmount()` even when the residual is much larger than dust.

| Current witness | First failing operation | Residual native units | Evidence in `offline-traces.log` |
|---|---|---:|---|
| `FundedStakingSequenceTest.test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | Cleanup of the 17-token bond; one-sided CP join | 999,001,017 | 17,409–17,524 |
| `RebasingClaimToken_Accounting.test_sameBlockFundedRewardsUpdateGonsButUnsolicitedBackingDoesNot` | Cleanup of the later 40-token bond; one-sided CP join | 999,001,040 | 20,682–20,797 |
| `Adversarial_Reentrancy.test_reentrancy_mint_hitsIsLocked` (R22) | Unlocked control's one-token bond cleanup | 999,001,001 | 18,755–18,872 |
| `UniswapV4Detf_Alignment_CloseD25.test_D25_fundedPrincipalAndRewardsPayOnlyStaking` | Bond cleanup; one-sided CP join | 1,998,002,003 | 43,149–43,264 |
| `CpReserveLiquidityTest.test_currentCollectorRedeemsActualFeeLpWithOwnerAuthorization` | Preparatory bond cleanup, before collector redemption | 19,980,030 | 46,764–46,879 |
| `UniswapV4Detf_Burn_H6.test_smallPrimaryBurn_firstPayableBoundary` | Redemption cleanup; one-sided join of retained DETF shares | 1,389 | 69,040–69,155 |

In these witnesses, funded bond/staking work is reached, but the mandatory cleanup subsequently reverts the whole transaction. The tests therefore never reach the behavior named in their final assertions.

The current source calls `joinResidualAtomic` directly and lets that revert escape. Consequently it never reaches the later single-asset join alternative. The SE-only zero-quote checks cannot detect a missing *hook* join leg, and neither applies to every DETF-share residual. This is an orchestration/capability mismatch, not evidence that funded staking itself should accept a zero principal.

The working diff also shows removal of the old narrow conversion from a zero-output join to `ResidualJoinUnavailable` and its caller handling. That explains a plausible regression mechanism, but restoring catches indiscriminately would conceal real operative failures. Prefer checking the actual join mode's feasibility at the same state, choosing a supported single-asset route when available, and retaining only a proven uninvestable remainder with proper reserve accounting. Any execution inconsistency after a positive quote must still revert and be diagnosed.

**A distinct Orbital dust variant is also trace-confirmed.** `OrbitalReserveLiquidityTest.test_customDonationQuoteIncludesWrappingBeforeReserveJoin` reaches a later residual-loop iteration with **one pair-token unit**. Its underlying ERC4626 SE quotes one share, but the Orbital hook's computed LP output is zero and `_fundFullOrPartial` reverts `ZeroAmount()` before the intended donation slippage error. See `offline-traces.log` lines 52,885–53,289. The outer ten-unit check is not repeated inside `_joinResidualUnbalanced` after it reduces the amount to a newly created remainder. Checking only SE mintability therefore misses the hook's LP minimum. Preflight the complete route on each iteration and retain/account for a genuinely uninvestable remainder; do not weaken the donation's `MinAmountNotMet` test.

The separate deterministic invariant lifecycle also reaches the CP incompatibility with a 13-unit `HostileReentrantShare` residual; see R21. Split the remaining population by first reverting frame. The inventory contains 1,387 direct `ZeroAmount()` failures and two donation tests that expected `MinAmountNotMet` but encountered `ZeroAmount` first. The sampled mechanisms are confirmed; attribution of all 1,389 is not. Ordinary input-zero guards and rounded-to-zero payouts remain independent possibilities in unexamined variants.

Sources: [UniswapV4DetfCommon.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol), `_tryJoinResidual`, `_joinResidualUnbalanced`, `_entryJoinResidualAtomic`; [single-CP DepositTarget](../../contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget.sol), [DepositCommon](../../contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol), [DepositPreviewTarget](../../contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget.sol).

### R19 — Orbital/underlying-SE alignment failures (10)

**Trace-confirmed intake-planning defect in both ALL6 witnesses.** Both affected product combinations contain a FullSpread V4 SE. The MorphoMix combination has Morpho on one leg and V4 on the other, so its name does not imply that Morpho raises this error. The production revert is in the idle FullSpread composition-deposit path.

In `UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6.test_DN21_d2_afterDonate`, the first donation of 13 whole pair tokens succeeds. During the second donation of 3 tokens, the residual sweep offers **24,337 native units** of the other six-decimal pair token. The SE preview returns **12,149,470,229 shares** for that full amount. Orbital's partial join reduces its actual intake to **24,336 units**. The SE preview for that reduced amount returns **zero**, but `_bufferToken` uses zero as its minimum and calls `exchangeIn` anyway. The identical reduced amount then fails `AlignmentNotAchievable()` (`0x4735ea42`).

The MorphoMix ALL6 witness confirms the same mechanism on its V4 leg: **24,371 units → 12,166,470,851 quoted shares**, followed by a reduced intake of **24,370 units → zero quoted shares → execution revert**. See `offline-traces.log` lines 37,812–38,699. This is not a Morpho supply failure.

This is not evidence that the full 24,337-unit deposit is unattainable, nor a contradiction between a positive SE quote and SE execution for the **same amount**. It is a consumer planner failing to preserve feasibility when it rounds the intake, then executing after a zero quote. Correct the consumed-amount plan against the actual SE forward quote and recompute LP issuance from the funded claim. A positive quote for the original budget cannot certify an arbitrary smaller input. Do not assume deposit feasibility is monotonic at every native-unit boundary. Any changed amount must remain within the caller's budget and preserve existing-holder protection.

Evidence: `retry-traces.log` lines 14,253–15,549, particularly the full-amount quote at 14,253/14,318, reduced-amount quote at 15,345/15,422, and execution at 15,428/15,448. The trace's external library argument labels can be incomplete; the public SE call arguments and returns above are decoded directly.

The planner must certify a funded swap, a price movement within 50 bps, a safe liquidity placement, and acceptable share issuance after native-unit placement losses. Its per-leg alignment check requires `10000 * shares * backing >= 9999 * supply * contribution`. That is a specific one-basis-point issuance protection, not a requirement for exact real-number equality. It also rejects a zero contribution on a nonzero backing leg. A bounded search/work-limit failure can return the same invalid plan as a genuinely unattainable allocation. The execution layer then collapses those distinctions into `AlignmentNotAchievable()`.

The preview returns zero for an invalid composition plan. A caller that interprets zero as a reason to execute anyway will still revert. Conversely, if the same-state preview returns positive shares and execution reaches an invalid plan, that is a quote/execution defect to repair before discussing economic policy.

Do not infer that every logged alignment failure requires relaxing protection. Preserve the failing snapshot, deposit token/amount, decimals, book balances/supply, manager lock state, proposed swap and placement, and planner failure reason. Distinguish rounding infeasibility from work exhaustion and projection mismatch. Only then decide the particular vault's policy with the owner.

Sources: [Hookless InBase](../../contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol), [TransitionPlanner](../../contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol), [AnalyticComposition](../../contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol), [ProtectionMath](../../contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol).

Consumer sources: [Orbital Common](../../contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol), `_bufferToken`, `_addLiquidity`, and partial intake calculations; [DepositCore](../../contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol), `_entryJoinUnbalanced`.

### R20 — Investable residual rejected by the fixed native-unit dust floor (2)

**Source-confirmed policy conflict; executable boundary needs confirmation.** `_tryJoinResidual` returns immediately for balances at most ten native units, before asking what those units can buy. In the two P6 V3-SE cases, the test reaches its `residual <= 10` check successfully, then obtains a nonzero LP quote for that residual: 780,744,733,934 or 699,389,631,011 LP units. Consequently, the code deliberately skips these amounts independently of their quoted investability.

The P6_R18 replay identifies the retained balance as **four native pair-token units**, quoting **780,744,733,934 LP units**. It does not execute that residual join, so executable quote parity remains a required follow-up rather than a proven result.

Replace the universal ten-unit shortcut with a route-specific executable minimum/no-progress criterion. Preserve bounded work, accounting of retained balances, and retry after future intake. Before classifying every positive quote as deployable, confirm the same-state execution can honor it; a quote/execution mismatch belongs in the pricing path and must not be hidden by calling the amount dust.

Sources: [UniswapV4DetfCommon.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol), `_tryJoinResidual` and `_sweepDustBody`; [V3 decimal TestBase](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Cp_Univ3Se_Decimals.sol), `_assertNoJoinableDust`.

### R21 — Two invariant failures need separate treatment (2)

**Wings: trace-confirmed campaign coverage failure, not a failed custody assertion.** The replayed one-call sequence is `rebalance()`. `invariant_review_actionWitnessesAndCustody` completes successfully, including custody, supply, liquidation value, and actual pool positions. The failure occurs in `afterInvariant`: `deposits()` is still 1, the setup count, so `assertGt(1, 1, "campaign must add successful deposits")` fails. See `retry-traces.log` lines 15,815–15,907.

A sequence containing only rebalance cannot satisfy a requirement for an additional deposit and withdrawal. The short diagnostic settings are not evidence of full-campaign coverage, but the supplied cached sequence already has that shape. Keep the money-path witness requirement; make successful deposit/withdrawal coverage deliberate in the campaign driver or a dedicated deterministic lifecycle, and evaluate it separately from whether each randomized state satisfies custody invariants. Do not delete the replay or interpret the one-call shrink as proof of a broken vault.

**DETF: coverage failure with a separately reproduced production blocker.** Its cached one-call `cycle` sequence also leaves `invariant_accounting` passing. `afterInvariant` instead fails because `attempted()` is zero against a minimum of eight (`offline-traces.log` lines 20,916–20,931). The handler increments `attempted` before deposit; a reverted cycle rolls back that counter along with the transaction.

The existing `test_deterministicLifecycle` exposes the underlying lifecycle blocker without random campaign coverage: redemption cleanup submits **13 units of `HostileReentrantShare`** to a one-sided CP `joinUnbalanced`, which reverts `ZeroAmount()` (`deterministic-traces.log` lines 8,222–8,339). This is the R18 route incompatibility. Fix that production path before reassessing the campaign. Preserve the eight-cycle/three-actor money-path requirement and make coverage deliberate; a one-call diagnostic campaign cannot establish it. The deterministic trace confirms this lifecycle blocker, while the cached invariant trace itself does not show its handler's inner revert.

### R22 — Reentrancy test fails before the locked attack (3)

**Trace-confirmed dependency on R18 in the base witness.** The unlocked funded one-token bond succeeds through its ordinary funding path, then residual sweeping submits 999,001,001 pair units as a one-sided CP `joinUnbalanced`. That call reverts `ZeroAmount()`, so the low-level positive control returns false. The reentrancy attack has not yet been armed.

Repair the residual join orchestration first, then rerun the base and both decimal variants. Keep the successful unlocked control, the nested `IsLocked` error, and the assertion that the rejected callback cannot spend its payment. This trace is not evidence of a bypassed reentrancy guard.

## Decisions resolved and remaining research

The owner has resolved the original minimum-deposit and alignment questions. Deposits below one vault-share unit or one BPT unit must revert atomically with an explicit minimum error. Genuinely unattainable alignment must revert; ordinary representable deployment dust remains attributed locally. The second-pass implementation follows these decisions, and the focused R04/R15, R19 and R20 witnesses pass. All mapped original cases passed the completed broad validation; current evidence is linked above.

The owner also resolved **R23, full-supply BPT valuation**: keep the generic rate provider unchanged and implement native liquidation valuation in the SE, allowing a quote when the underlying protocol may reject execution at that size. This is implemented and all 30 formerly failing cases pass. Broad compatibility and targeted follow-ups reconcile to 2,041 passing tests with no remaining failures. Six factory library-linking helpers and twelve raw-token-quantization comparison assertions were also corrected and validated. No further pricing decision is needed. See the [implementation plan](BALANCER_SE_LIQUIDATION_IMPLEMENTATION_PLAN_2026-10-10.md).

The additional Curve Quad and Orbital funding variants are **fixed and validated**. Eight regressions reproduced failures before the fixes; all ten final funding regressions pass, along with the 3,738-test affected batch. They require no further product decision.

## Validation required after implementation

Re-run each group's representative witness first, then all mapped variants in the original inventory. For shared production changes, include affected consumers across token orientations, decimals, direct/PoolManager routes, native/ERC20 funding, and projected/live states. Quote parity must compare the same pre-state and amount; invert exact-out quotes with an executable minimal-input boundary, not a tolerance broad enough to hide a changed trade.

Dust validation must cover initial retention with shares, repeated deposits crossing the executable boundary, sweep conservation, local-first same-token withdrawal, and unrelated-token isolation. Numerical limits must test the advertised boundary and the next unit. Security controls need a successful funded control and a specific negative reason. Restore normal fuzz/invariant settings and meaningful successful-action counts for release validation. Size/selector checks must use freshly built installed production artifacts.

The initial diagnostic pass included no production or test fixes. Follow-up remediation is tracked in the implementation status above and its linked plan.
