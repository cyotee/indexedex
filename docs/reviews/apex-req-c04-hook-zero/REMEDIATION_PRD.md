# Remediation PRD — DETF residual join does not preview

- **Status:** CLOSED, 2026-10-16, by owner clarification. The ruling below is the requirement. The preview-and-revert plan is withdrawn and was not executed. This close is not a claim that the source was edited.
- **Date:** 2026-10-15
- **ID:** REQ-C04
- **Origin:** Stage-1 REQ-01 / OD-08. Do not assign a new ID that erases REQ-01.
- **Review target:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`, `_entryJoinResidualAtomic`.
- **Owner ruling, 2026-10-15:** This ruling replaces the 2026-10-11 draft that kept the hook preview and reverted on a quote of `0`. Do not implement that older shape.
- **Authorization:** Writing this PRD does not authorize editing code in this session.

## Required outcome

This residual join calls the hook join. It does not preview first. A hook join revert, including a revert from the underlying Standard Exchange deposit inside that join, reverts the DETF call. Nothing in this sequence catches that revert, books a reserve from it, or starts the other join mode after it.

The hook does not keep the dust. Dust that is too small for the Standard Exchange vault to mint stays on the DETF through the existing `_retainSubSharePairResidual` helper. That helper is not this repair.

## What is wrong now

`_entryJoinResidualAtomic` previews, and if the preview returns `0` it returns `0` without calling the join (`UniswapV4DetfCommon.sol:604-605` and `:614-615`). The underlying vault never sees the deposit, so it cannot revert. The caller treats that `0` as a stop (`:565` and `:590`) and can try the other mode. `_tryJoinResidual` can then book the local balance (`:543-545`).

The preview is also passed in as `sharesMin`, and line `:618` reverts unless the live join returns that same count. That is a second calculation of the same deposit. The owner rejected that cost and rejected a special zero check.

## Required repair

In `_entryJoinResidualAtomic` only:

1. Delete both preview calls: `previewJoinSingleAssetExactIn` and `previewJoinUnbalanced`.
2. Call `joinSingleAssetExactIn` or `joinUnbalanced` directly, with the same token, amount, holder, and `block.timestamp + 1` deadline used today.
3. Pass `0` as `sharesMin`. Do not compute another minimum. Do not add a second quote, a helper, or a view call to fill that argument.
4. Delete both `if (quoted_ == 0) return 0` lines.
5. Delete `if (lpOut_ != quoted_) revert ResidualJoinUnavailable()`. There is no quote to match. Accept the share count the join returns, including `0`.
6. Do not wrap either join in `try` or `catch`. A revert from the hook, or from the Standard Exchange deposit the hook calls, reverts this DETF call. Do not translate it into a returned `0`, a book, or the other join mode.
7. Do not add a new DETF check that a returned `0` must revert. The underlying join is the rejection. A returned `0` is that join's result, not a preview.

Do not change `_retainSubSharePairResidual` or `_pairQuoteIsZero`. A successful Standard Exchange `previewExchangeIn` of `0` still books the full local balance through that helper. A reverting Standard Exchange preview is still not caught.

Do not delete the terminal reserve update at `:543-545` as this repair. A hook join revert never reaches it. A completed join may still sync the local reserve after the attempt. Rewrite the comments at `:543-544`, `:548-549`, and `:612-613` so they no longer say a hook preview of zero is retained or is a reason to try the other mode. They say this sequence joins, and a hook revert ends the call.

## Acceptance criteria

- `_entryJoinResidualAtomic` contains no `previewJoinSingleAssetExactIn` and no `previewJoinUnbalanced`.
- The single-asset branch calls `joinSingleAssetExactIn` with `sharesMin` of `0`.
- The unbalanced branch calls `joinUnbalanced` with `sharesMin` of `0`.
- A hook join revert rolls the DETF call back. The other join mode is not called. No holder-reserve update from that call is committed.
- No new `catch` is added around either join.
- No new check reverts because the join returned `0`.
- `_retainSubSharePairResidual` is unchanged. A successful Standard Exchange preview of `0` still books. A reverting Standard Exchange preview still reverts.
- The named comments no longer teach a hook-preview fallback.

## Tests

Rewrite tests that expect a hook preview of zero to continue, to switch modes, or to book. They must expect the join to be called with no preceding preview, and a hook join revert to roll the DETF call back with no reserve update. Do not mock the DETF. Keep tests that expect a successful Standard Exchange preview of `0` to book through the existing helper.

Known sites to re-read, not a closed list:

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`
- `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`
- Comments in `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol` that describe hook-zero retention. A Standard Exchange zero-preview positive in that file stays a positive.

## Non-goals

- Do not add a preview back, including as a zero check that reverts.
- Do not pass a nonzero `sharesMin` computed by this function.
- Do not change the hook join signature.
- Do not catch a revert to retry, to switch modes, or to book.
- Do not change `_retainSubSharePairResidual`.
- Do not redesign the halving loops, bond, threshold, or vesting economics.
- Do not reroute `joinResidualAtomic`.
- Do not claim demonstrated loss.
- Do not deploy or upgrade live instances.

## Withdrawn

The 2026-10-11 repair is withdrawn. Do not revert on a hook preview of `0`. Do not keep the preview in order to fill `sharesMin`. Do not keep the exact quote match at the old line `:618`. `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.plan.md` follows that withdrawn repair and must not be executed.

## Verification

Implement only after a separate request. Report the commands actually run. A present assertion is not a pass.
