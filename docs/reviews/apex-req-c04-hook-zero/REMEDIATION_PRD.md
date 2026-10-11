# Remediation PRD — hook preview of zero rolls back

- **Status:** DRAFT
- **Date:** 2026-10-11
- **ID:** REQ-C04
- **Origin:** Stage-1 REQ-01 / OD-08. Do not assign a new ID that erases REQ-01.
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11.
- **Inputs:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C04; `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` OD-08; council originals and cross-reviews under `docs/reviews/apex-req-c04-hook-zero/reviewers/`.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ed4b5a1c0ffeQAC0qfU97gIkVq`. Not censored. No resubmission.
- **Other reviewers:** Grok `ses_ed4b57779ffeGmcCiqV4AZKS0r`, MiniMax M3 `ses_ed4b549bbffeL8O0YXyWZIyq0H`, Kimi K3 `ses_ed4b51764ffe7if9IHLJ1F2RPS`. This is not proof by consensus.
- **Authorization:** Writing this PRD does not authorize editing code in this session.

## Required outcome

A hook preview of `0`, or a hook join revert, rolls the parent transaction back. It does not book a new holder reserve. It does not continue into another join mode.

Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`. That helper is already in place and is not this repair.

## Root cause

The last repair changed the signal inside `_retainSubSharePairResidual`. It did not change how a hook preview of zero is returned to the caller.

`_entryJoinResidualAtomic` treats a hook preview of `0` as a successful no-progress result and returns `0` (`UniswapV4DetfCommon.sol:604-605` and `:614-615`). The join loops treat `lpOut_ == 0` as an ordinary stop (`:565` and `:590`). `_tryJoinResidual` then books the full local balance (`:543-545`).

The comments teach the next agent to keep that shape. `:548-549` says a zero complete-route quote retains the booked remainder. `:612-613` says a one-sided proportional join can be unsupported and still continue. Tests that expect the single-asset fallback, or a book, after a hook preview of zero repeat the same lesson.

OD-08 already forbids that translation. A soft zero is not a book-and-wait signal, and it is not permission to try the other mode.

## In scope

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:600-618`, both hook-preview branches.
- The loop stops at `:565` and `:590` that treat a zero LP return as ordinary no-progress.
- Comments at `:543-544`, `:548-549`, and `:612-613` that describe a hook zero as retention or as a reason to try the other mode.
- Tests that currently expect a hook preview of zero to continue or to book. Known sites from the review, to re-read rather than treat as a closed list:
  - `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`
  - `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`
  - Comments in `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol` that describe hook-zero retention. A Standard Exchange zero-preview positive in that file stays a positive.

## Required repair

1. At both hook-preview checks in `_entryJoinResidualAtomic`, a quote of `0` reverts. It does not return `0`. Use the existing `ResidualJoinUnavailable` error unless a test must distinguish this case from a short join. A dedicated error is allowed. A new `catch` is not.
2. That revert is not caught by the join loops or by `_tryJoinResidual`. The parent transaction rolls back. No holder-reserve update from that call is committed.
3. A proportional hook preview of `0` does not fall through to the single-asset mode. A single-asset hook preview of `0` does not fall through to a book. OD-08 does not allow either continuation.
4. Remove the loop branches that treat a zero LP return from this hook join as ordinary no-progress, once that return can no longer occur. Do not replace them with a book.
5. Keep the terminal reserve update at `:543-545`. It is also the custody sync after a join that consumed what it could without a hook preview of zero. Deleting it would drop that sync. The hook-zero path must revert before this line runs. Rewrite the comments above it so they no longer say a hook zero is booked or that the other mode should be tried after a hook zero.
6. Rewrite the tests that expect continuation or booking after a hook preview of zero. They must expect parent rollback and no new holder-reserve update. Keep the tests that expect a successful Standard Exchange preview of `0` to book the full local balance.
7. Do not add a second helper. Do not copy `_retainSubSharePairResidual` into the hook path.

## Acceptance criteria

- A proportional hook preview of `0` reverts the parent. The single-asset join is not called. No holder-reserve update is committed.
- A single-asset hook preview of `0` reverts the parent. No holder-reserve update is committed.
- A hook join revert still rolls the parent back and is not translated into a book.
- A successful Standard Exchange `previewExchangeIn` of `0` for that leftover still books the full local balance of that token, through the existing helper.
- A reverting Standard Exchange preview is not caught and is not booked.
- A join that makes progress and does not see a hook preview of zero still syncs the local reserve at the end of the attempt.
- No new `catch` is added around the hook preview or the hook join.
- The comments named above no longer tell a later agent to retain or to switch modes on a hook preview of zero.

## Non-goals

- Do not change `_retainSubSharePairResidual` or `_pairQuoteIsZero`.
- Do not delete the terminal reserve update at `:543-545` as the repair. The repair is the revert before that line.
- Do not add a `catch` that books, continues, or switches modes.
- Do not redesign DETF bond, threshold, or vesting economics.
- Do not invent a `beforeSwap` guard from the withdrawn claim.
- Do not treat this item as the RC-01 holder or self-call repair. Do not reroute `joinResidualAtomic` in this item.
- Do not claim demonstrated loss.
- Do not deploy or upgrade live instances.

## Verification

Implement only after a separate request. Tests use the production DETF path. They do not mock the DETF. A test that still expects the single-asset fallback after a hook preview of zero is not a pass. Report the commands actually run.
