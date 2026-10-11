# Astra — REQ-C04: hook-zero success sentinel preserves the wrong retention policy

## Finding

- **Title:** Hook preview zero is encoded as a successful no-progress result and then becomes fallback or booked custody.
- **Severity:** Medium.
- **Class:** CODE_DEFECT, reinforced by contradictory test expectations and comments.
- **Origin:** **REQ-C04 / Stage-1 REQ-01 / OD-08**. This is the caller-path obligation left open after the leftover-helper repair, not a new identifier for that historical requirement.
- **Production file:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`.
- **Primary lines:** hook-zero returns at `:603–605,614–615`; loop zero-result breaks at `:565,590`; fallback and eventual full-balance booking at `:531–545`.
- **Impact class:** parent-operation atomicity, dependency-failure policy and residual-accounting conformance. No demonstrated fund loss, theft or insolvency is claimed.
- **Confidence:** High in current control flow, the requirement conflict and the inspected test expectations. Runtime execution and the precise historical edit sequence remain unverified.

## Intended behavior and broken invariant

The intended behavior is specified, not an open preference:

- `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:184` says book-and-wait applies only to a successful **Standard Exchange** `previewExchangeIn` returning zero. A **hook** preview of zero or hook join revert must roll the parent transaction back, without adding a holder-reserve update or paying the amount out.
- The same document's REQ-01 repeats this at `:195,199–202` and prohibits translating preview failure into a zero quote.
- `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md:85–98` retains that origin, requires hook-zero rollback, and explicitly says not to undo `_retainSubSharePairResidual`.

**Broken invariant:** once a residual hook join has been selected and its preview returns zero, the parent must not successfully continue, try a different mode because of that zero, or reach reserve booking as if it had proved a valid SE-zero deferral. A hook zero is not interchangeable with an SE zero, even when retaining custody appears financially conservative.

## Current caller path — facts

All Common references below are to the production file named above.

1. `_tryJoinResidual` first calls `_retainSubSharePairResidual` at `:528`. That helper at `:625–637` uses the actual leftover's SE preview and books the full local balance only after a successful zero. **This helper's repaired predicate is not the problem under REQ-C04.**
2. If the helper does not retain, `_tryJoinResidual` enters `_joinResidualUnbalanced` at `:531`.
3. The join loops call the existing atomic join entry at `:561` and `:586`. The maintenance target forwards to `_entryJoinResidualAtomic` without catching its failure (`UniswapV4DetfMaintenanceTarget.sol:55–57`).
4. Inside `_entryJoinResidualAtomic`, either selected hook preview can return zero. The function immediately returns numeric zero at `:605` or `:615`, rather than reverting. The final result check at `:618` is skipped by those early returns.
5. The loops interpret returned zero as a reason to break at `:565` and `:590`. Breaking does not revert; the functions can return their default false result.
6. Following an unbalanced zero, `_tryJoinResidual` may try the single-asset mode at `:535–539`. If neither mode progresses, it still reaches `_updateReserve` with full local custody at `:543–545`.
7. The enclosing sweep can then complete normally. `_sweepDustBody` processes tokens through this same path at `:508–520`. The public maintenance entry calls `_entrySweepDust`, which calls that body (`UniswapV4DetfMaintenanceTarget.sol:45–48`; `UniswapV4DetfTarget.sol:775–776`).

These facts establish two manifestations of the same defect: **successful alternate-mode fallback after hook zero**, or **successful retention/book update after zero progress**. The second outcome need not occur in every invocation for the first outcome to violate OD-08.

Counterevidence is important: the operative hook calls at `Common:606,616` are already hard calls, and their ordinary reverts propagate. There is no need to add another catch-removal campaign to explain the current defect. It is the explicit zero-as-success return protocol that defeats the specified rollback.

## Root cause — why repairing the retain helper did not repair this path

The retain helper and the hook-join dispatcher implement different decisions. The previous helper repair tightened the **SE admission-to-retention predicate**. It did not change the **hook completion contract** or how callers interpret its return.

The remaining implementation conflates three outcomes:

- A successful SE preview of zero: authorized book-and-wait.
- A successful positive hook join: completed settlement, with ordinary custody synchronization afterward.
- A hook preview of zero: currently encoded as a successful “nothing happened” result, although OD-08 requires parent rollback.

The third outcome is converted into the first outcome's practical effect by the loop breaks, mode fallback and terminal reserve write. Removing the old inverse-quote decision from `_retainSubSharePairResidual` cannot prevent a later, separate hook-zero branch from returning successfully.

### The recurrence bait is explicit

The source does not merely omit a check; it tells the next implementer that the wrong behavior is intended:

- `Common:548–549`: “Try the supported single-asset mode after the proportional mode cannot progress. A zero complete-route quote retains the booked remainder.” This collapses hook-zero and SE-zero policy into a generic “complete-route” concept.
- `Common:543–544`: “Keep an unmintable remainder booked locally for the next sweep” immediately precedes a write reachable after hook-zero failure. A non-progressing hook mode is not the required proof of an unmintable SE leftover.
- `Common:612–613` explains that one-sided proportional joining can be unsupported despite mintable underlying SE shares. That can explain a quote result, but it does not authorize treating the result as a successful fallback signal under OD-08.

**Inference, not a historical attribution claim:** leaving these return values, comments and tests in place makes it easy for a later agent to restore the same behavior when a newly strict test fails. No source history was inspected to establish which edit or agent introduced each site.

## Current tests that reinforce the wrong policy

### 1. Explicit fallback success after zero hook preview

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52–83`:

- The test is named `test_RC06_nonzeroPreview_usesSingleAssetFallback`.
- At `:56` it establishes a **nonzero SE preview**.
- At `:62–65` it establishes zero unbalanced-hook preview and a positive single-asset-hook preview.
- At `:69–77` it expects the alternate join, successful public sweep, LP delivery and remaining-custody booking.

This is direct source evidence of an expectation contrary to OD-08. It is not a test of the legitimate SE-zero retention exception. The proper repair must change this expectation, not weaken the hook-zero check to keep this positive case green.

### 2. Gas/fuzz residual tests expressly accept hook zero as retention evidence

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:25–62`:

- At `:35`, the expected-retention predicate is **SE zero OR hook-preview zero**.
- At `:38–41`, that predicate is used to expect a successful sweep retaining all custody and issuing no LP.
- At `:53–56`, the same disjunction validates remaining custody and a full holder-reserve book.
- `_hookPreviewIsZero` at `:65–72` consults the two hook previews, supplying exactly the prohibited alternative proof.

A test that insists reverting previews are errors but accepts a successfully returned hook zero still misses OD-08. These expectations must be split by the identity of the preview, not preserved as a generic “unmintable complete route.”

### 3. Do not misclassify a legitimate SE-zero positive because it also observes hook zero

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46–60` asserts **SE preview zero first** at `:48–49`, then separately observes both hook previews at `:54–57`. Its full-local-book assertion at `:58` can be valid under the SE-zero exception: production may return from the retain helper before attempting a hook join.

Its text is misleading, however: `:16` describes failed retries retaining booked custody, and `:55` says zero unbalanced LP selects a single-asset retry. Relabel this as SE-zero deferral where that is the actual precondition, and verify that the production hook join path is not entered. Do not turn a valid SE-zero positive into a rollback test merely because the test itself also reads a hook quote.

`UniswapV4Detf_Dust.t.sol:14–48` was also read. It checks funded dust joining and custody preservation without explicitly asserting a hook-zero precondition. No separate defect is inferred from those tests. Search coverage was bounded; no claim is made that every residual test in the repository was exhaustively classified.

## Remediation — remove the zero-success contract and its documentary/test support

This is one repair to the existing hook-join boundary and its consumers, **not another copy of the retain helper**.

1. **Make the existing atomic hook join return positive, validated LP or revert.** In `_entryJoinResidualAtomic`, a zero quote from either selected hook-preview method must cause a hard failure before the operative join. Use the existing error vocabulary consistently; `IUniswapV4DetfSelfCall.ResidualJoinUnavailable` already exists at `interfaces/IUniswapV4DetfSelfCall.sol:7` and is used for incompatible settlement results at `Common:618`. The supplied requirement fixes the outcome, not a new error selector, so selecting the existing suitable error does not require an owner policy decision.
2. **Remove hook-zero-as-no-progress handling from both callers.** The `lpOut_ == 0` branches must not break into a successful return. With the atomic entry guaranteeing positive LP or failure, remove that soft-success interpretation; any retained defensive check must fail hard, not start a fallback or book. Preserve successful positive-join progress handling and bounded iteration rather than redesigning the loop economics.
3. **Keep hook failure out of `_tryJoinResidual`'s success paths.** Neither single-asset fallback nor the final reserve synchronization may be reached as recovery from a hook zero. Do not add an earlier zero-preview probe that skips the failing mode and calls that a repair; it would retain the same forbidden outcome at a different location. Reserve writes for successfully completed settlement and the existing authorized SE-zero deferral are distinct and need not be deleted indiscriminately.
4. **Keep propagation hard through the parent.** Do not catch the new local zero-quote failure, the hook preview's own revert, or the hook join's revert. Earlier approvals, token movement, supply changes and reserve writes in that parent must roll back. No error translation into a boolean deferral or zero LP result.
5. **Remove the misleading policy instructions.** Replace the quoted “zero complete-route” and “unmintable remainder” comments where they imply hook-zero retention with the explicit distinction: SE zero may defer; a selected hook zero fails the parent. Update the existing callback documentation as necessary; its current notice already says residual joining reverts when it cannot mint LP (`IUniswapV4DetfSelfCall.sol:9–11`). There is no need for a new callback, second retention function or copied settlement engine.
6. **Correct the contradictory tests together with the boundary.** Replace the named fallback-success expectation with exact parent rollback. Remove the hook-zero alternative from the gas/fuzz retention oracle. Keep separately funded positive joins and genuine SE-zero retention controls so that hardening one branch cannot be disguised as disabling the whole residual path.

The final unconditional reserve write is part of the observed path, but **deleting that write alone is not a repair**: the parent could still continue after a forbidden hook zero. Conversely, changing only the producer's two early returns while leaving contradictory tests/comments and soft-zero loop handling is an incomplete anti-recurrence handoff. The existing join result must no longer advertise hook zero as an accepted control-flow outcome.

## Required defensive verification in a later authorized session

Use the actual production DETF, hook and SE deployment paths. Do not mock the SUT to manufacture the named condition. The assertions must distinguish:

| Condition reached by the parent operation | Required result |
|---|---|
| Successful SE preview of the actual leftover is zero | Existing retain helper may book the full local balance; no deposit, no caller/fee payout. |
| SE preview reverts | Exact dependency failure propagates; no new reserve book or successful parent continuation. |
| SE preview is nonzero and selected unbalanced hook preview is zero | Parent reverts; no alternate-mode success and no surviving book update. |
| Selected single-asset hook preview is zero | Parent reverts through that existing branch; no silent break or retention. |
| Hook preview is positive but operative join reverts | Failure propagates and all parent changes roll back. |
| Hook preview is positive and operative result matches | Existing funded joining, LP custody and ordinary reserve synchronization remain correct. |

Assert the exact expected error rather than any revert. Capture pre-parent state and verify unchanged local book, held token balances, LP custody, relevant supplies, approvals and recipient balances on rejection. Include a parent path with prior meaningful state changes so the test proves transaction rollback rather than merely that a standalone preview failed. Do not change bond, threshold or vesting policy to create that witness.

The existing nonzero-SE/zero-hook fallback test already identifies the required distinction on production fixtures; its expected outcome must change. Whether every additional fixture can reach every branch is a test-engineering limitation to report, not authority to reinterpret hook zero as success. No test was run in this review.

## What must not change

- **Do not undo or duplicate `_retainSubSharePairResidual` at `Common:625–637`.** Keep actual-amount successful SE-zero preview as its signal and full local balance as its book.
- Do not reintroduce an inverse one-share quote or use a hook quote as proof for that helper.
- Do not add any new catch around preview, join or parent propagation.
- Do not adjudicate the separate supportsInterface probe policy. OD-08/REQ-01 expressly leave that separate site outside this ruling.
- Do not redesign bond, threshold, vesting or residual ownership economics. Do not change unrelated family routes or other remediation items.
- Do not weaken the existing successful-SE-zero tests merely to make all residual outcomes revert.

## Owner decision and limitations

**No owner question blocks this single repair.** OD-08 and REQ-C04 already decide that a selected hook preview of zero rolls the parent back. The fact that another join mode could succeed does not create an exception. Preserving that fallback would require changing the stated requirement; it is not an equally valid implementation of it.

Facts above are current source/test text. The root-cause explanation is a control-flow inference supported by those facts. No execution result, historical edit attribution, complete repository test census or financial loss is claimed. All explicitly supplied input paths were available. No file under `docs/reviews/apex-req-c04-hook-zero/` was read; only this assigned report was created there.

**Stop.** This review does not implement the repair, edit either PRD, authorize implementation, or begin cross-review.
