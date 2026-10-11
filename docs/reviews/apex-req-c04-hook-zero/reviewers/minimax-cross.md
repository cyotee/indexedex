# MiniMax M3 — REQ-C04 cross-review

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3 (continuing session per Stage-2 PRD §12.1)
- **Original first pass:** `docs/reviews/apex-req-c04-hook-zero/reviewers/minimax-original.md`
- **Scope of this file:** Bounded cross-review of the three peer originals (Astra, Grok, Kimi). Original is not revised.
- **Method:** Recheck disputed material claims against current source and OD-08. No build, test, or shell.

## 1. The dispute

The question prompt restates two aspects of the dispute:

1. **Mode-fallback survival.** If the proportional hook preview is zero, may the single-asset fallback still run, or must the parent revert immediately?
2. **Terminal reserve update.** Is deleting the unconditional `_updateReserve` at `UniswapV4DetfCommon.sol:543-545` required, or is it sufficient that the hook-zero path reverts before it is reached?

All three peers (Astra, Grok, Kimi) agree on both aspects: parent reverts immediately; the terminal update is not deleted; the bail is broader than the terminal line alone.

My original agreed with the peers on aspect (1) but differed on aspect (2). On (2) I said to delete the unconditional `_updateReserve` at `:543-545`. The peers all keep it for the bounded-iteration no-progress case and only ensure that a hook-preview-of-zero can never reach it. I correct my original below.

## 2. Aspect 1 — Mode fallback survival: I agree with the peers

**Agreement:** All three peers and I agree that the literal REQ-C04 text and OD-08 mandate an immediate parent revert on a hook preview of `0` in any mode. The current code at `UniswapV4DetfCommon.sol:604-605` (single-asset preview) and `:614-615` (unbalanced preview) returns `0` instead of reverting, which the loops at `:565` and `:590` interpret as a no-progress break, which `_tryJoinResidual` then absorbs at `:543-545`.

Kimi flags this as a possible owner question: "If the owner instead intends mode fallback to survive a zero preview and rollback to apply only when the final attempted mode previews zero, REQ-C04 needs a one-sentence scoped amendment; absent that amendment, the plain text controls and the repair above implements it." None of the peers record such an amendment. I agree with Kimi's reading: the plain REQ-C04 text and OD-08 control. The mode fallback does not survive.

**Effect on the existing test:** `test_RC06_nonzeroPreview_usesSingleAssetFallback` at `UniswapV4DetfLeftoverPreview.t.sol:53-84` currently encodes the fallback expectation. It must be updated to expect a parent revert. Per REQ-C04 acceptance criteria 1 ("A hook preview of `0` rolls the parent back and does not add a holder-reserve update"), that test changes from a positive to a revert assertion.

**Effect on the public hook dispatcher:** `_entryJoinResidualAtomic` at `:600-619` becomes a hard-fail point. The hooks it dispatches to (`_hook().previewJoinSingleAssetExactIn`, `_hook().previewJoinUnbalanced`, `_hook().joinSingleAssetExactIn`, `_hook().joinUnbalanced`) are already hard calls from the public sweep maintenance entry (`UniswapV4DetfMaintenanceTarget.sol:55-57`, as cited by Astra; the public path through `UniswapV4DetfTarget.sol:775-776` calls `_entrySweepDust`, which calls `_sweepDustBody`, which iterates tokens and SE shares through `_tryJoinResidual`). Astra is right that no new catch is needed to explain this — the existing revert at `:618` for `lpOut_ != quoted_` already shows the hook-join revert propagates through the call ladder. The fix is to convert the two `if (quoted_ == 0) return 0;` checks at `:605` and `:615` into reverts, using the existing `IUniswapV4DetfSelfCall.ResidualJoinUnavailable()` error (already defined in the self-call interface and already used at `:618`) or a new dedicated `HookPreviewIsZero()` selector in the same interface. Either keeps the repair on the source-visible path. No owner decision is required to choose between the existing and a new selector; that is an implementation choice.

## 3. Aspect 2 — Terminal reserve update: I correct my original

**Correction.** My original said: "Remove the unconditional `_updateReserve(IERC20(token_), IERC20(token_).balanceOf(address(this)))` at `:543-545`."

The peers all keep this line. Their reasoning, which I now accept:

- After the hook-zero revert in `_entryJoinResidualAtomic`, the fall-through at `:543-545` is no longer reachable in the hook-zero case. A revert propagates through `_joinResidualUnbalanced` / `_joinResidualCapped` → `_tryJoinResidual` → `_sweepDustBody` → the public caller.
- The fall-through is still reachable for a different case: 24 iterations of `_joinResidualUnbalanced` followed by 24 iterations of `_joinResidualCapped`, each returning `lpOut_ > 0` but no actual progress (`after_ >= before_`, the halving branch keeps reducing `amt_` until the loop exits). This is a "bounded-iteration no-progress" case, not a hook-preview-of-zero case.
- OD-08 governs the hook-preview-of-zero case specifically ("A hook preview of `0`, or a hook join revert, rolls the parent transaction back"). It does not govern the no-progress case. The no-progress case is governed by the loop economics that the PRD's "Do not redesign DETF bond, threshold, or vesting economics" non-goal preserves.

Kimi's wording is the most explicit: "the terminal book exists solely to sync actual custody after bounded-iteration partial progress, a path that is reachable only when every preview was nonzero." Grok says the same in different words: "A hook preview of `0` must not reach that line." Astra's "Keep hook failure out of `_tryJoinResidual`'s success paths. Neither single-asset fallback nor the final reserve synchronization may be reached as recovery from a hook zero" reads the same way: the terminal line is preserved as long as hook failure does not reach it.

Removing the line is therefore not the repair, and removing it could be characterized as a redesign of the no-progress stash behavior, which the PRD's non-goal forbids. I withdraw that portion of my original.

**What remains to be done in `_tryJoinResidual`** to remove the bait without removing the legitimate behavior:

- Leave `:543-545` in place.
- Rewrite the comment at `:543-544` ("Residuals belong to the reserve. Keep an unmintable remainder booked locally for the next sweep; never donate it to the hook without LP") so that it does not describe the hook-zero case as a retention event. The line documents the bounded-iteration partial-progress stash. A reader must understand that the line is not reached on a hook preview of `0`.
- Rewrite the comment at `:548-549` ("Try the supported single-asset mode after the proportional mode cannot progress. A zero complete-route quote retains the booked remainder.") so that it no longer collapses the hook-zero signal and the SE-zero signal into one "complete-route" concept. The single-asset fallback is reached when the unbalanced loop exits without making progress on a positive preview; it is not reached on a hook preview of `0`.

These two comment rewrites, together with the `_entryJoinResidualAtomic` revert and the dead `if (lpOut_ == 0) break;` removal at `:565` and `:590`, complete the source-visible removal of the bait. A future agent reading the function after the fix sees: the helper book-and-waits on the SE zero preview (unchanged); the join loops try each mode up to 24 iterations and propagate a revert on hook preview of `0`; the loops are reached only when the SE preview was nonzero; the terminal book is reached only when the loops exhausted positive-preview iterations without making progress. There is no path in the function that retains custody on a hook preview of `0`.

## 4. The bait is broader than I said

My original called the bait "the unconditional `_updateReserve` at `:543-545`." The peers identify more components of the bait:

- The `if (quoted_ == 0) return 0;` checks at `:605` and `:615` (the producer's soft-zero contract).
- The `if (lpOut_ == 0) break;` checks at `:565` and `:590` (the consumer's soft-success interpretation).
- The comment at `:548-549` that teaches "zero complete-route" as a fallback concept.
- The comment at `:543-544` that documents the terminal book as "unmintable remainder" without distinguishing the bounded-iteration case from the hook zero case.
- The comment at `:612-613` that explains a one-sided proportional join being unsupported.
- The tests at `UniswapV4DetfLeftoverPreview.t.sol:53-84`, `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-45,52-56,65-72`, and the residual sweep tests in the `prod-se/` and `decimals/` TestBase families that encode the same expectation.

A future implementer restoring the old behavior after a stricter test fails would find any one of these and re-introduce the same violation. The repair must touch all of them, not just the producer's `return 0`. I now agree with the peers on this scope. My original identified the producer and the terminal book but missed the comments, the consumer's soft-success interpretation, and the three test sites.

## 5. Remediation I still support

The repair is one repair, at the root cause, not a copy of `_retainSubSharePairResidual` and not a redesign of the residual accounting.

1. In `_entryJoinResidualAtomic` (`UniswapV4DetfCommon.sol:600-619`), replace `if (quoted_ == 0) return 0;` at `:605` and `:615` with a revert. Use `IUniswapV4DetfSelfCall.ResidualJoinUnavailable()` (already in use at `:618`) or a new dedicated `HookPreviewIsZero()` selector in the same interface. The two branch conditions collapse into a single revert point at the producer, matching the existing `lpOut_ != quoted_` revert at `:618` in shape.
2. In `_joinResidualUnbalanced` (`:575-598`) and `_joinResidualCapped` (`:550-573`), the `if (lpOut_ == 0) break;` checks at `:565` and `:590` become dead code. Remove them so that "zero means continue" is no longer a readable pattern in this ladder. Preserve the `if (amt_ > before_) amt_ = before_;`, the `if (amt_ == 0) break;`, the halving branch, and the bounded iteration. Their separation is preserved; only the soft-success interpretation is removed.
3. In `_tryJoinResidual` (`:524-546`), leave `:543-545` in place. Rewrite the comment at `:543-544` so it no longer describes the terminal book as a hook-zero retention event. Rewrite the comment at `:548-549` so it no longer collapses the hook-zero signal into the "complete-route" concept. The terminal book continues to fire for the bounded-iteration no-progress case, which OD-08 does not address.
4. Update the three test sites that encode the wrong expectation:
   - `test_RC06_nonzeroPreview_usesSingleAssetFallback` at `UniswapV4DetfLeftoverPreview.t.sol:53-84` — expect a parent revert with the chosen hook-zero selector instead of a successful sweep through the single-asset fallback.
   - `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-45,52-56,65-72` — the `retained_` predicate currently treats hook-preview-of-zero as authorizing full-custody booking. Split the predicate by preview identity: SE-preview-of-zero still authorizes booking through `_retainSubSharePairResidual`; hook-preview-of-zero must assert parent rollback.
   - `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-61` — its full-custody booking assertion follows an SE-preview-of-zero. Keep that assertion (it is correct under OD-08). Correct the test's prose where it implies a hook-preview-of-zero authorizes the fallback (`:16`, `:55`); the prose is bait.
   - The repetition in `prod-se/`, `decimals/`, and `pons/` TestBase families was not enumerated in my first pass. The implementer should sweep these for the same expectation and update them.
5. Rewrite the comment at `:612-613` ("Test this complete mode: a one-sided proportional join can be unsupported even when the input can mint underlying SE shares.") to make clear that an unsupported join is a hook-preview-of-zero signal that reverts the parent. It is not a fallback signal.

## 6. What must not change (carried over from my original)

- `_retainSubSharePairResidual` at `:625-637`. Its `previewExchangeIn == 0` signal and full-local-balance write are confirmed correct under RC-06 and stay.
- `_pairQuoteIsZero` at `:641-646`. The shared SE zero-quote read stays.
- No new catch anywhere in the chain. A reverting SE preview keeps reverting uncaught.
- DETF bond, threshold, or vesting economics are not redesigned. The hook-join ladder's accounting does not change. Only the return-value convention on hook-preview-of-zero changes (from `return 0` to a revert), and only the now-dead soft-zero loop exits and the misleading comments are removed.
- No `beforeSwap` guard is invented from the withdrawn claim.
- The Stage-1 REQ-01 OD-08 ruling is not amended. The implementation enforces it.
- `_entryJoinResidualAtomic`'s existing `if (lpOut_ != quoted_) revert ResidualJoinUnavailable();` at `:618` is preserved.

## 7. Confidence

High in the control flow, the root-cause chain, and the three test citations. Medium in the breadth of the test-update scope: `prod-se/`, `decimals/`, and `pons/` residual sweep tests were not enumerated in either pass; the implementer should sweep these families for the same expectation. The mode-fallback survival question is closed by the literal REQ-C04 text; no owner amendment is required. The terminal-book deletion question is closed: the line stays for the bounded-iteration no-progress case.

## 8. Owner question that remains

None. OD-08 and REQ-C04 require an immediate parent revert on a hook preview of `0`. The terminal `_updateReserve` at `UniswapV4DetfCommon.sol:543-545` is preserved for the no-progress case, which OD-08 does not address. The implementer may choose between the existing `ResidualJoinUnavailable()` selector and a new dedicated `HookPreviewIsZero()` selector in the same `IUniswapV4DetfSelfCall` interface. That is an implementation choice, not an owner decision.

**Stop.**