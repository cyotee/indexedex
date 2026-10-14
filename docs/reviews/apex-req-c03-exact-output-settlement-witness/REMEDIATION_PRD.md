# Remediation PRD — witness the V3 exact-output settlement check

- **Status:** DRAFT
- **Date:** 2026-10-11
- **ID:** REQ-C03
- **Origin:** FIX_PRD RC-04 settlement bullet. The quote check is already present and is not this item.
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11.
- **Inputs:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C03; `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-284` and `:531-536`; `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:77-89`; `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:15-17`.
- **Authorization:** Writing this PRD does not authorize editing code in this session. A later session must be explicitly asked to implement it.

## Required outcome

A production-path test reaches the post-swap output check and shows what that check does. Quote rejection is not that test.

If the witness shows the check does not reject a short payment, or shows the check is never reached after a quote that was accepted, that failure is the result. Do not weaken the assertion, delete the check, or relabel the quote test to hide it.

## What is already true

Exact-output means the recipient receives the requested output, and the caller pays no more than the stated input maximum.

`_quoteSwapOut` rejects an incomplete quote before execution (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-283`). `_executeQuotedSwapOut` calls that function first (`OutExecuteTarget.sol:77`) and only then calls `_swapExactOut` (`:89`).

`_swapExactOut` has a second check. After `pool.swap`, it reverts `UniswapV3Exchange_ExactOutputNotFilled` when the output the pool paid is not the requested amount (`Common.sol:531-536`).

The current file `UniswapV3FullSpreadExactOutputFill.t.sol` asks for more output than the pool holds. The quote is incomplete, so execution reverts at `:77` and never enters `_swapExactOut`. The file says so at `:15-17`. The funded success test is a request the pool can fill. Neither case is a short payment after an accepted quote.

## The gap

The settlement acceptance bullet is unwitnessed: an execution whose output delta is not the requested amount reverts, and the caller's input is unchanged.

A test that reverts inside `_quoteSwapOut` cannot fail if `:534-535` is removed, skipped, or compares the wrong delta. That is why this is a coverage gap rather than a confirmed production defect. A witness that actually reaches the line may still find that the check is wrong or unreachable. That discovery is in scope to report. It is not in scope to patch in this item.

## Required repair

Add or replace a test on the production V3 FullSpread proxy. Use the existing TestBase and registry deploy path. Do not mock the vault, the package, the manager, the registry, or the fee oracle.

The witness must show all of the following:

1. The same requested output passes `_quoteSwapOut`. An incomplete quote is not this case. The existing `test_RC04_unfilledQuoteAndPreview_revert` and `test_RC04_unfilledExecutionQuote_preservesBalances` stay as quote-stage tests. They are not edited into a claim that they cover settlement.
2. Execution then reaches `_swapExactOut`. The revert, if any, is not the revert from `:281-283` on the pre-swap quote.
3. The pool payment observed by `:531-536` is not the requested output.
4. The call reverts `UniswapV3Exchange_ExactOutputNotFilled` with the requested amount and the amount actually paid.
5. The caller's input balance is unchanged. A later refund is not this proof. The pull must roll back with the revert.
6. A fillable request on the same proxy still pays the requested output and spends no more than the input maximum. That success case remains distinct from the short-payment case.

Do not construct the short payment by skipping the quote, by replacing `pool.swap`, or by calling `_swapExactOut` on a bare implementation that is not the production proxy. A non-SUT token or pool observer may be used only to let the production sequence quote successfully and then observe a different payment. It must not replace the vault.

If that sequence cannot be established without mocking the vault or the pool swap, stop. Report that the settlement guard was not reached after an accepted quote. Do not mark the quote-stage tests as the missing witness.

## Acceptance criteria

- The new or rewritten test fails if `:534-535` is absent or does not revert on a short payment.
- The test's revert is `UniswapV3Exchange_ExactOutputNotFilled` from the settlement comparison, not from the pre-swap quote.
- The caller's input is unchanged after that revert.
- The quote-stage tests remain, and their names or comments do not say they cover the post-swap guard.
- The fillable success case still passes on the production proxy.
- Hookless, Pons-family, and Wings are not edited and are not cited as this witness.
- If the witness cannot reach settlement, the implementation report says so and does not claim REQ-C03 closed.

## Non-goals

- Do not change `UniswapV3Quoter`.
- Do not rename `UniswapV3Exchange_InsufficientOutput`. That name is the input-ceiling error and is not this item.
- Do not delete or weaken `:531-536` to make the current quote test sufficient.
- Do not treat a quote of more output than the pool holds as the settlement witness. That quote never reaches the pool swap.
- Do not edit hookless, Pons-family, or Wings.
- Do not describe a live swap, a price, or a call sequence that produces a short fill outside the test.
- Do not deploy or upgrade live instances.

## Verification

Implement only after a separate request. After any production edit, refresh artifacts before `forge test`. This item should not need a production edit unless the witness fails and a later PRD authorizes a fix. Report the commands actually run. A failing witness is reported, not hidden.
