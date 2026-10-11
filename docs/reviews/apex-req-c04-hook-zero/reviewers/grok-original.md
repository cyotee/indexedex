# Grok — REQ-C04 hook preview of zero

## Finding

- **Title:** Hook preview of zero is a soft stop, and the sweep then books
- **Severity:** Medium
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:603-605`, `:614-615`, `:565`, `:590`, `:543-545`
- **Intended behavior:** OD-08, restated by Stage-1 REQ-01 and by REQ-C04. A hook preview of `0`, or a hook join revert, rolls the parent back. That path does not add a holder-reserve update and does not pay the amount out. Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`.
- **Broken invariant:** `_entryJoinResidualAtomic` returns `0` when the hook preview is `0`. The join loops break on that zero. `_tryJoinResidual` then books the full local balance. That is not a parent rollback.
- **Impact class:** Parent-operation atomicity and residual accounting. No principal loss was established.
- **Confidence:** High on the control flow and on the tests that teach the wrong outcome. No Forge run.

## Root cause

The RC-06 repair stopped at `_retainSubSharePairResidual` (`:625-637`). That helper returns before any hook call when the Standard Exchange preview of the leftover is `0`, and it books there. A nonzero Standard Exchange preview returns false, so the leftover still enters `_joinResidualUnbalanced` and `_joinResidualCapped`.

Those callers were not part of the helper repair, and they still describe a hook preview of `0` as a reason to continue or to book:

- `:612-613` says a one-sided proportional join can be unsupported even when the input can mint Standard Exchange shares.
- `:604-605` and `:614-615` turn that unsupported quote into `return 0`.
- `:548-549` says a zero complete-route quote retains the booked remainder.
- `:565` and `:590` break on a zero join result instead of failing the parent.
- `:543-545` then books every remainder the loops did not mark deferred, under the comment that an unmintable remainder stays booked for the next sweep.

A later agent that only re-reads the repaired helper will think book-and-wait is already closed. A later agent that re-reads the callers will see a zero return, a break, a book, and a test that requires the fallback. That is the bait. Copying the retain helper onto the hook-zero path would make the violation worse: it would book the case OD-08 says must roll back.

## Tests that currently require the wrong outcome

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52-77`. The Standard Exchange preview is nonzero. `previewJoinUnbalanced` is `0`. The test expects the sweep to continue into a single-asset join, not to roll back.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-41` and `:65-72`. If both hook previews are `0`, the sweep is expected to succeed and retain custody even when the Standard Exchange quote is not the reason.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-58`. The booked amount in this test follows a Standard Exchange preview of `0`, which OD-08 still allows. The sentence "zero unbalanced LP selects single-asset retry" is still bait. Do not delete that test's Standard Exchange book to fix the hook path.

## Remediation

Do not add a second retain helper. Do not point the hook-zero path at `_retainSubSharePairResidual`.

In `_entryJoinResidualAtomic`, a hook preview of `0` reverts. It does not return `0`. The existing join call is already uncaught, so that revert rolls the parent back and never reaches the book at `:545`. A hook join revert stays a hard failure. Do not add a catch around either result.

Remove the comments that tell the next agent a zero hook quote is a fallback, a retained remainder, or a book. The closing book in `_tryJoinResidual` must not be documented as the response to a hook preview of `0`. A hook preview of `0` must not reach that line.

Change the two tests that expect continuation or successful retention after a hook preview of `0` when the Standard Exchange preview is not the book signal. They must expect the parent to roll back and must not expect a new holder-reserve update. Leave the Standard Exchange zero-preview book assertion in place.

## What must not be changed

- `_retainSubSharePairResidual` at `:625-637`. A successful Standard Exchange preview of `0` may still book the full local balance and skip the deposit.
- No new catch. A reverting Standard Exchange preview is not translated into a book.
- No bond, threshold, or vesting redesign.
- No `beforeSwap` guard from the withdrawn claim.

## Owner question

None. OD-08 and REQ-C04 already require rollback. The conflicting tests are not an owner choice. They are the bait this repair has to remove.
