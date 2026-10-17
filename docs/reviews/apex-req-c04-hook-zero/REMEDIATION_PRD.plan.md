# Implementation plan — hook preview of zero rolls back

- **Date:** 2026-10-11
- **Status:** WITHDRAWN 2026-10-15. Do not execute this plan. The owner replaced the preview-and-revert rule. The controlling text is [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). This file remains only as the withdrawn draft.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it.
- **Council input:** Astra, Grok, MiniMax M3, and Kimi K3 each reported no blocking question and wrote a plan draft under `reviewers/`. This file is the coordinator consolidation.

## Law this plan follows

A hook preview of `0` rolls the parent back. It does not book a new holder reserve. It does not switch join modes. A revert is not caught and translated into a book or a retry.

Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`, through the existing helper. Do not change that helper.

## Objective

Make both hook-preview checks in `_entryJoinResidualAtomic` revert instead of returning `0`. Remove the loop stops that treat that zero as ordinary no-progress. Keep the terminal reserve update. Rewrite the comments and tests that teach the old fallback.

## Order

| Step | Work | Why this order |
| --- | --- | --- |
| 1 | Revert on both hook previews of zero | The producer must stop returning a successful zero before the callers are cleaned up. |
| 2 | Remove the soft-zero loop stops | Those stops exist only to consume the return this step removes. |
| 3 | Rewrite the three comments | So the next agent does not restore the fallback. |
| 4 | Rewrite the contradictory tests | A green fallback test is not a pass. |
| 5 | Search sibling residual tests, then run the named suites | The three named files are not a closed inventory. |

## Step 1 — Revert at the hook preview

In `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`, inside `_entryJoinResidualAtomic`:

- At `:604-605`, a `previewJoinSingleAssetExactIn` of `0` reverts. It does not return `0`.
- At `:614-615`, a `previewJoinUnbalanced` of `0` reverts. It does not return `0`.
- Use the existing `ResidualJoinUnavailable` error, already used at `:618`. Do not add a dedicated error. The re-read found no test that must distinguish a short join from a hook preview of zero by selector.
- Do not catch either revert in the join loops or in `_tryJoinResidual`.
- A proportional preview of `0` reverts before the single-asset mode starts. Do not move the zero check earlier only to skip the failing mode and then try the other one.
- Keep the operative joins at `:606` and `:616`, and the quote-match check at `:618`.

## Step 2 — Remove the soft-zero stops

Once the atomic join can no longer return `0` for a hook preview of zero:

- Remove the `lpOut_ == 0` break at `:565`.
- Remove the `lpOut_ == 0` break at `:590`.
- Do not replace either break with a reserve write.
- Keep bounded iteration, amount halving, approval clearing, and the Standard Exchange zero checks that return before the hook join (`:558-559` and `:583-584`).

## Step 3 — Keep the terminal sync, rewrite the bait

Keep the `_updateReserve` at `:545`. A positive join can finish with the loop's default false return and still need that custody sync. The writes at `:532` and `:538` run only when a Standard Exchange zero defers. They do not replace `:545`.

The hook-zero path must revert before `:545` runs. Do not delete `:545` to satisfy this item.

Rewrite only these comments:

- `:543-544`: this syncs actual local custody after a completed join attempt. It is not proof that a hook preview of zero was booked.
- `:548-549`: a selected hook preview of zero is a hard failure. It does not retain the remainder, and it does not authorize the other mode.
- `:612-613`: a zero proportional hook quote is not permission to continue. A nonzero Standard Exchange preview does not override that rollback.

## Step 4 — Tests that currently expect the wrong outcome

Use the production DETF path and the existing TestBase. Do not mock the DETF. Do not weaken a Standard Exchange zero-preview positive.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`

- `test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance` stays a positive. A successful Standard Exchange preview of `0` still books the full local balance and does not enter the hook join.
- `test_RC06_revertingPreview_doesNotBookOrDeposit` stays a negative. A reverting Standard Exchange preview is not caught and is not booked.
- `test_RC06_nonzeroPreview_usesSingleAssetFallback` currently expects a zero unbalanced hook preview to continue into a single-asset join and to book. Replace that expectation. The parent reverts `ResidualJoinUnavailable`. The single-asset join is not called. The prior reserve is unchanged. Held tokens, share supply, and LP custody match the state before the sweep. Rename the test so it no longer says the fallback is the expected path.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`

- Split the retention check that treats a Standard Exchange quote of `0` and a hook preview of `0` as the same successful retention.
- A Standard Exchange preview of `0` still completes and books the full local balance.
- If the proportional hook preview is `0` and the Standard Exchange preview is not `0`, the sweep reverts. It does not enter the deploy branch or the retain branch. The single-asset join is not called. No new holder-reserve update is committed.
- A completed sweep's remainder is explained only by the Standard Exchange zero preview, not by a hook preview of zero.

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`

- `test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry` stays a Standard Exchange zero-preview positive.
- Rewrite the notice and the assertion message that say a zero unbalanced quote selects a single-asset retry, or that failed hook retries retain custody. The book stays only because the Standard Exchange preview is `0` and the helper returns before the hook join.

After those edits, search sibling residual tests, including `decimals/` and `pons/` copies, for a hook preview of zero that is still expected to succeed, continue, or book. Update each hit the same way. Do not treat the three files above as a closed list.

## Step 5 — Build and report

After the production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Wait for the compiler.

Run the leftover-preview suite, the residual-gas suite, and the product-law suite named above. Report the commands actually run, the toolchain, and any test that did not pass. A missing run is not a pass.

## Out of scope

- `_retainSubSharePairResidual` and `_pairQuoteIsZero`.
- A new `catch`.
- Deleting the terminal reserve update.
- A dedicated hook-zero error.
- Bond, threshold, or vesting economics.
- Rerouting `joinResidualAtomic`, or the RC-01 holder repair.
- A `beforeSwap` guard from the withdrawn claim.
- Deployment or live-instance upgrades.

## Done when

- Both hook-preview checks revert on `0` with `ResidualJoinUnavailable`.
- Neither join loop treats that zero as ordinary no-progress or as a reason to switch modes.
- `:545` is still present, and a hook preview of zero never reaches it.
- The three comments no longer teach retention or mode switching on a hook zero.
- The named Standard Exchange zero-preview positives still book. The named hook-zero cases revert and do not book.
- The implementation session reported the commands it ran.

Stop after that report. Do not deploy.
