# Plan draft — REQ-C04 hook preview of zero rolls back (input, not final)

- **Date:** 2026-10-11. **Author:** Kimi K3, as review input. The coordinator owns the final `REMEDIATION_PRD.plan.md`; this draft is input to it.
- **Controlling document:** `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md` (DRAFT, 2026-10-11), preserving the Stage-1 REQ-01 / OD-08 origin.
- **Authorization:** Writing this draft does not authorize implementation. The PRD itself does not authorize editing code. A later session must be explicitly asked to implement and must report the commands it actually ran.
- **Blocking questions:** none. The PRD settles both points that were disputed in review: a hook preview of `0` reverts the parent immediately (no join-mode switch, no booking), and the terminal reserve update at `UniswapV4DetfCommon.sol:543-545` is kept because the hook-zero path reverts before that line.

## 1. What the repair is

A hook preview of `0` is a hard failure, not a no-progress result. The single existing change of behavior is at the point of observation inside `_entryJoinResidualAtomic`: a zero quote from either hook preview reverts instead of returning `0`. That revert is never caught, so it propagates through the join loops, `_tryJoinResidual`, `_sweepDustBody`, and the self-call frame, and the parent transaction rolls back with no committed holder-reserve update. Book-and-wait remains only the existing Standard Exchange zero-preview path through `_retainSubSharePairResidual`, which this plan does not touch.

## 2. Edit sequence

All edits are in `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol`, followed by tests and comments. Production edits first, build, then tests, per repository law.

### Step 1 — Hard failure at the preview

In `_entryJoinResidualAtomic` (`:600-619`), both hook-preview branches — the single-asset check at `:604-605` and the unbalanced check at `:614-615` — revert on a quote of `0` instead of returning `0`. Per PRD repair 1, use the existing `ResidualJoinUnavailable` error already in use at `:618`, unless a test must distinguish this case from a short join, in which case a dedicated error on the same interface is allowed. No new `catch` is added anywhere. The existing `lpOut_ != quoted_` check at `:618` stays as it is.

### Step 2 — Remove the dead soft-zero stops

Once a zero LP return from this join can no longer occur, remove the loop branches at `:565` and `:590` that treat `lpOut_ == 0` as ordinary no-progress. Do not replace them with a book or a mode switch. The halving/progress logic around them is unchanged, and the bounded-iteration structure is preserved.

### Step 3 — Keep the terminal reserve update; fix the comments that teach the wrong rule

The terminal reserve update at `:543-545` stays: it is the custody sync after a join that consumed what it could without a hook preview of zero, and deleting it would drop that sync. The hook-zero path now reverts before that line runs. Rewrite the comments at `:543-544`, `:548-549`, and `:612-613` so they no longer describe a hook zero as retention, as a reason to try the other mode, or as an "unmintable remainder" proof; they should state that only a successful Standard Exchange preview of `0` authorizes retention and that a hook zero is a hard failure.

### Step 4 — Tests

Rewrite the expectations identified below (each re-read from current source). Tests use the production DETF path through the registry-deployed proxies; the DETF, hook, and SE are not mocked. Exact expected errors and unchanged affected state are asserted, including that no holder-reserve update is committed and that the alternate join mode is never called.

## 3. Named tests and what each must assert instead

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`

- `test_RC06_nonzeroPreview_usesSingleAssetFallback` (`:53-84`). Currently: nonzero SE preview, zero unbalanced hook preview, positive single-asset hook preview, and the sweep is expected to continue into a successful single-asset join with LP delivered and remaining custody booked. Under the repair this scenario must instead assert: the sweep call reverts with the chosen hook-zero error; the single-asset join is never called (the existing zero-count call expectation style used in this file is the right instrument); the holder reserve, both token balances, both supplies, LP custody, and allowances are all unchanged from before the call. The setup assertions documenting the preview states may remain so the test records why the parent failed.
- `test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance` (`:39-50`) and `test_RC06_revertingPreview_doesNotBookOrDeposit` (`:87-100`) are Standard Exchange zero-preview and reverting-preview positives. Do not weaken them; they must pass unchanged.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`

- `_checkResidualSweep` (`:25-63`) and its oracle `_hookPreviewIsZero` (`:65-72`). Currently the retention predicate is "SE quote zero **or** both hook previews zero" (`:35`), and retention is then expected to succeed and book (`:39-41`, `:52-56`). The disjunction must be split: an SE preview of `0` remains a retention-and-book case; a case with a nonzero SE preview and a hook preview of `0` is now a revert case, and the fuzz and fixed-size variants must expect that revert (with unchanged state assertions equivalent to the current retention checks) rather than successful retention. The existing comment at `:70` — a reverting preview is an error, never evidence that retention is valid — is the correct model and is extended from reverts to zero quotes.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`

- `_assertSelectedAlignmentResidual` (`:46-61`). Its SE preview of `0` (`:48-49`) means production returns from the retain helper before any hook join; its booking assertion (`:58`) stays a positive and must not be converted into a rollback case. Only the misleading text changes: the comments that describe a zero unbalanced LP quote as selecting a single-asset retry (`:55`) and failed retries retaining custody (`:16`) are relabeled to describe SE-zero deferral. The sweep-continuation assertion style at `:36-43` already branches on the SE quote and is retained.

The PRD names these files as known sites, not a closed list; the implementation session re-greps for residual-sweep expectations in the sibling `decimals/` and `pons/` families and applies the same split-by-preview-identity rule to any further site it finds.

## 4. Preserved behavior (explicit)

- `_retainSubSharePairResidual` (`:625-637`) and `_pairQuoteIsZero` (`:641-646`) are not edited. A successful Standard Exchange `previewExchangeIn` of `0` for the actual leftover still books the full local balance through the existing helper; a reverting Standard Exchange preview is neither caught nor booked.
- The `supportsInterface` probe policy is not adjudicated here.
- A join that makes progress without seeing a hook preview of `0` still completes and still ends with the local custody sync.
- No bond, threshold, or vesting economics change. No `beforeSwap` guard is invented. `joinResidualAtomic` is not rerouted. Nothing is deployed or migrated.
- The RC-01 holder/self-call work is a separate item and is not touched here.

## 5. Execution notes for the later implementation session

- Production edit first, then `forge build`, then `forge test` — FactoryServices read creation bytecode from `out/`. Use the documented artifact-refresh workflow after editing production source. Never `new` a facet or package; no `via_ir`; do not kill long compiles.
- A test that still expects the single-asset fallback after a hook preview of zero is not a pass. A green run must include the converted rollback cases and the unchanged SE-zero positives.
- Report the commands actually run and their outcomes. Do not claim this draft was executed.

**Stop.**
