# Plan draft — hook preview of zero rolls back

- **Status:** input draft only. The coordinator owns the final plan.
- **Controlling PRD:** `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md`.
- **Authorization:** Writing this draft does not authorize implementation. A later session must be explicitly asked to edit code.

## What this repair does

A hook preview of `0` reverts the parent. It does not switch join modes. It does not book. Book-and-wait stays the existing Standard Exchange helper. This draft does not change that helper and does not add a catch.

The re-read found no test that already requires a distinct selector for a short join versus a hook preview of zero. Use the existing `ResidualJoinUnavailable` error. Do not add a dedicated error in this item.

## Production change

In `_entryJoinResidualAtomic`, both hook-preview checks revert when the quote is `0`. They do not return `0`. The unbalanced check is the proportional mode. That revert happens before the single-asset mode is started. The single-asset check, if that mode is reached only after a nonzero proportional preview, also reverts. Do not catch either revert in the join loops or in `_tryJoinResidual`.

Remove the loop branches that treat a zero LP return from this hook join as ordinary no-progress, once that return can no longer occur. Do not replace those branches with a book.

Keep the terminal reserve update at `UniswapV4DetfCommon.sol:543-545`. A join that makes progress and does not see a hook preview of zero may still sync the local reserve there. The hook-zero path reverts before that line runs. Rewrite the comments at `:543-544`, `:548-549`, and `:612-613` so they no longer say a hook zero is booked, retained, or a reason to try the other mode.

Do not change `_retainSubSharePairResidual` or `_pairQuoteIsZero`. Do not copy the retain helper onto the hook path. Do not redesign bond, threshold, or vesting economics. Do not reroute `joinResidualAtomic`. Do not deploy or upgrade live instances.

## Tests, from the re-read

Use the production DETF path. Do not mock the DETF. A test that still expects the single-asset fallback after a hook preview of zero is not a pass.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`

- `test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance` stays a positive. A successful Standard Exchange preview of `0` still books the full local balance.
- `test_RC06_revertingPreview_doesNotBookOrDeposit` stays a negative. A reverting Standard Exchange preview is not caught and is not booked.
- `test_RC06_nonzeroPreview_usesSingleAssetFallback` currently expects a zero unbalanced hook preview to continue into a single-asset join and to book. Replace that expectation. The Standard Exchange preview is nonzero and the proportional hook preview is `0`, so the parent reverts. The single-asset join is not called. No holder-reserve update is committed. Balances, LP custody, and the prior reserve match the state before the sweep.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`

- `_checkResidualSweep` currently treats Standard Exchange quote of `0` or a hook preview of `0` as the same successful retention. Split them.
- A Standard Exchange preview of `0` still completes and books the full local balance. Do not weaken that positive.
- If the proportional hook preview is `0` and the Standard Exchange preview is not `0`, the sweep reverts. It does not enter the deploy branch and it does not enter the retain branch. The single-asset join is not called. No new holder-reserve update is committed.
- The remaining-balance check must not accept a hook preview of `0` as proof that a completed sweep was allowed to keep that remainder. A completed sweep's remainder is still explained only by the Standard Exchange zero preview.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`

- `test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry` stays a Standard Exchange zero-preview positive. The sweep may still complete and keep the booked local balance when that preview is `0`.
- Rewrite the notice at the test and the message in `_assertSelectedAlignmentResidual` that say a zero unbalanced quote selects a single-asset retry or that failed hook retries retain custody. Those sentences must not survive. The book assertion stays only because the Standard Exchange preview is `0`, and the helper returns before the hook join.

## Done when

A proportional hook preview of `0` reverts the parent before the other mode and before `:543-545`. A single-asset hook preview of `0` reverts the parent and does not book. The terminal reserve update is still present. The retain helper is unchanged. The named tests match the split above. This draft was not executed.
