# REQ-C04 — Hook preview of zero still books instead of rolling back

## Title
Hook preview of zero propagates as "no progress" through the residual sweep ladder and reaches an unconditional fallback booking in `_tryJoinResidual`, instead of reverting the parent transaction as OD-08 requires.

## Severity
Medium. Stage-1 REQ-01 / OD-08 origin; the Stage-1 PRD explicitly controls over RC-06's narrowed scope. No demonstrated principal loss was established. The fix is a single revert insertion and the removal of one unconditional `_updateReserve` line.

## File and line
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:600-619` (`_entryJoinResidualAtomic` — the inner hook entry that currently returns `0` on a hook-preview-of-zero at `:605` and `:615`).
- `:524-546` (`_tryJoinResidual` — the caller ladder that absorbs that `false` and books at `:545`).
- `:550-573` (`_joinResidualCapped`) and `:575-598` (`_joinResidualUnbalanced`) — the two loops that interpret `lpOut_ == 0` as "break and continue".
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:53-84` (`test_RC06_nonzeroPreview_usesSingleAssetFallback`) — currently expects hook-preview-of-zero on the unbalanced path to continue to the single-asset path. With OD-08 enforcement, this assertion must revert and the test must assert that revert.

## Intended behavior (OD-08)
A hook preview of `0`, or a hook join revert, rolls the parent transaction back. It does not add a holder-reserve update. Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`. Hook residual joins are hard calls (no translation catches around them).

The PRD's REQ-C04 acceptance criteria restate this: a hook preview of `0` rolls the parent back and does not add a holder-reserve update; a hook join revert still rolls the parent back; a successful Standard Exchange preview of `0` for the leftover may still book the full local balance of that token; a reverting Standard Exchange preview is not caught and is not translated into a book; no new catch is added.

## Broken invariant
`_entryJoinResidualAtomic` (`:600`) returns `0` when its `_hook().previewJoinSingleAssetExactIn(...)` or `_hook().previewJoinUnbalanced(...)` returns `0` (`:605`, `:615`). The two call ladders interpret that `0` as a benign "no progress" signal: `_joinResidualUnbalanced` and `_joinResidualCapped` break out of their `for(; i < 24 && amt_ > 0; )` loops at the `if (lpOut_ == 0) break;` checks (`:565`, `:590`) and fall through to the function's default `deferred_ = false` return. The outer caller `_tryJoinResidual` then proceeds to its last-line unconditional `_updateReserve(IERC20(token_), IERC20(token_).balanceOf(address(this)))` at `:543-545` whenever both loop functions have returned `false`. From the perspective of the parent user operation, a hook preview of `0` therefore reaches a successful `_updateReserve` book and continues — exactly the path OD-08 prohibits. The earlier `return true` paths (`_retainSubSharePairResidual` at `:528`/`:558`/`:583` and `_pairQuoteIsZero` at `:559`/`:584`) correctly handle the SE-preview-of-zero book-and-wait signal, so the SE path is not the bait. The bait is the `_tryJoinResidual` structure that ends in an unconditional `_updateReserve`.

## Root cause: why the previous repair of the leftover helper left this caller path booking
The Stage-1 REQ-01/OD-08 implementation and the RC-06 fix in `FIX_PRD.md` both targeted the Standard Exchange preview path — i.e., `_retainSubSharePairResidual` at `:625-637` and `_pairQuoteIsZero` at `:641-646`. RC-06's text and the PRD's REQ-C04 scope explicitly say the helper is closed against OD-08 (book-and-wait is now correctly gated by the SE preview of `0` only). What was not repaired is the hook path that the residual sweep uses to dump `token` into the hook LP. The hook path lives in `_entryJoinResidualAtomic` and the two `_joinResidualUnbalanced` / `_joinResidualCapped` callers. Its return-value convention (`lpOut_ == 0` means "no progress") was inherited from the pre-REQ-01 source and was never converted to OD-08's "hook preview of `0` rolls back". The current code is consistent with the Stage-1 PRD's accounting for SE-only zero previews; it is inconsistent with OD-08's ruling that a hook preview of `0` rolls the parent back. The bait that survives is the unconditional `_updateReserve` at `:543-545`. A future implementer reading the function will see the same shape again — try the helpers, return true if any one books, otherwise fall through and book — and may not realize that "hook preview of `0`" is a parent-rollback signal, not a no-progress signal.

## Remediation that removes the bait, not a second copy of the helper
This is a single repair at the root cause. It does not duplicate `_retainSubSharePairResidual`, does not introduce a new catch around the SE preview, and does not redesign DETF bond, threshold, or vesting economics.

In `_entryJoinResidualAtomic` (`:600-619`):
- Replace `if (quoted_ == 0) return 0;` (`:605`, `:615`) with a revert. Use the same `IUniswapV4DetfSelfCall.ResidualJoinUnavailable()` revert that the function already reverts with at `:618` when `lpOut_ != quoted_`, or use a new dedicated error like `HookPreviewIsZero()` in the same `IUniswapV4DetfSelfCall` interface. Either is consistent with the existing self-call error surface and does not add a new catch.
- Remove the `if (lpOut_ == 0) break;` checks at `:565` and `:590`. With the hook-zero revert, those checks are dead. The `else { amt_ = after_; }` (`:568`/`:593`) and the halving branches remain to handle the "non-zero LP but no progress" case.

In `_tryJoinResidual` (`:524-546`):
- Remove the unconditional `_updateReserve(IERC20(token_), IERC20(token_).balanceOf(address(this)))` at `:543-545`. With the hook-zero revert in `_entryJoinResidualAtomic`, the only paths that reach the end of `_tryJoinResidual` are: (a) `bal_ == 0` early return at `:526`, (b) `_retainSubSharePairResidual` returned `true` at `:528`, or (c) the balances dropped to zero inside the loops and `_updateReserve` was already called inside the loop at `:532` or `:538`. Removing the unconditional fallback makes "neither mode succeeded" translate to "neither helper returned true and `_updateReserve` was not called" — i.e., no booking. The caller `_sweepDustBody` will then see no booking and may continue to the next token or finish; if the failure was a hook preview of `0`, the new revert in `_entryJoinResidualAtomic` propagates and the sweep reverts the parent before it returns.

The two existing `return true` paths inside `_joinResidualUnbalanced` (`:558`, `:559`) and `_joinResidualCapped` (`:558`, `:559`) are retained. They are the book-and-wait exits via `_retainSubSharePairResidual` and `_pairQuoteIsZero`, both of which are SE-preview-of-zero signals — they are OD-08-compliant and stay.

The `_secureShareDelivery` branch deletion and `delegatecall` self-call repair from REQ-C01 are not touched here.

In `UniswapV4DetfLeftoverPreview.t.sol:53-84`:
- Update `test_RC06_nonzeroPreview_usesSingleAssetFallback` so the `detfInfo.sweepDust{gas: 30_000_000}()` call expects a revert with the chosen hook-zero selector. The earlier assertions on the SE preview and on the single-asset preview can remain (they document why the unbalanced path was the one that reverted). A new positive single-asset-only assertion can be added if the testbase has a hook that does support one-sided proportional joins; otherwise the test family is now limited to the zero-SE-preview book-and-wait assertion and to a synthetic revert assertion that uses a hook-fixture mock.

## Impact class
Error propagation and residual accounting, parent-operation atomicity. A hook preview of `0` currently advances as a successful `_updateReserve` booking that is not authorized by OD-08. A future caller that depends on a hook-zero revert (for example, a downstream module that relies on sweep failure to leave tokens in the vault wallet) would have its expectation violated by the current code. No principal-loss magnitude was established; no third-party theft path was asserted; the impact is conformance, not authorization bypass.

## What must not be changed
- The zero-SE-preview helper `_retainSubSharePairResidual` at `:625-637` is left alone. It already matches OD-08 and the RC-06 fix. No new catch is added.
- `_pairQuoteIsZero` at `:641-646` is left alone for the same reason.
- No catch is introduced around the hook preview. The hook join is a hard call per OD-08. The fix makes it revert; it does not catch it.
- DETF bond, threshold, and vesting economics are not redesigned. The hook join ladder's accounting does not change. Only the return-value convention of `_entryJoinResidualAtomic` on hook-preview-of-zero changes (from `0` to a revert), and only the dead unconditional `_updateReserve` line is removed from `_tryJoinResidual`.
- The Stage-1 REQ-01 OD-08 ruling is not amended. The implementation enforces it.

## Confidence
High in the source re-read: the four-line range `:600-619` contains the only two `if (quoted_ == 0) return 0;` checks in this file, and they are the only path that converts a hook preview of `0` into a "no progress" signal. High that the unconditional `_updateReserve` at `:543-545` is the bait that survives the RC-06 fix. Medium in the test-update scope: a focused sweepDust unit test (`test_RC06_nonzeroPreview_usesSingleAssetFallback`) currently asserts a behavior that OD-08 forbids, and the implementer should update or replace it. There may be other sweepDust tests in `decimals/`, `pons/`, and `prod-se/` TestBase families that exercise the same fixture and assert the same fallback; those were not enumerated in this pass and would need a coordinated update.

## Owner question that blocks a single repair
None. The Stage-1 PRD's OD-01, OD-08, and REQ-01 specify the ruling; the current confirmation pass's REQ-C04 restates it as the controlling acceptance list. The implementer can choose to make `_entryJoinResidualAtomic` revert with the existing `ResidualJoinUnavailable()` selector or with a new dedicated `HookPreviewIsZero()` selector; either keeps the repair on the source-visible path and does not require an owner ruling. If the owner prefers a dedicated selector, that is an implementation choice, not an owner decision.

STOP.