# FullSpread sequential-projection delta gate review

- recommendation: REJECT
- confidence: High for the source-backed blocker below. No numerical quote mismatch or runtime reproduction is claimed.
- reviewer: omo-native-gate-reviewer, task st_01a1b7e3
- date: 2026-11-07
- scope: Receipt 51's three-family unknown-state repair and its relevant callers/tests, not a repeat of the historical implementation audit.

## Original intent and desired outcome

originalIntent: Complete the FullSpread SE-hook accounting plan while preserving the user's clarification: every required genesis leg can be funded with pair tokens or SE shares; ongoing caller-funded single-leg deposits remain supported. Rates price paid preparation, while native components determine issuance against the post-trade book.

desiredOutcome: Sequential views must either use a genuine projected state or explicitly reject an unavailable capability. They must not price later operations using unchanged live SE state after a simulated consumed conversion. Ordinary one-conversion component quotes and actual funded execution must remain positive. No fabricated FullSpread projection interface, provider semantic change, storage-layout change, or weakened positive test is authorized.

userOutcomeReview: Dual and Orbital implement the reviewed guards coherently, and Balancer joins share the new flags correctly. Balancer single-asset exit previews still discard the flag when moving from allocated components to the remaining pool book. This leaves an installed route violating the exact Task 13 rule the repair was intended to close. The green focused receipt does not cover that missing propagation.

## Blockers

### B1 - Balancer single-asset exit loses the unknown-state flags

- violatedCriterion: Task 13 / IS-5. The plan at `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md:488` says: "Never substitute a live state read for a projected post-conversion state." The delta brief additionally requires that unknown-state flags cannot be lost or read through.
- evidencePointer: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:167-186`, especially line 178; `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol:66-70,85-90,123-131,366-380`.
- severity: High, incomplete correctness repair on a public quote path.

`_previewSingleExit` constructs `allocation` and `remaining` with separate `_bookBasket()` calls. Each therefore receives a separate, false-initialized `unprojected` array. At line 178 it aliases only `remaining.states = allocation.states`. It then calls `_previewOutputs(allocation, flags)` at line 181. A consumed ordinary FullSpread redemption sets `allocation.unprojected[i] = true` through `_previewOutputConversion`; it does not change `remaining.unprojected[i]`.

At line 186, `_ratedBasket(remaining)` consequently passes `_basketRate`'s new guard and reads the unchanged live rate because the FullSpread state remains empty. This is the prohibited post-conversion live read. In the supported two-leg fixture, a positive exit to the raw `other` token redeems the buffered leg's allocated shares before selling those pair proceeds into the remaining raw leg. The output branch is raw, so no later output conversion is needed to trigger another unknown-state guard. The source permits the stale-state quote to continue instead of rejecting this capability.

This is installed behavior, not an unused helper. `UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol:32-36` installs the exact-input and exact-output single-exit preview aliases; `UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget.sol:52-74` forwards them to this core. The exact-output sizing loop also calls `_previewSingleExit` at LiquidityCore line 262.

Smallest fix: alias `remaining.unprojected = allocation.unprojected` beside the state-array assignment, before `_previewOutputs`. Add a real FullSpread two-leg regression using a positive LP burn and the raw output leg: the installed preview must reject with `InvalidQuoteState`, while actual exact-BPT-in exit must still pay the requested token and burn only the caller's LP. Retain the ordinary proportional one-conversion preview/execution control. Check the equivalent five-leg and preview aliases through the shared path. No production fix was made by this reviewer.

## Direct review of the delta

### Balancer

The join-side repair is correctly placed: `_previewBasket` aliases both `states` and `unprojected` at UnitsCore lines 185-186. Consumed fallback conversions mark the shared flag; `_basketRate`, `_previewConversionAt`, and `_previewOutputConversion` reject subsequent dependent reads. Sizing probes do not advance state. Component acceptance does not query rates, so the complete proportional share-basket route remains available. Actual assembly calls `_convert`, not the simulated conversion helper, and can read real post-conversion state. The exit-side alias omission above is the unresolved sibling caller.

### Dual

`DepositQuoteLib.sol:108-150` marks consumed, unprojected conversions and guards both later conversions and sizing reads. The conditional before `redemptionFor` mirrors that helper's condition for actually consulting an SE quote, allowing no-conversion component arithmetic to continue. `_swapAmount` and `_swap` reject unknown input state; `_reserve` rejects unknown state when shares require valuation; output redemption also marks the output leg. The same memory Leg objects flow through single-input assembly and exit sequencing. Complete independent per-leg conversion paths do not perform a subsequent dependent read. `Common.sol:302-315,330-357,619-650` executes real conversions, verifies receipts, and uses live state after actual execution. No blocking issue found in this delta.

### Orbital

`ExitQuoteLib.sol:58-134` marks unprojected redemptions/deposits, then immediately invokes `_refresh`, which rejects before reading an SE rate. Raw legs remain independent. The early failure also prevents a later final share-output conversion from reading through a previously unknown state. Prepared in-kind joins price trades before their caller-only conversion stage and do not reuse the exit Leg flag as stored state. No blocking issue found in this delta.

All three added flags are fields in memory quote structs, not additions to a Repo storage layout.

## Regression evidence inspected

`51-sequential-projection-controls.log:2355-2719` reports five suites, 265 counted cases, zero failed/skipped, and `REGRESSION_EXIT=0`. Its opening command builds dependent artifacts before the selected Solar tests. The suite counts reconcile as 1 + 60 + 60 + 65 + 79. Compiler warnings remain in the log; this is not a warning-free claim.

Reviewed substantive controls:

- Dual component tests at lines 25-62: exact capability rejection plus actual positive single-share join and cross-leg exit; complete per-leg share conversion preview/execution parity.
- Balancer component tests at lines 27-60: pair/share unbalanced preview rejection, positive actual joins, and proportional share-basket quote parity; inherited in the N5 adapter. These test joins, not the allocation-to-remaining-book transition in B1.
- Orbital component test at lines 562-578: capability rejection before a real cross-leg exit, actual payout, caller supply burn, preservation of another holder and protocol LP. Native component and ordinary paid-join controls also remain positive in the inspected receipt.

These are actual public-surface tests with FullSpread fixtures, not assertions on a private flag. No tests or builds were run by this reviewer, as required by the task.

`50-final-gates.log` records the earlier default exit 0; that receipt predates this delta. `52-final-gates.log`, when inspected, contained `BUILD_EXIT=0` and `SIZE_EXIT=1`, but no default-suite completion result. The pending default rerun is not counted as a pass. Parent owns final publication. The previously accepted 13 test/vendor size exceptions are recorded in `49-size-classification.md`; no global-green size claim is made.

## remove-ai-slops / programming perspective

Both skills were loaded from `/Users/cyotee/.omo/binary-runtime/5.1.51/plugin/skills/`. The task's read-only scope overrides their cleanup/refactor actions. Solidity has no language-specific reference in the programming skill; its shared correctness, boundary, minimal-change and test principles were applied.

Direct checks covered excessive/useless tests, deletion-only and requested-removal tests, tautologies, implementation-mirroring tests, unnecessary extraction, parsing, normalization, redundant defense and scope drift. The added capability negatives are meaningful behavior assertions paired with positive execution; the ordinary parity controls independently execute the real route. They do not pin the flag or certify a textual removal. No new parsing, normalization, abstraction or provider layer is introduced. The guards are load-bearing capability checks, not generic defensive clutter.

B1 is also a programming root-cause/completeness finding: the shared state model was extended, but a sibling caller copies only the old field. The focused tests provide false confidence if treated as coverage of all sequential Balancer paths. Existing large modules, long signatures, and negative flag naming are maintenance notes, not separate success-criterion blockers or authorization for an unrelated refactor.

The historical `fullspread-se-hooks-20261106-code-review.md` explicitly records a skill-perspective pass and deletion-only/tautological/implementation-mirroring coverage, plus needless complexity. It also explicitly limits its test sample and predates this repair. It does not establish a fresh exhaustive slop check of receipt 51, nor explicitly enumerate every excessive/useless-test and parsing/normalization criterion. This review performs the delta check directly; historical report coverage is not substituted for it.

## Checked artifact paths

Evidence and requirements:

- `.omo/evidence/fullspread-se-hooks-20261106/50-review-brief.md`
- `.omo/evidence/fullspread-se-hooks-20261106/51-review-remediation.md`
- `.omo/evidence/fullspread-se-hooks-20261106/51-sequential-projection-controls.log` (commands, selected output and complete results/footer)
- `.omo/evidence/fullspread-se-hooks-20261106/50-final-gates.log`
- `.omo/evidence/fullspread-se-hooks-20261106/52-final-gates.log`
- `.omo/evidence/fullspread-se-hooks-20261106/49-size-classification.md`
- `.omo/evidence/fullspread-se-hooks-20261106-code-review.md`
- `.omo/evidence/fullspread-se-hooks-20261106/F2-review.md` (explicitly historical)
- `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md` (scope and Task 13)
- `CLAUDE.md`

Production, in full unless marked:

- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol` (lines 1-300)
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol` (conversion/assembly and actual single-join/withdraw sections)
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol` (lines 1-180)
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol`
- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol`

Tests, relevant sections:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_ComponentAccounting.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_ComponentAccounting.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` (fixture topology and binding)

## Exact evidence gaps and limits

- No test/build execution was authorized here; B1 is a deterministic source-flow finding, not a claimed measured payout discrepancy.
- Three LSP reference requests timed out. Literal caller searches and direct source reads were used instead; no fresh LSP-clean claim is made.
- No isolated pre-receipt-51 source snapshot/diff was supplied. Read-only `GIT_MASTER=1 git diff` against HEAD includes extensive older edits and its combined output was truncated. The three current delta production files were read in full; attribution of every historical hunk is not claimed.
- No current notepad path was supplied. The brief and remediation artifact supplied scope and progress.
- No JS eval/toolkit-status tool is available in this session. The evidence/loop directory inspection found only an unrelated older session, so the report uses the specified fallback evidence location rather than inventing a current attempt directory.
- Full default receipt 52 remained pending in the inspected gate file. This is not the reason for rejection; B1 independently violates Task 13.

Only this gate report was written. No implementation, tests, Git state, build artifacts, deployment, or historical report was modified.
