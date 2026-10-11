# Grok cross-review — REQ-C04 hook preview of zero

Original file unchanged. Peers read: Astra, MiniMax M3, and Kimi K3 originals only. Rechecked `UniswapV4DetfCommon.sol:524-618` and OD-08 at `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:184`. No consensus is claimed.

## Proportional zero does not authorize the single-asset fallback

**Agree with Astra. Agree with Kimi that the plain text controls. Object to treating the fallback as an open implementation choice.**

OD-08 says a hook preview of `0` rolls the parent back. It does not say "only the last mode" or "only if every mode is zero."

Current order is fixed. `_tryJoinResidual` calls `_joinResidualUnbalanced` first (`:531`). That mode calls `_entryJoinResidualAtomic` with `singleAsset_ == false` (`:586`). A zero `previewJoinUnbalanced` returns `0` at `:614-615`. The loop breaks at `:590` and the function returns false. Only then does `:535-539` try the single-asset mode. The comment at `:548-549` and `UniswapV4DetfLeftoverPreview.t.sol:52-77` teach that this continuation is intended. It is not. The unbalanced preview is already a hook preview of `0`. The parent must revert there. It must not start the single-asset join.

Kimi's transparency note is a consequence, not a blocker. A scoped amendment would be required to keep the fallback. No such amendment is in OD-08 or REQ-C04. I do not invent one.

My original already required that test to expect rollback rather than continuation. This cross-review makes the mode order explicit. I do not soften that.

## The terminal reserve write is not the repair

**Agree with Astra. Object to MiniMax's requirement to delete `:543-545` as part of this item. Agree with Kimi that the write can remain only for paths that never saw a hook preview of `0`.**

Deleting the terminal `_updateReserve` alone does not repair the defect. After a proportional hook preview of `0`, the parent can still continue into the single-asset mode at `:535-539` and succeed. That continuation is already forbidden, and it never needs the terminal write.

Making the hook preview of `0` revert inside `_entryJoinResidualAtomic`, before `return 0`, stops both manifestations: the fallback is not reached, and `:545` is not reached. The join call at `:561` and `:586` is already uncaught, so the revert rolls the parent back. No second helper. No new catch.

The terminal write can still run when both modes return false for a reason other than a hook preview of `0`, including bounded iteration that made no progress after nonzero previews. OD-08 does not say to delete that sync. Removing it would change residual booking outside the hook-zero path. That is not required, and it is bait of a different kind: a later agent can "restore" the write and, with it, the comment that a zero quote books.

What is required is that a hook preview of `0` never reaches that line, and that `:543-544` and `:548-549` stop saying a zero hook quote is an unmintable remainder or a retained complete-route quote. A defensive `lpOut_ == 0` check, if kept, must fail hard. It must not break into a successful return. Leaving "zero means continue" readable is how the fallback comes back.

## Tests

Agree with Astra's split:

- `UniswapV4DetfLeftoverPreview.t.sol:52-77` has a nonzero Standard Exchange preview and a zero unbalanced hook preview. It must expect parent rollback, not a single-asset join.
- `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-41` treats hook-preview zero as retention authority. That disjunction must go. Standard Exchange preview of `0` may still retain through the existing helper.
- `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-58` asserts Standard Exchange preview of `0` before it reads the hook quotes. That book can remain the helper's book. The sentence that zero unbalanced LP selects a single-asset retry is bait and must be removed. Do not convert that Standard Exchange-zero case into a rollback test.

I object to Kimi only if the ProductLaw book assertion is rewritten into a hook-zero rollback while the Standard Exchange preview is still `0`. Kimi's own text also says Standard Exchange-zero cases keep passing. On that reading I agree.

## Remediation I still support

One change at the existing hook-join boundary. In `_entryJoinResidualAtomic`, either selected hook preview of `0` reverts. Do not return `0`. Do not catch it. Do not copy `_retainSubSharePairResidual`. Do not route hook zero into that helper.

The proportional mode is tried first. Its preview of `0` rolls the parent back immediately. The single-asset fallback does not run. A single-asset preview of `0`, if that mode is reached only after a nonzero proportional preview, also reverts. A hook join revert stays a hard failure.

Do not delete the terminal reserve update merely to satisfy this item. Correct the comments so it is not the hook-zero outcome. Remove the tests and comments that teach continuation or booking after a hook preview of `0`. Leave `:625-637` unchanged. No new catch. No bond, threshold, or vesting redesign.

## Owner question

None remains. OD-08 already decides this. Keeping the single-asset fallback after a proportional hook preview of `0` would be a new exception, not an implementation of the current text.
