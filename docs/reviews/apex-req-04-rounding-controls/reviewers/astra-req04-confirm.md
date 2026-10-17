# Astra — REQ-04 independent confirmation

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent source review against the current controlling PRD and plan. No other reviewers' notes or prior peer cross-reviews were read for this confirmation.

## Verdict

**The inspected source implementation is complete against the amended plan; no remaining scoped implementation defect was established.** Both quad deposit previews use isolated zero-aware math, both corresponding execution joins reject zero shares before taking input, the six behavior files enforce their required outcomes and exact SE-share reconciliation, and Orbital uses its installed two-argument preview selector.

There is an important scope correction to the question: **Dual production was edited for this item.** This is explicitly required by the follow-up at `REMEDIATION_PRD.plan.md:11–17` and `REMEDIATION_PRD.md:18–22`, which supersedes the original no-Dual-edit restriction. It is not a deviation from the current amended plan. Weighted, single-CP and Orbital production have no edits in the supplied incremental diffs; I have not independently recomputed a whole-tree baseline comparison to certify the absence of additional changes.

The initial execution was not complete: the report preserves its 17 failures and stop condition. Current source contains the subsequent corrections. Saved follow-up logs record 175 focused passes and 3,642 full-selection passes. **Those are inspected saved results, not an independent rerun.**

## Authority and method

Read the current `REMEDIATION_PRD.plan.md`, controlling `REMEDIATION_PRD.md`, and `EXECUTION_REPORT.md` in `docs/reviews/apex-req-04-rounding-controls/`. The report and its evidence files were treated as claims to compare with source, not as permission to edit or execute anything.

The current PRD expressly distinguishes valid zero-rounded inputs from positive one-unit fixtures. Therefore, accepting the three explicitly specified positive fixtures is not accepting zero-share retention or branching on an observed preview result. The amendment also requires the execution quote substitutions, not merely a zero guard after a strict quote that could revert first.

Repository routing and canonical testing guidance (`CLAUDE.md`, `docs/agent/SKILL_CATALOG.md`, `lib/crane/.claude/skills/crane-testing/SKILL.md`, and `.claude/skills/indexedex-testing/SKILL.md`) were already read directly in this session. This task required source and local evidence inspection, not external library documentation.

## Production verification — current-source facts

Production paths below are relative to `contracts/hooks/uniswap/v4/standardExchange/`.

| Path / lines | Confirmed behavior |
|---|---|
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:283–288,352–376` | Named deposit preview reaches `_quoteSingleJoinExactInPreview`, preserving input classification, inventory conversion, fee, supply and value preparation before calling preview math. |
| Same file, `291–318` | Deadline, recipient, amount and full-book checks precede the quote. Execution now calls the zero-aware quote at 305 and rejects zero at 306, before either direct SE-share intake or face intake. The existing minimum check remains. |
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol:276–324` | Strict unbalanced and single-join functions remain separate. New preview math validates index, supply and fee; zero converted amount returns zero. Positive-input calculation retains the existing formula and tests `nextD <= currentD` before the final unsigned subtraction. Rounded final division may return zero. |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:439–448,507–525` | Named deposit preview preserves inactive/input-zero/token-resolution handling and the existing flexible SE-share branch. The normal face route uses the new quote helper with the original conversion/fee/supply steps. |
| Same file, `451–478` | Normal face-input execution uses the zero-aware quote at 471 and rejects zero with the existing `ZeroAmount()` at 472, before `_pullAmounts` at 476. Deadline, recipient, live-state, input, token resolution and minimum checks remain. The flexible branch still delegates separately. |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol:431–504` | Original strict function remains present with its reverts. The new helper checks supply, fee, index and every reserve before its zero-input return; then handles non-growing pre-/post-fee invariants and zero share division without the former rounding reverts. It does not catch dependency or invalid-reserve errors. |
| `dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol:125–142` | `_swap` now returns `(amountIn, 0)` at 131 for a computed zero sale, before projected buffering and the `DepositExactIn` transition. Its caller retains the zero-leg return `(true, 0)` at 68. This matches the narrow amended Dual repair. |

A source search also confirmed the public quad query targets dispatch `previewDepositSingle` to `_entryPreviewDepositSingle`: Balancer QueryTarget **46–50**, Curve JoinQueryTarget **75–80**. Orbital DepositQueryTarget **69–74** exposes the two-argument preview and dispatches to its entry helper.

**Inference, high confidence:** the normal face-input quad zero-rounding cases now reach the deliberate `ZeroAmount()` execution guard rather than the strict math's earlier rounding rejection. No newly invented selector or broad catch-and-zero was found in these changes. This conclusion is bounded to the named paths and does not certify all stable-invariant inputs or all flexible joins.

## Six behavior files verified

All paths below are under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`.

| Behavior file | Rounding/one-unit checks | Exact-output SE accounting |
|---|---|---|
| `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` | 214–228: successful preview decodes to zero; execution expects encoded `MinAmountNotMet(1,0)`; caller/hook/book unchanged | 248–291 |
| `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` | 299–327: preview zero, failed execution restricted to `InsufficientTokenOut()` or `ZeroAmount()`, unchanged balances/book | 347–390 |
| `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` | 269–293: same required zero/rejection/unchanged-state conditions and sibling selector set | 313–356 |
| `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` | 290–337: explicit default/positive controls; default preview uses two arguments at 318; execution retains six arguments including bytes at 325–326 | 362–401, using `seUT0`, `face0`, `_hookSeShares(0)` |
| `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` | 320–366: explicit default/positive controls; default requires preview zero and exactly `ZeroAmount()` | 386–429 |
| `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` | 269–292: preview zero and exactly `ZeroAmount()`; caller/hook/book unchanged | 312–355 |

At all six share sites, the face-leg SE's `previewExchangeOut(SE shares, face, wantOut)` is captured **before** execution. Logs are recorded around settlement; mint counting filters by the output SE emitter, standard Transfer topic, zero sender and hook recipient. Each equality is:

`before + mintedBack == after + expectedDebit`

This reconciles **net balance decrease plus mint-back** to gross quoted debit. It is not an input-token quote or a mere decrease assertion. The original plan's phrase “burned shares plus any shares minted back” at line 63 is imprecise if “burned” means gross burn; the implementation uses the correct balance identity for the controlling PRD's exact-debit requirement. Do not change its sign to follow that phrase literally.

Funded exact-output delivery, bounded input/refund and code-less-caller rejection assertions remain in the inspected surrounding controls. The supplied incremental diffs remove preview-error echo acceptance and successful zero-share retention, not those surrounding controls.

### Explicit positive fixtures

Direct reads confirm the three overrides, rather than dynamic expected-outcome selection:

- Orbital `UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_RebasingAwareERC4626.t.sol:18–20`: expected LP amount **1**.
- Balancer `decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F6.t.sol:14–16`: **240384615373**.
- Balancer `decimals/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_SimpleYieldERC4626Control_F9.t.sol:14–16`: **240384613**.

The positive helpers assert fixed preview output, matching execution output, exact recipient LP receipt, one-unit caller payment, quoted SE-inventory increase and unchanged face residual. Other fixtures retain the default zero/rejection helper. I have not independently numerically recomputed the two fixed Balancer values; their runtime agreement is recorded in saved evidence.

## Scope and execution evidence

Read both `evidence/implementation.diff` and `evidence/followup-implementation.diff` in full and compared the pertinent hunks with the current sources above. The former lists four quad production files plus six behavior files. The latter lists the two quad cores and Dual quote library plus three behavior files and three positive-fixture files. Combined, that is **five distinct production files and nine distinct test files**, not “three production and six test files” for the entire item; that latter count describes the follow-up increment only.

Neither supplied diff lists weighted, single-CP or Orbital production, nor the excluded non-CP behavior `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`. `static-checks.txt` and `followup-static-checks.json` claim baseline hash comparisons consistent with that scope. These are executor-generated evidence, not hashes independently recalculated here. I cannot certify that no additional current worktree change lies outside these saved diffs. The original no-Dual-edit condition is explicitly superseded; saying all four non-quad families were untouched would be false.

Inspected `followup-focused-command.json` and `followup-full-command.json`: both include the three follow-up production roots and six family test roots. The focused command filters the partial-consumption/one-unit row; the full command has no test-name filter. Saved-log summaries were directly located:

- `evidence/followup-focused.log:1900`: 175 tests passed, zero failed/skipped.
- `evidence/followup-full.log:15119`: 3,642 tests passed, zero failed/skipped, 383 suites.

Also inspected the focused/full summary portions of `followup-results.json`. These corroborate what the report records but do not establish a fresh runtime result or independently authenticate the baseline/source-to-artifact relationship. No shell, hashing, test, build or deployment was performed.

## Astra informational verification gap

- **Title:** Historical untouched-source scope is supported by saved evidence, not independently recomputed.
- **Severity:** Informational; no unauthorized edit is demonstrated.
- **File and line:** `EXECUTION_REPORT.md:22,43,72`; `evidence/followup-static-checks.json:2–4,17`, under this review directory.
- **Intended behavior:** Restrict production changes to the quad repairs and amended Dual zero-sale branch; preserve weighted, single-CP, Orbital production and the excluded test.
- **Broken invariant:** No source invariant is established broken. Independent certification of the complete historical change boundary remains unavailable in this read-only workflow.
- **Impact class:** Auditability / verification uncertainty.
- **Fix direction:** If stronger scope certification is needed, provide an independently verifiable item baseline and current content comparison separating unrelated worktree edits. No code change is indicated by this limitation.
- **Confidence:** High about the evidence boundary; no conclusion that an out-of-scope edit occurred.

## Files examined without a scoped implementation defect

The five production files, six behavior files and three positive-fixture files listed above were directly inspected at their relevant functions. Public query-wrapper signatures/delegations were checked by source search. The controlling PRD, plan, execution report, two incremental diffs, two static-check records, two follow-up command records, result-summary portions and saved-log summary lines were examined as described. No peer review artifact was read. All supplied input paths existed; the assigned output was absent before this write.

**Disposition:** source-level completion confirmed against the amended plan, with the historical scope and no-independent-rerun limitations stated above. No new remediation work is invented. Only this assigned report was created; code, tests, PRD, plan and configuration remain untouched by this reviewer.

I did not run Forge.
