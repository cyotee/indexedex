# Implementation plan draft — REQ-C04 hook preview of zero rolls back

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3
- **Controlling PRD:** `docs/reviews/apex-req-c04-hook-zero/REMEDIATION_PRD.md` (DRAFT, 2026-10-11).
- **Status of this file:** DRAFT plan input. The coordinator owns the final `REMEDIATION_PRD.plan.md`. This draft does not authorize editing code in this session. A later session must be explicitly asked to implement it.
- **Method:** Source and test re-read. No build, test, or shell.

This draft follows the updated PRD. The two aspects of the prior dispute are settled in the PRD itself:

- A hook preview of `0` reverts the parent. It does not switch join modes. It does not book. Repair 3 in the PRD is explicit on the no-fallback rule, and Repair 4 removes the loop branches that previously treated a zero LP as ordinary no-progress.
- The terminal reserve update at `UniswapV4DetfCommon.sol:543-545` stays. The repair is the revert *before* that line, not the deletion of it. Repair 5 and the Non-goals are explicit.

`_retainSubSharePairResidual` (`:625-637`) and `_pairQuoteIsZero` (`:641-646`) are not touched. No new catch is added. Bond, threshold, and vesting economics are not redesigned. This item is not the RC-01 holder or self-call repair and does not reroute `joinResidualAtomic`.

## 1. Source changes — call sites and lines

The signature of `_entryJoinResidualAtomic` does not change. The body changes at the two hook-preview branches. The loops lose the `lpOut_ == 0` breaks. The comments are rewritten. Nothing else in the file changes.

| Site | Action |
| --- | --- |
| `UniswapV4DetfCommon.sol:600-619` (`_entryJoinResidualAtomic`, both hook-preview branches at `:604-605` and `:614-615`) | Replace `if (quoted_ == 0) return 0;` with a revert. Prefer the existing `IUniswapV4DetfSelfCall.ResidualJoinUnavailable()` selector already used at `:618` for the `lpOut_ != quoted_` mismatch. A dedicated selector in the same `IUniswapV4DetfSelfCall` interface is permitted by the PRD when a test must distinguish this case from a short join; either choice keeps the repair on the source-visible path. The earlier `if (address(this) == SELF)` self-call gate stays untouched. |
| `UniswapV4DetfCommon.sol:565` (`_joinResidualUnbalanced`, `if (lpOut_ == 0) break;`) | Remove. After the producer-side revert, `lpOut_` cannot be `0` from `_entryJoinResidualAtomic`; the break becomes dead. Keep the bounded iteration, the `amt_ > before_` clamp, the `if (amt_ == 0) break;` exit, and the `after_ >= before_` halving branch. |
| `UniswapV4DetfCommon.sol:590` (`_joinResidualCapped`, `if (lpOut_ == 0) break;`) | Remove. Same reasoning as `:565`. The halving and the `amt_` updates stay. |
| `UniswapV4DetfCommon.sol:543-544` (the comment above the terminal `_updateReserve`) | Rewrite so it no longer describes the hook-zero retention path. The terminal line is the custody sync after a join that consumed what it could without a hook preview of zero, per the PRD's Repair 5. |
| `UniswapV4DetfCommon.sol:548-549` (the comment above `_joinResidualCapped`) | Rewrite so it no longer says a zero complete-route quote retains the booked remainder, and so it no longer tells the next agent to try the single-asset mode after the proportional mode "cannot progress". The single-asset mode remains reachable only when the proportional mode succeeded in producing no LP, or when the bounded iteration in proportional mode exited on `amt_ == 0` or on halving. |
| `UniswapV4DetfCommon.sol:612-613` (the comment above the unbalanced branch's `_hook().previewJoinUnbalanced(tokens_, amounts_)`) | Rewrite so an unsupported one-sided proportional join is described as a hook-preview-of-zero signal that reverts the parent, not as a reason to continue to single-asset. |

`_entryJoinResidualAtomic:618` (`if (lpOut_ != quoted_) revert ResidualJoinUnavailable();`) stays as the existing short-join guard. The producer function retains its `if (address(this) == SELF)` gate.

The terminal `_updateReserve(IERC20(token_), IERC20(token_).balanceOf(address(this)))` at `:545` stays. After the fix, it is reached only on the bounded-iteration no-progress path (24 iterations of unbalanced followed by 24 iterations of capped, each with positive `lpOut_` but `after_ >= before_`), which is not a hook-preview-of-zero case and is not addressed by OD-08.

## 2. Public sweep path

The hooks at `_hook().previewJoinSingleAssetExactIn`, `_hook().previewJoinUnbalanced`, `_hook().joinSingleAssetExactIn`, and `_hook().joinUnbalanced` are already hard calls from the public maintenance entry. `_entrySweepDustAtomic` and `_sweepDustBody` propagate the new revert; no try/catch is added around it. The `_trySweepDust` entry and the public path through `UniswapV4DetfTarget` are unchanged in observable behavior beyond the new parent-revert on a hook preview of zero.

## 3. Test changes — what each named test must now assert

The PRD names three test sites that currently expect continuation or booking after a hook preview of zero. The implementer must update each; the Standard Exchange zero-preview positive in the same files stays a positive.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol`

Three test methods in this file:

- `test_RC06_zeroPreview_retainsTokensAndBooksFullLocalBalance` (`:39-50`). SE preview of zero. The hook preview is irrelevant to this case. **Keep this positive.** The assertion remains: a SE preview of zero continues to book the full local balance through the existing helper. No change.
- `test_RC06_nonzeroPreview_usesSingleAssetFallback` (`:53-84`). SE preview is nonzero. The unbalanced hook preview is zero. The single-asset hook preview is nonzero. The current assertion expects `sweepDust` to succeed through the single-asset path. **Replace with a parent-rollback assertion.** The new test must: (1) capture pre-parent state (held balances, reserve book, LP custody, DETF supply, approvals, fee-recipient balance); (2) call `detfInfo.sweepDust{gas: ...}()`; (3) expect a revert with the chosen hook-zero selector (`ResidualJoinUnavailable()` or the dedicated selector); (4) assert the pre-parent state is unchanged. The named hook-zero recovery is the explicit intent of OD-08 and REQ-C04 acceptance bullet 1.
- `test_RC06_revertingPreview_doesNotBookOrDeposit` (`:87-99`). SE preview reverts. **Keep this positive.** A reverting SE preview keeps propagating uncaught. No change.

The `expectCall` predicates inside the existing zero-preview positive (`:106-112`) verify that `previewExchangeIn` is consulted and `quoteInputForExactShares` is not. They stay; they belong to the SE-zero book-and-wait assertion.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`

The test reads hook previews and treats a zero preview from either hook as the `retained_` predicate (`:35-45`, `:52-56`). The `_hookPreviewIsZero` helper at `:65-72` is the source of that predicate. **Split the predicate by preview identity.** A SE preview of zero continues to authorize booking through `_retainSubSharePairResidual` and is the `retained_` signal for that file's sweep. A hook preview of zero must not be a `retained_` signal; tests that observe both hook previews zero must expect a parent revert with the chosen hook-zero selector, capture pre-parent state, and assert unchanged local book, held balances, LP custody, supply, and approvals. The `_hookPreviewIsZero` helper, if retained, must not be combined with the SE zero-preview check into a single retention predicate without naming which preview is zero.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`

The full-custody book assertion at `:46-61` follows an SE preview of zero (`:48-49`). **Keep this positive.** It is correct under the SE-zero exception. Correct the prose at `:16` and `:55` where the comment implies that a zero unbalanced LP or a zero single-asset LP authorizes the retry. The retry that the prose describes is no longer reachable when either hook preview is zero; rewrite those lines so they describe the legitimate bounded-iteration halving path rather than a zero-preview fallback.

### `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/` and other DETF TestBase families

The PRD's in-scope list says the three named tests are "from the review, to re-read rather than treat as a closed list." Any `prod-se/`, `decimals/`, `pons/`, or other DETF TestBase that constructs a hook preview of zero and asserts a successful sweep or a book update is in scope. The implementer must search for and update each one. The update pattern is the same: replace the success assertion with a parent-rollback assertion that pins the chosen hook-zero selector and the unchanged pre-parent state.

## 4. Comment rewrites — concrete intent

- `UniswapV4DetfCommon.sol:543-544`. Current: "Residuals belong to the reserve. Keep an unmintable remainder booked locally for the next sweep; never donate it to the hook without LP." Rewrite intent: the terminal `_updateReserve` is the custody sync after a join that consumed what it could without a hook preview of zero. A hook preview of zero reverts before this line and never reaches it.
- `UniswapV4DetfCommon.sol:548-549`. Current: "Try the supported single-asset mode after the proportional mode cannot progress. A zero complete-route quote retains the booked remainder." Rewrite intent: the single-asset mode is reached when the proportional mode produced no LP because no preview was zero (bounded iteration exhausted `amt_` or halving); it is not reached on a hook preview of zero. A "zero complete-route quote" is a SE-preview-of-zero signal only; the SE book-and-wait path lives in `_retainSubSharePairResidual` and is not this line.
- `UniswapV4DetfCommon.sol:612-613`. Current: "Test this complete mode: a one-sided proportional join can be unsupported even when the input can mint underlying SE shares." Rewrite intent: an unsupported one-sided proportional join returns a hook preview of zero; OD-08 makes that a parent-revert signal. The "test this complete mode" framing that suggests trying the single-asset mode after is removed.

## 5. What stays the same

- `_retainSubSharePairResidual` at `:625-637`. The SE `previewExchangeIn == 0` signal and the full-local-balance write are confirmed correct under RC-06 and stay. The `supportsInterface` probe catch returns false and does not book; that stays.
- `_pairQuoteIsZero` at `:641-646`. The shared SE zero-quote read stays.
- The terminal `_updateReserve(IERC20(token_), IERC20(token_).balanceOf(address(this)))` at `:543-545`. The line stays as the custody sync for the bounded-iteration no-progress path. It is not deleted by this repair.
- The `if (lpOut_ != quoted_) revert ResidualJoinUnavailable();` guard at `:618` in `_entryJoinResidualAtomic`. The existing short-join guard stays.
- The `if (address(this) == SELF)` self-call gate at `:601` in `_entryJoinResidualAtomic`. The entry-point guard stays.
- `_entrySweepDustAtomic` at `:489-492` and `_sweepDustBody` at `:494-522`. The sweep dispatcher stays; the new revert propagates through it without a new catch.
- DETF bond, threshold, and vesting economics. Not redesigned.
- `beforeSwap` guards. None invented; the withdrawn claim is not reopened.
- Public `exchangeIn` / `exchangeOut` (Uniswap V3 FullSpread and legacy V4 yield paths). Not touched here. RC-01 self-calls and `executeZapOutWithdrawal` are out of scope.
- No `catch` added anywhere in the residual sweep ladder.
- No live-instance migration, deployment, or upgrade.

## 6. Implementation order

1. **Source**: replace the two `if (quoted_ == 0) return 0;` checks in `_entryJoinResidualAtomic` with a revert. Choose the existing `ResidualJoinUnavailable()` selector unless a test must distinguish the case, in which case add a dedicated selector in `IUniswapV4DetfSelfCall`. Remove the two `if (lpOut_ == 0) break;` lines at `:565` and `:590`. Rewrite the three comments at `:543-544`, `:548-549`, `:612-613`. Compile.
2. **Tests**: update the three named test sites in the order they appear in the PRD. `UniswapV4DetfLeftoverPreview.t.sol`: replace `test_RC06_nonzeroPreview_usesSingleAssetFallback` with a parent-rollback assertion; keep the other two tests unchanged. `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol`: split the `retained_` predicate by preview identity. `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol`: keep the SE-zero positive; correct the prose.
3. **Other TestBase families**: search `prod-se/`, `decimals/`, `pons/`, and the rest of `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/` for tests that construct a hook preview of zero and assert success or booking; update each to the same parent-rollback pattern. Report any family not enumerated in this draft in the implementation-session log.
4. **Verification**: report the commands actually run. A test that still expects the single-asset fallback after a hook preview of zero is not a pass, per the PRD's Verification section.

## 7. Authorization

Writing this plan does not authorize implementation. A later session must be explicitly asked to implement it. The implementer must report the commands actually run and any test that did not pass. Do not claim this draft was executed. Do not deploy, migrate, or upgrade live instances. Do not describe a live redemption.

**STOP.**