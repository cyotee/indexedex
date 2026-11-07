# Final Balancer exit-projection delta gate review

- recommendation: APPROVE
- blockers: []
- confidence: High for closure of prior B1 and the scoped delta. This is not a claim that the pending corrected full default run has passed.
- reviewer: omo-native-gate-reviewer, task st_01a1b7ec
- date: 2026-11-07
- scope: The missing Balancer exit-side `unprojected` alias, its regression, and neighboring callers. Previously accepted seven-family/native-component work is not re-audited here.

## Original intent and desired outcome

originalIntent: Complete the FullSpread SE-hook accounting plan while preserving the owner's clarification: genesis requires each required leg funded with pair tokens OR SE shares; ongoing caller-funded single-leg execution remains supported. Rates price preparation trades, not LP ownership.

desiredOutcome: Close Task 13 / IS-5's remaining stale-state preview path. A later dependent quote must use a genuine projected state or reject the unavailable capability. Ordinary independent conversion previews and actual funded execution must remain available. Do not fabricate projection support, change providers or storage layout, or relax gas limits.

userOutcomeReview: The missing propagation is repaired at the allocation-to-remaining-book boundary, before conversion can mark state unknown. Installed exact-BPT-in, exact-token-out and SY preview controls reject the unsupported sequence, while the actual raw-output exact-BPT-in exit still pays and burns the caller's LP. No concrete remaining delta blocker was found.

## Prior B1: closed

- violatedCriterion previously: Task 13 / IS-5, `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md:488`: never substitute a live state read for projected post-conversion state.
- repair evidencePointer: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:178-187`.

`remaining.unprojected = allocation.unprojected` now sits directly beside the existing state-array alias and precedes `_previewOutputs(allocation, flags)`. Both memory baskets therefore observe the same flag array. A consumed ordinary FullSpread redemption marks that array in `UniswapV4BalancerStableLiquidityUnitsCore.sol:123-140`; the later `_ratedBasket(remaining)` reaches `_basketRate`, which rejects the unknown state before consulting the live provider (`:51-70`). The stale read identified by B1 no longer passes through the separate false-initialized array.

Native LSP references for both Basket fields, corroborated by a literal copy-site search, identify two whole-array sharing sites: UnitsCore `:185-186` and LiquidityCore `:178-179`. Both propagate states and flags together. The remaining state references initialize or update individual snapshots; no other whole-array alias omission appeared. LSP references for `_previewSingleExit` identify the exact-input/withdraw aliases and the exact-output sizing loop (`LiquidityCore.sol:251-263`). ExitTarget `:52-78` forwards the public methods; ExitFacet `:32-37` installs them. InQuoteBase `:21-29` routes LP redemption previews to the same exact-input path, and NativeStandardYieldPreviewTarget `:15-17` supplies the SY forwarding call.

The fix is confined to memory quote-state propagation. Actual exact-input execution continues through `_exitSingleAssetFrom` and `_convertOutputs`, using actual conversions and post-conversion storage rather than the simulated flags. Proportional preview performs its independent per-leg conversions without a subsequent rate read. A genuine transition snapshot continues along the existing projected path. Exact-token-out execution calls its preview for sizing, so an unsupported sequential quote also fails before burning or paying; this is explicit capability failure, not a new promise of exact-output support.

## Regression and artifact evidence

The new test is `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol:62-83`, `test_component_sequentialRawExitQuoteRequiresProjectionButExecutionWorks`.

It seeds the real FullSpread-backed hook, takes a positive LP allocation, and checks:

- Proportional conversion preview remains positive.
- Installed exact-BPT-in, exact-token-out and SY previews reject specifically with `InvalidQuoteState`.
- Actual raw-token exit remains positive and the recipient's balance delta equals the returned payout.
- Caller LP and total supply decrease by the requested burn; fee-recipient LP remains unchanged.

The test's `before_.userPairs[1]` is correctly the raw `other` token: `_hbPairs` uses `_hbNativeIndex`, whose index 1 maps to `otherIdx`; the snapshot helper reads those token balances. The N5 contract inherits the same test and initializes five legs. The fixture's two-leg row binds one real buffered leg plus one raw leg; N5 adds a distinct buffered leg and additional raw legs.

`53-balancer-exit-projection-control.log` records dependent-artifact build before Solar test execution. Its results at lines 1987-2163 contain 1 share-output control plus 61 base and 61 N5 tests: 123 passed, zero failed/skipped, `REGRESSION_EXIT=0`. The new test explicitly passes at lines 2036 and 2121. The neighboring one-conversion, funded join, ownership, disable/refund and composed-route gas controls also pass. Counts alone were not used to approve: the regression body, fixture binding, installed selectors and state flow were inspected directly.

Fresh LSP diagnostics returned no diagnostics for LiquidityCore and ComponentAccounting. No tests or builds were run by this reviewer, as instructed. Receipt 53 includes compiler warnings; this is not a warning-free-build claim.

Receipt 52 is historical for this last line: its footer at `52-final-default.log:60984` records 28,409 passing cases, zero failed/skipped, and its gate file records default exit 0. It does not validate the follow-up alias.

At the final evidence inspection, `54-final-gates.log` records `BUILD_EXIT=0` and `SIZE_EXIT=1`, with no `DEFAULT_EXIT`. `54-final-build.log:6` reports successful compilation with warnings. `54-final-default.log` has started but has no observed completion receipt. Its success must not be inferred from receipt 52 or 53; the parent owns publication of its actual completion.

`54-final-sizes.log` retains exactly the 13 negative-margin test/vendor identities and sizes classified in `49-size-classification.md`. The five Balancer facets at lines 1841-1849 fit runtime/initcode limits; the largest listed Balancer runtime is QueryFacet at 17,106 bytes. The accepted earlier 77-product classification is not represented as a newly reproduced exhaustive 77-row audit. Global size exit 1 remains visible, not green. No gas ceiling change occurs in the one-line repair; receipt 53's existing ceiling tests pass. No claim of identical before/after gas consumption is made.

## Direct remove-ai-slops / programming pass

Loaded both skills from `/Users/cyotee/.omo/binary-runtime/5.1.51/plugin/skills/`. Their implementation/refactor instructions do not authorize edits under this read-only review mandate. Solidity has no language-specific reference in programming; its shared correctness, minimal-change, boundary and test principles were applied.

The added alias is necessary shared-state propagation, not a wrapper, extraction, parser, normalization layer, speculative fallback or redundant validation. It fixes the lost-state boundary rather than adding a caller-specific rejection. No new provider, storage field, public API or dependency is introduced by this delta.

The regression is not deletion-only, requested-removal coverage, a tautology, or an assertion of internal implementation. It exercises real installed calls and independently checks token/LP effects. Positive execution and the ordinary preview make blanket rejection detectable. Inheriting it for N5 covers a separately required topology without copying the test. No useless/excessive test cluster or new production complexity was found in this delta. The combined test has several preview calls before one real exit; this is a bounded capability-versus-execution scenario, though its first failed assertion can mask later assertions. That is a diagnostic-granularity note, not a failed success criterion.

The historical code-review report explicitly records a skill-perspective check and deletion-only, tautological and implementation-mirroring test coverage, plus needless production complexity. It also explicitly limits its test sample and predates this correction; it does not enumerate every excessive/useless-test or parsing/normalization criterion. The second gate report explicitly covers all those delta criteria. Neither report substitutes for the direct check above. Historical oversized modules, long signatures and negative flag naming do not justify unrelated restructuring in a one-line correctness gate.

## Exact evidence gaps and nonblocking notes

- Corrected full default receipt 54 is pending at inspection. This approval closes B1; it is not the parent's full-run completion receipt.
- The Git diff against HEAD contains the older LiquidityCore rewrite, not an isolated second-review snapshot. The current source and prior B1 report agree on the repaired location; attribution of every historical hunk is not claimed. The newly added test was read directly; it did not appear in the tracked-file diff.
- No mutation/revert experiment or independent test execution was authorized. Regression sensitivity is supported by the source flow and the observed real-surface receipt, not a reviewer-run pre-fix failure.
- The added test preserves the existing fee-recipient balance but does not explicitly arrange a nonzero protocol holding. Existing passing ownership/fee controls remain relevant; this narrow test alone is not proof of every fee configuration.
- No current notepad path was supplied. The brief, remediation report and prior gate provided scope and progress.
- No JS eval/toolkit-status tool is available. The user's explicit sole permitted output path is used; no attempt-directory value is invented.

## Checked artifact paths

Read completely:

- `CLAUDE.md`
- `.omo/evidence/fullspread-se-hooks-20261106/50-review-brief.md` (including original goal, clarification and QA matrix)
- `.omo/evidence/fullspread-se-hooks-20261106/51-review-remediation.md`
- `.omo/evidence/fullspread-se-hooks-20261106-delta-gate-review.md`
- `.omo/evidence/fullspread-se-hooks-20261106-code-review.md`
- `.omo/evidence/fullspread-se-hooks-20261106/49-size-classification.md`
- `.omo/evidence/fullspread-se-hooks-20261106/52-final-gates.log`
- `.omo/evidence/fullspread-se-hooks-20261106/54-final-gates.log` (current two-line state)
- Both skill `SKILL.md` files named above.
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitTarget.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookExitFacet.sol`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookInQuoteBase.sol`
- `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_ComponentAccounting.t.sol`

Read relevant sections or searched output, not full-file audits:

- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol:1-430`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:1-170`
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/HookComponentAccountingBehavior.sol` (bootstrap, snapshot and fee/ownership controls)
- `docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md:470-517`
- `.omo/evidence/fullspread-se-hooks-20261106/53-balancer-exit-projection-control.log` (commands, compilation and complete test results/footer)
- `.omo/evidence/fullspread-se-hooks-20261106/52-final-default.log` (completion footer)
- `.omo/evidence/fullspread-se-hooks-20261106/54-final-build.log` (opening/compiler result)
- `.omo/evidence/fullspread-se-hooks-20261106/54-final-sizes.log` (all negative-margin rows, Balancer facets and failure diagnostic)
- `.omo/evidence/fullspread-se-hooks-20261106/54-final-default.log` (opening, pending)

Read-only Git evidence: `GIT_MASTER=1 git diff --no-ext-diff --unified=2 --` followed by the LiquidityCore and ComponentAccounting paths above. No Git write occurred. Only this report artifact was written; production, tests, earlier reports and build artifacts were not modified by this reviewer.
