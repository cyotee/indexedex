# Implementation plan: Uniswap V4 Hookless SE — Aperture-Inspired Analytic Swap Refactor

- **PRD:** [UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md](UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md)
- **Created:** 2026-10-04
- **Status:** ready for implementation

This file is the execute artifact. The implementing session should be given **this path**. Implementors follow this plan and the PRD; they do not invent requirements. Writing or reading this plan does not authorize execution. A separate implementation task must name this path before any file other than this plan and the PRD cross-link is changed.

## Objective

Replace Hookless idle exact-input deposit composition amount refinement with one bounded, core-compatible segment walk and one analytic integer candidate, certified by the existing source-exact V4 forward quote, placement, and share rules. The owner removed Gate M on 2026-10-04. It is not a limitation and does not block replacing `TransitionPlanner._composition`.

## In scope

- Independently authored analytic coefficient, root, traversal, and certification libraries.
- A provenance record for the no-source-reuse decision.
- Stage 1 tests against real V4 core, unchanged production quote/placement/share components, and an independent reference.
- Replace the body of `TransitionPlanner._composition` so execution, ordinary preview, and `quoteTransition` share that planner. Gate M is not required.
- Stage 2 regression and matched-state gas evidence on the locked corpus.

## Out of scope

- NAV, oracle issuance, idle internal constant-product admission, wings, or a second analytic route beside the canonical deposit.
- Copying Aperture `OptimalSwap.sol`, Aperture `SwapRouter.sol`, or `@aperture_finance/uni-v3-lib` source.
- Changing `_maintenance`, public holder-repair search, Orbital `_faceForClaim`, `_invertBufferForEffective`, `zapSplitWad`, Pons sources, hooks, routers, storage layout, DFPkg wiring, or facet selectors.
- New exact-output inversion, nested PoolManager unlock, live deployment, migration, or deletion.
- Raising `via_ir`, optimizer runs, gas limits, runtime-size limit, or Foundry fuzz/invariant runs.
- Claiming clean-room status. Prior research access remains recorded.

## Decisions (locked)

| ID | Decision |
|----|----------|
| D1 | Implement the math independently under BSL-1.1. Do not vendor or transliterate Aperture or `uni-v3-lib` source. Aperture commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e` changed to GPL-2.0-or-later on 2026-07-01; this tree's Hookless sources are BSL-1.1. Reuse only Crane `Math`, existing V4 `SwapMath`, `TickMath`, `ProtocolFeeLibrary`, `StateLibrary`, and the unchanged Hookless `Quotes`, `Inventory`, and `Protection` libraries. |
| D2 | Keep `TransitionPlanner._composition(Types.Snapshot memory, Quotes.Params memory, uint256) public view returns (Types.Plan memory)`. Stage 2 replaces its body only. `InventoryMath._composition(Snapshot)` remains the ratio helper and is not the swap planner. |
| D3 | Production composition evaluates one floored in-domain root, then one `Quotes._tryForward` certification, then the existing `_safePlacement` path already used by `_compositionCandidate`. No amount bisection, no endpoint trials at `0` and `credit`, and no neighbor stencil. |
| D4 | Coefficient arithmetic uses the PRD expansion cleared to integers. Signed coefficients are a sign flag plus `Types.Uint2048`. Overflow of limb 7 is `Unrepresentable`, not a wrap. |
| D5 | Root conversion floors. An out-of-domain root is rejected. It is not clamped to `0` or `credit` and then accepted. The initial policy has no +1 correction. Adding one requires revalidation. It does not reopen Gate M. |
| D6 | Discovery core steps, bitmap word reads, and certification core steps each have a separate ceiling of 64. Placement evaluations have a ceiling of 3. These are evaluation ceilings taken from the existing `Quotes.MAX_CORE_STEPS` envelope and the current target / target-1 / current placement checks. They are not a claim that 64 has been measured sufficient. |
| D7 | Stage 2 maps analytic domain, root, and representability failures to existing `AlignmentNotAchievable`. It maps work-limit failure to existing `QuoteWorkLimit`. No new external error is added. |
| D8 | Projected transition quotes pass `ProjectedPoolOverlay`. When `useOverlay` is true, discovery reads no PoolManager bitmap, tick, slot0, or liquidity. Live reads cannot overwrite overlay fields. |
| D9 | The mandatory corpus is the named cases in this plan, version `hookless-analytic-corpus-v1`. Fuzz seed `uint256(0xA4E0000000000001)` and the configured 16 fuzz runs are additional only. |
| D10 | A required positive case is discharged only by a certified success, or by a completed reference that proves no protected solution exists. `unknown` discharges nothing. |
| D11 | Stage 2 performance passes only when every successful comparable composition call uses no more gas than the frozen baseline on both cold and warm runs, nested totals do not exceed their frozen baselines, and both remain within the existing 31,000,000 and 32,000,000 consumer ceilings. No percentage speedup is required. A capped or failing baseline has no speedup denominator. |
| D12 | Changed deployed runtimes must be <= 24,576 bytes. Do not change `foundry.toml`. |

## Work order

### Step 1: Record provenance and baseline identities

- **Files:** create `docs/plans/records/UNISWAP_V4_HOOKLESS_APERTURE_PROVENANCE.md`.
- **Do:** Record IndexedEx git revision, `foundry.toml` `solc = 0.8.35`, `optimizer_runs = 1`, `via_ir = false`, and the exact Crane V4 library paths reused. Record Aperture commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`, `uni-v3-lib` tag `v3.0.3`, BUSL change date `2026-07-01`, and GPL-2.0-or-later. State the locked choice: independent implementation, no source copy, no clean-room claim. Record that research read those sources on 2026-10-03.
- **Tests:** none.
- **Done when:** the memo exists, names D1, and grants no legal clearance beyond the selected non-reuse.

### Step 2: Add the pure analytic math library

- **Files:** create `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.sol`.
- **Do:** BSL-1.1 library. No production file imports it in this step. Implement:
  - `enum Failure { None, Degenerate, NegativeDiscriminant, OutOfDomain, Unrepresentable, ZeroLiquidity, EmptyBook }`
  - `struct Signed2048 { bool negative; Types.Uint2048 magnitude; }`
  - `struct SegmentInput` with `uint160 sqrtPriceX96`, `uint128 poolLiquidity`, `uint128 ownedLiquidity`, `uint24 lpFeePips`, `uint16 protocolFeePips`, `uint256 incumbentIn`, `uint256 incumbentOut`, `uint256 callerInRemaining`, `uint256 callerOutAccumulated`, `bool zeroForOne`.
  - `struct Candidate { uint256 swapIn; Failure failure; }`
  - `function _candidate(SegmentInput memory) internal pure returns (Candidate memory)`
  - Combine fees with `ProtocolFeeLibrary.calculateSwapFee`. `phi` numerator is the selected directional protocol pips; denominator is `1_000_000`. Do not multiply the forward quote by `phi`.
  - Reject unless `sqrtPriceX96 > 0`, `poolLiquidity > 0`, `ownedLiquidity <= poolLiquidity`, protocol pips `<= 1_000_000`, combined fee `< 1_000_000`, both incumbent legs `> 0`, and `callerInRemaining > 0`.
  - Compute the PRD `A`, `B`, and `C` after clearing `L`, `1_000_000`, and the Q96 denominator. Use `Math.mul512` and limb arithmetic. Do not use `unchecked` wrapping for coefficient construction.
  - `A == 0 && B == 0`: `Degenerate`.
  - `A == 0 && B != 0`: one linear floor division.
  - Otherwise compute `B^2 - 4AC` in `Signed2048`. Negative result is `NegativeDiscriminant`.
  - Floor square root is digit-by-digit long square root in this library, named `_floorSqrt2048`. Do not import a new sqrt dependency.
  - Two nonnegative roots: select the smaller root inside `(0, callerInRemaining]`. None in that interval is `OutOfDomain`.
  - Return the floored raw `swapIn`. Do not add 1.
- **Tests:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticSwapMath.t.sol`.
- **Done when:** both directions, `rho` in `{0, interior, 1}`, zero and nonzero protocol fee, linear degeneracy, negative discriminant, and limb overflow have explicit passing tests. The test reference recomputes coefficients with a separate test-local expansion. It does not call `_candidate` to obtain expected coefficients.

### Step 3: Add bounded traversal and one-candidate certification

- **Files:** create `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol`.
- **Do:** Library function:
  - `function _plan(Types.Snapshot memory, Quotes.Params memory, uint256 credit, ProjectedPoolOverlay memory) internal view returns (Types.Plan memory, Work memory, Failure)`
  - `struct TickOverlay { int24 tick; int128 liquidityNet; uint128 liquidityGross; }`
  - `struct ProjectedPoolOverlay { bool useOverlay; uint128 activeLiquidity; uint160 sqrtPriceX96; int24 tick; uint24 lpFee; uint24 protocolFees; TickOverlay[] ticks; }`
  - `struct Work { uint32 discoveryCoreSteps; uint32 bitmapWordReads; uint32 certificationCoreSteps; uint32 placementEvaluations; }`
  - Require `state.idle`, `book.supply > 0`, and `credit > 0`. Otherwise return `EmptyBook` and an invalid plan.
  - Copy the snapshot before mutation. Call `Inventory._collect` once on the copy.
  - Walk only in `params.zeroForOne`. Commit each completed segment's `SwapMath` input to caller and incumbent prefix state. Pool `L` and owned `l` update separately. Own position boundaries remain active even when aggregate `liquidityNet` cancels.
  - `useOverlay == true`: iterate the supplied ascending tick array only. Do not call `StateLibrary` or PoolManager. Each overlay tick increments `bitmapWordReads` by 1 and manager word reads by 0.
  - `useOverlay == false`: read slot0 once for fee pips not already supplied, then read bitmap words through the existing V4 bitmap/tick libraries. Each actual word read, including an empty word, increments `bitmapWordReads`.
  - Stop discovery at the first in-segment candidate. Certify that amount with exactly one `Quotes._tryForward`. Incomplete fill is rejection, not a smaller accepted fill.
  - After a filled quote, apply the attribution already in `TransitionPlanner._compositionCandidate`: incumbent fee growth, caller credit exclusion, 50 bps price impact on price rather than sqrt price, placement loss, zero-contribution rejection, `ConstantProduct._sharesForDeposit`, and 1 bp alignment. Placement uses `_safePlacement` and counts at most the current, target, and target-minus-one evaluations already performed there.
  - Counters above 64 discovery steps, 64 bitmap word reads, 64 certification steps, or 3 placement evaluations return `Failure` work-limit and `plan.valid == false`.
  - Set `plan.workflow = Composition`, `plan.refinements = 0`, and `plan.evaluations = 1 + placementEvaluations` on the certified plan.
  - Do not call `TransitionPlanner._composition` or `_maintenance`.
- **Tests:** `UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticTraversal.t.sol` and `UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticCertification.t.sol` in the same analytic test directory.
- **Done when:** empty-word, zero-liquidity, initialized-boundary, own-versus-external crossing, and overlay-precedence tests pass. A live read after a supplied overlay fails the test. Certification matches one real PoolManager swap on an identical PoolManager state for both directions.

### Step 4: Add the test-only executor and independent reference

- **Files:**
  - create `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/test/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticExecutor.sol`
  - create `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/test/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticReference.sol`
- **Do:** The executor is not a facet, DFPkg, or vault dispatch target. It deploys through the existing test PoolManager setup, holds local inventory, opens a real full-range position, executes the selected negative-`amountSpecified` exact-input swap, then calls the unchanged placement component. It records backing, fee checkpoints, and modeled shares. Expected values come from the reference and from PoolManager deltas, not from a second call to `_plan`.
  - The reference, for `credit <= 4096` and one active segment, tries every raw `swapIn` from 0 through `credit` inclusive. It classifies `feasible`, `infeasible`, or, if it does not finish that closed interval, `unknown`.
  - A planted witness is a corpus-recorded `swapIn` that the reference certifies. The planner is not given that amount.
  - Reference search cost does not change the production 64-step ceiling.
- **Tests:** executor settlement tests in `AnalyticCertification.t.sol`.
- **Done when:** production files do not import either test helper, and one both-direction executor case shows PoolManager debt/receivable signs, protocol/LP fee split, and share flooring without calling `_plan` for the expected numbers.

### Step 5: Freeze and run the mandatory corpus

- **Files:** create `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticCorpus.sol`.
- **Do:** Encode corpus version `hookless-analytic-corpus-v1` and seed `uint256(0xA4E0000000000001)`. Required cases, each a named test, are:
  - Positive: token0-to-token1 and token1-to-token0; sleeve wad `0`, fee-oracle default, and `1e18`; protocol fee `0` and nonzero; LP fee `0` and nonzero, including the zero-LP-fee protocol branch; prior earned fees nonzero; one core step; at least two initialized ticks; external liquidity nonzero; decimals 18/18 and 6/18.
  - Positive planted witnesses for the multi-step and mixed-decimal cases, with the witness `swapIn` stored in the corpus and withheld from the planner.
  - Negative: `credit == 0`, `supply == 0`, `idle == false`, nonzero hook, amount above `uint128(type(int128).max)`, price move above 50 bps, discovery step 65, bitmap word read 65, negative discriminant, and `Uint2048` overflow.
  - One outside-corpus fuzz witness, if found, is appended to this file with a disposition of `supported-regression` or `outside-supported-domain`. It is not deleted to make the run pass.
- **Tests:** the corpus file itself.
- **Done when:** every required positive case either certifies or has a completed reference result of `infeasible`. No required positive case uses `unknown`. Every reference-confirmed feasible miss fails the run.

### Step 6: Analytic test run

- **Files:** analytic libraries and their tests. A production edit is allowed. Gate M is removed and is not a diff check.
- **Do:** Run the analytic tests. A change to `TransitionPlanner.sol` does not fail this step and does not stop the plan.
- **Tests:**

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic
```

- **Done when:** the command exits 0, or the same analytic tests have already passed under `forge test`. A corpus miss or work-limit escape is a test failure to fix. It is not a Gate M stop.

### Step 7: Record Stage 2 measurements

- **Files:** create `docs/plans/records/UNISWAP_V4_HOOKLESS_APERTURE_STAGE2_BASELINE.md`.
- **Do:** Gate M does not require this step to finish before integration. If `TransitionPlanner.sol` is already edited, record that the pre-change baseline was not frozen, then measure the integrated planner. Record cold and warm `gasleft` deltas, quote count, core steps, and success or failure for:
  1. Idle exact-in, one step, 18/18, default sleeve, zero protocol fee, token0 in.
  2. The same with token1 in.
  3. Idle exact-in, 6/18, nonzero protocol and LP fee, nonzero earned, token0 in.
  4. The same with token1 in.
  5. Idle exact-in crossing one initialized tick, both directions.
  6. `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`.
  7. `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol`.
  - Record pre-existing failures separately. Do not repair them in this step.
- **Tests:** the two consumer paths above plus one local gas test added only under the analytic test directory that calls the unchanged production vault.
- **Done when:** the measurement file exists. Do not stop before Step 8.

### Step 8: Replace production composition dispatch

- **Files:** modify `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol`.
- **Do:** Replace the refinement loop in `_composition` with a call to `AnalyticComposition._plan` using a live overlay (`useOverlay == false`). Preserve the function signature. On analytic `Failure` other than work-limit, revert `AlignmentNotAchievable`. On work-limit, revert `QuoteWorkLimit`. On success, return the certified plan with `refinements == 0`.
  - Leave `_compositionCandidate` available only if the new body still needs its attribution sequence. Do not call it inside a search loop.
  - Do not change `_maintenance`, `_directOut`, `_closedPlacement`, or `_safePlacement`.
  - Do not change `InBase.sol` or `InQueryTarget.sol` unless the unchanged signature fails to compile. `InBase.sol:269`, `InBase.sol:284`, and `InQueryTarget.sol:167` remain the production callers. `quoteTransition` therefore follows the same planner without a new Orbital interface.
- **Tests:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/QuoteExecutionParity.t.sol` and `TransitionLifecycleClosure.t.sol`.
- **Done when:** identical-state preview, transition quote, and execution return the same swap amounts, shares, and rejection. `refinements == 0` on composition. A maintenance case still reports its own repair refinements when the existing repair loop runs.

### Step 9: Close Stage 2 consumers, size, and performance

- **Files:** no new production source. Update `docs/plans/records/UNISWAP_V4_HOOKLESS_APERTURE_STAGE2_BASELINE.md` with the after-change measurements. Create `docs/plans/records/UNISWAP_V4_HOOKLESS_APERTURE_STAGE2_GATE.md`.
- **Do:** Refresh artifacts, then run the locked commands below. Compare each successful workload with the Step 7 baseline under the same compiler, fresh artifacts, start state, caller, funding mode, and cold/warm condition. Report composition gas, maintenance gas, and outer consumer gas separately.
  - Run `forge build --sizes` and record every changed Hookless facet, delegate, and package runtime. Fail the gate above 24,576 bytes.
  - Pre-existing consumer failures stay named. A new failure, a reference-confirmed feasible miss, or a gas increase on a successful comparable call is a failure to fix or report. Do not weaken a protection or raise a cap. Do not stop because Gate M was removed.
- **Tests:**

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/FullSpreadConsumerBurnGates.t.sol \
  --test-root test/foundry/spec/protocols/dexes/uniswap/v4/pons/FullSpreadConsumerPolicy.t.sol
```

- **Done when:** the Stage 2 record says passed, or it names the failing command and evidence. Do not use a Gate M status. Pons sources are unchanged in the diff.

## Acceptance criteria

- [ ] Stage 1 adds no import of the analytic libraries from production dispatch, facets, DFPkgs, or storage repos.
- [ ] No Aperture or `uni-v3-lib` source is copied. The provenance memo records independent implementation and does not say clean-room.
- [ ] `_candidate` implements the PRD `A`, `B`, and `C` expansion in both directions, with rational fee and liquidity terms cleared before division.
- [ ] Zero-liquidity, empty-book, degenerate, negative-discriminant, out-of-domain, and unrepresentable inputs return the locked failure and no successful plan.
- [ ] The returned composition candidate is one floored root. Production does not evaluate neighboring amounts.
- [ ] Discovery steps, bitmap word reads, and certification steps each revert or return work-limit at 65. Placement evaluation above 3 does the same.
- [ ] Overlay quotes do not call PoolManager for slot0, bitmap, tick, or liquidity.
- [ ] Live quote fee and tick reads do not overwrite a supplied overlay.
- [ ] Exact-input V4 `amountSpecified` passed to PoolManager is negative.
- [ ] Protocol fee is the live directional pips. Combined fee uses `ProtocolFeeLibrary.calculateSwapFee`. Zero hooks do not force zero protocol fee.
- [ ] Certification repeats per-step protocol take and LP growth floors. It does not multiply a quote by `phi`.
- [ ] Caller credit is excluded from incumbent backing. Swap repricing and own LP fees increase incumbent backing, not caller contribution.
- [ ] Required placement loss reduces caller contribution when liquidity increases, and incumbent backing when liquidity decreases.
- [ ] Successful issuance is nonzero and satisfies `10000 * shares * backing >= 9999 * supply * contribution` on every positive leg.
- [ ] Composition price impact uses price, not sqrt price, at 50 bps. The 10 bps execution shortfall guard is not used as preview tolerance.
- [ ] Corpus version `hookless-analytic-corpus-v1` has zero unresolved reference-confirmed feasible misses.
- [ ] No required positive case is accepted on an `unknown` reference result.
- [ ] Gate M is removed. It is not an acceptance criterion.
- [ ] `TransitionPlanner._composition` is the only production composition entry. `InBase` and `quoteTransition` call it.
- [ ] Preview, transition quote, and execution match exactly from the same snapshot.
- [ ] Composition `refinements` is 0. Maintenance retains its existing bounded repair search.
- [ ] Blocked local admission, scalar exit, supported exact-output, native currency, import, dual join/exit, and public maintenance keep their current route behavior.
- [ ] Pons sources are not edited.
- [ ] Successful comparable Stage 2 calls do not exceed frozen baseline gas. Nested calls remain within frozen baselines and the existing 31,000,000 and 32,000,000 ceilings.
- [ ] Changed deployed runtimes are <= 24,576 bytes.
- [ ] `foundry.toml` is unchanged.

## Verification

Run the analytic tests. A production edit does not have to wait:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic/UniswapV4FullSpreadHooklessStandardExchangeVaultAnalyticComposition.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/analytic
```

Run the integrated planner and consumers. Gate M is not required:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/FullSpreadConsumerBurnGates.t.sol \
  --test-root test/foundry/spec/protocols/dexes/uniswap/v4/pons/FullSpreadConsumerPolicy.t.sol
forge build --sizes
```

Default hermetic profile only. Do not set `FOUNDRY_PROFILE=fork` for these gates. Do not delete `out/` or `cache_forge/`.

## Do not

- Do not change files outside the Files lists without a PRD update.
- Do not reopen locked decisions.
- Do not add scope from Out of scope.
- Do not treat Gate M as a stop. The owner removed it.
- Do not repair unrelated consumer failures inside this refactor.
- Do not treat a passing test as economic or security proof beyond the named gate.
