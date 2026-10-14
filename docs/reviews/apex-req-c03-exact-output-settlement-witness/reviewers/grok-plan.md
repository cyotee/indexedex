# Plan draft — witness the V3 exact-output settlement check

- **Status:** input draft only. The coordinator owns the final plan.
- **Controlling PRD:** `docs/reviews/apex-req-c03-exact-output-settlement-witness/REMEDIATION_PRD.md`.
- **Authorization:** Writing this draft does not authorize implementation. A later session must be explicitly asked to add the test.

## No further owner decision

The production order is already fixed. `_executeQuotedSwapOut` quotes first (`OutExecuteTarget.sol:77`), pulls next (`:86`), and only then calls `_swapExactOut` (`:89`). The settlement comparison is `Common.sol:531-536`, after `pool.swap` returns. The Crane pool returns the remaining exact-output amount when it stops at the price limit. It does not require a mock of `pool.swap` to produce a returned delta. The pull is a real `transferFrom` on the input token (`Common.sol:877-878`). A non-SUT token can run during that pull. That is enough to write one witness. Do not skip the quote. Do not replace the vault.

## What stays

Keep `test_RC04_unfilledQuoteAndPreview_revert` and `test_RC04_unfilledExecutionQuote_preservesBalances` as quote-stage tests. Do not edit their names or comments into a claim that they cover the post-swap guard. Keep the fillable success case on the same production proxy: it still pays the requested output and spends no more than the input maximum.

Do not edit hookless, Pons-family, or Wings. Do not change the quoter. Do not rename `UniswapV3Exchange_InsufficientOutput`. Do not delete or weaken `:531-536`.

## The witness

Add one test on the production V3 FullSpread proxy, using the existing TestBase and registry deploy path. Do not mock the vault, the package, the manager, the registry, the fee oracle, or `pool.swap`. Do not call `_swapExactOut` on a bare implementation.

The fixture class is a non-SUT input token, or a non-SUT observer invoked only by that token. It may change the real pool's state only during the production pull that sits between the accepted quote and the swap. It must still deliver the quoted input to the vault. It must not replace the vault and must not move the pool before the quote.

The same requested output must pass `_quoteSwapOut`. Execution must then enter `_swapExactOut`. The revert must be `UniswapV3Exchange_ExactOutputNotFilled` from the settlement comparison, carrying the requested amount and the amount the pool actually paid. It must not be the pre-swap quote revert. The input maximum must not be the reason for the revert, because that ceiling is checked before the output comparison. The caller's input balance is unchanged because the pull rolls back with the revert. A later refund is not the proof.

A fillable request on the same proxy, without that pull-time pool change, still pays the requested output and spends no more than the input maximum.

## If the line is not reached

If the real `pool.swap` reverts inside its own callback or before it returns, the settlement comparison was not reached. Stop. Report that the guard was not reached after an accepted quote. Do not mark the quote-stage tests as the missing witness. Do not delete the check. Do not invent a second test that skips the quote.

## Done when

The new test fails if `:534-535` is absent or does not revert on a short payment after an accepted quote. The quote-stage tests remain quote tests. The fillable success case remains. This draft was not executed.
