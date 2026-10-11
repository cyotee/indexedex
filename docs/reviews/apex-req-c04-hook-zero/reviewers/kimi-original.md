# Kimi K3 — REQ-C04 root cause and remediation (hook preview of zero books instead of rolling back)

- **Date:** 2026-10-11. Reviewer: Kimi K3. Scope: REQ-C04 only.
- **Controlling requirement:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C04 (:85-98), which keeps the Stage-1 origin: OD-08 / REQ-01 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:184` and `:195-202`.
- Source re-read this pass: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (:490-656). Tests re-read: `UniswapV4DetfLeftoverPreview.t.sol`, `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`, `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:30-61`. No shell, tests, or edits.

## Title

A hook preview of zero is converted to a soft `return 0` inside `_entryJoinResidualAtomic`, so the residual-join ladder treats a mandated rollback as ordinary loop exhaustion and `_tryJoinResidual` books the full local balance.

## Severity

Medium (matches REQ-C04). No demonstrated fund loss; the violated property is parent-transaction atomicity and the exclusive book-and-wait signal.

## File and line

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:604-605` (single-asset mode: `previewJoinSingleAssetExactIn` of zero returns `0`) and `:614-615` (unbalanced mode: `previewJoinUnbalanced` of zero returns `0`).
- The loop exits that consume the soft zero: `:565` and `:590` (`if (lpOut_ == 0) break;`).
- The terminal booking that fires after exhaustion: `:543-545` (`_tryJoinResidual` writes the full local balance to the holder reserve).
- The bait comment: `:548-549` ("A zero complete-route quote retains the booked remainder") and, in part, `:543-544` ("Keep an unmintable remainder booked locally for the next sweep").

## Intended behavior (from OD-08)

OD-08 decision 1 (Stage-1 REMEDIATION_PRD.md:184): "Book-and-wait applies only to a successful Standard Exchange `previewExchangeIn` of `0`. Hook residual joins are hard calls. A hook preview of `0`, or a hook join revert, rolls the parent transaction back. That path does not add a holder-reserve update and does not pay the amount out." REQ-01's acceptance (:199-202) adds: a reverting SE preview is not converted into a zero quote, and tests must assert both outcomes. REQ-C04 restates this without qualification by mode.

## Broken invariant

The exclusive-signal invariant: the only predicate that may turn a leftover into a booked holder reserve is a successful SE `previewExchangeIn` of `0`. Today a second, unauthorized predicate exists: a hook preview of `0` leads — via soft zero, loop break, and fall-through — to the same full-balance booking at `:545`. The parent operation completes and the reserve grows on a path OD-08 says must roll back with no holder-reserve update.

## Root cause — why the RC-06 helper repair left this caller path booking

The previous repair (FIX_PRD RC-06) was scoped to the *signal* inside `_retainSubSharePairResidual` (:625-637): it replaced the one-share inverse quote with the actual-leftover zero preview. That was correct and is confirmed closed. But booking authority in the caller chain has two tiers, and the repair touched only the first:

1. The helper's explicit book, gated on the SE zero preview (authorized).
2. The terminal fall-through book at `:543-545`, which fires whenever the join ladder reports "could not deploy" — with no record of *why*.

The ladder collapses three different failure causes into one boolean. `_entryJoinResidualAtomic` observes the hook preview returning zero and, instead of reverting, returns `0` as if nothing happened (`:604-605`, `:614-615`). The loops (`_joinResidualUnbalanced` :575-598, `_joinResidualCapped` :550-573) read that zero as ordinary no-progress and break (`:590`, `:565`), returning the default `false`. `_tryJoinResidual` then reaches its terminal clause and books the full local balance. So the mandated rollback was never encoded anywhere: the one place that sees the hook zero preview is a self-call wrapper whose design vocabulary treats zero as "skip," and the one place that books treats "skip" as "retain." The in-code comment at `:548-549` then teaches the next agent that a zero quote legitimately retains, which is how the pattern survives review — the recurrence vector is the soft zero plus the comment, not the helper.

## Remediation — remove the bait, do not copy the helper

1. In `_entryJoinResidualAtomic`, a hook preview of zero in either mode becomes a hard revert (using an existing named error surface, e.g. the family's residual-join failure error), not a `return 0`. The revert propagates through the loops, `_tryJoinResidual`, `_sweepDustBody`, and the self-call frame, rolling the parent transaction back with no holder-reserve update. This single change satisfies REQ-C04 bullets 1 and 2: the join revert case already propagates, and the preview-zero case now shares that shape.
2. With preview-zero reverted at the point of observation, the `lpOut_ == 0` break at `:565`/`:590` is unreachable from a preview (a join returning zero LP against a nonzero quote already reverts at `:618`). Remove or re-scope that dead soft-zero handling so "zero means continue" is no longer a readable pattern in this ladder.
3. Rewrite the bait comments: `:548-549` and the terminal clause comment at `:543-544` must state the rule plainly — only a successful SE zero preview of the actual leftover authorizes retention; a hook zero preview is a hard failure; the terminal book exists solely to sync actual custody after bounded-iteration partial progress, a path that is reachable only when every preview was nonzero.
4. Tests: rework the three suites that currently encode the wrong expectation — `UniswapV4DetfLeftoverPreview.t.sol:52-84` (expects continuation into single-asset fallback after a zero unbalanced preview), `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-45,52-56` (`retained_` treats a hook zero preview as authorizing full-custody booking), and `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-61` (asserts both hook previews zero and "entire residual booked") — so that a hook preview of zero asserts parent rollback with unchanged reserves, while the SE-zero-preview retention cases in those suites continue to pass unchanged through the existing helper.

## Impact class

Error propagation / residual-accounting conformance. A state in which the residual cannot be deployed through the hook is committed (booked) instead of rejected. No extraction or loss is established; booked amounts are tokens the DETF actually holds. The harm is that a mandated hard failure becomes silent acceptance, which can bind a parent bond/mint operation to inventory the protocol rule says must abort it.

## Fix direction (prose summary)

Make the hook zero preview a hard failure where it is first observed, delete the now-unreachable soft-zero loop exits, correct the two comments that teach retention-on-zero, and convert the three named test expectations from "books/continues" to "rolls back." One signal, one failure mode, no second helper.

## What must not be changed

- The zero-preview helper `_retainSubSharePairResidual` (:625-637): its SE `previewExchangeIn == 0` signal, full-local-balance write, and non-booking `supportsInterface` probe catch are confirmed correct under RC-06 and stay.
- No new catch anywhere in the chain; a reverting SE preview keeps reverting uncaught.
- `_pairQuoteIsZero` (:641-646) remains the shared SE zero-quote read.
- No DETF bond, threshold, or vesting economics changes; no `beforeSwap` invention; no changes outside this residual-join path.

## Confidence

High on the control flow, the root-cause chain, and the three test citations (all read directly this pass). Medium on one product-design boundary, noted below.

## Owner question blocking a single repair

None blocking. REQ-C04's acceptance bullet 1 is unqualified by mode, so the repair above is fully specified. One consequence the owner should be aware of (not a blocker, flagged for transparency): the ladder tries the proportional mode before the single-asset mode, so a literal reading means a zero preview from the *first* mode rolls the parent back even when the second mode could have deployed the residual — the fallback ladder in `_tryJoinResidual` ceases to survive a first-mode zero preview, and the `test_RC06_nonzeroPreview_usesSingleAssetFallback` scenario becomes a rollback case. If the owner instead intends mode fallback to survive a zero preview and rollback to apply only when the final attempted mode previews zero, REQ-C04 needs a one-sentence scoped amendment; absent that amendment, the plain text controls and the repair above implements it.

**Stop. No cross-review begun.**
