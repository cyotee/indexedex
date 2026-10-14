# Implementation plan — witness the V3 exact-output settlement check

- **Date:** 2026-10-11
- **Status:** ready for a separately authorized implementation session
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan and an earlier review sentence conflict, the PRD controls.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it.
- **Council input:** Astra, Grok, and Kimi K3 reported no blocking question and wrote plan drafts. MiniMax M3 asked whether a real V3 exact-output swap can return a short payment. That question is not adopted as an owner decision. A V3 swap that reaches its price limit returns the partial deltas. The vault uses that full-range limit. The quote rejects a short quote before the swap. The production pull is the gap between those two calls. If a later session finds the pool reverts inside `pool.swap` instead of returning a short payment, it stops and reports. It does not mock the swap to force the line.

## What this item is

The quote check at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-283` is already tested. This item witnesses the later check at `:531-536`.

`_executeQuotedSwapOut` quotes, then pulls, then calls `_swapExactOut` (`OutExecuteTarget.sol:77-89`). A request the pool cannot fill fails at the quote and never reaches `:531-536`. The current unfilled tests are that case. Leave them as quote tests.

## Fixture class

Use the production V3 FullSpread proxy, the existing TestBase, and the registry deploy path. Do not mock the vault, package, manager, registry, fee oracle, or `pool.swap`.

The input token may be a non-SUT token. During the production pull, and only then, that token may change the state of the already deployed pool so the following `pool.swap` pays less than the output the quote accepted. Do not replace the swap call. Do not skip `_quoteSwapOut`. Do not put amounts, ticks, prices, or a live short-fill procedure in this plan or in test comments.

The same proxy, with that token not changing the pool, must still complete a fillable exact-output request.

## Test work

In `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol`:

1. Leave `test_RC04_unfilledQuoteAndPreview_revert` and `test_RC04_unfilledExecutionQuote_preservesBalances` as quote-stage tests. Do not rename them, and do not edit their comments into a claim that they cover `:531-536`. Keep the file note at `:15-17` accurate: those cases do not reach the post-swap guard.
2. Add a settlement witness on the production proxy.
   - Before `exchangeOut`, the same requested output passes `previewExchangeOut` or `_quoteSwapOut`. An incomplete quote is not this case.
   - `exchangeOut` then reverts `UniswapV3Exchange_ExactOutputNotFilled` with the requested amount and the amount the pool paid.
   - That revert is the settlement comparison at `:534-535`, not the quote revert at `:281-283`.
   - The caller's input balance is unchanged. The pull rolls back with the revert. A later refund is not this proof.
   - The single-asset path is not this test.
3. Keep `test_RC04_fillableExactOutput_paysRequestedOutputWithinMaximum`. A fillable request on the same proxy pays the requested output and spends no more than the input maximum. Run it with the non-SUT token in its quiet state, so the short-payment behavior is not always on.

If the only way to observe a short payment is to mock the vault or replace `pool.swap`, stop. Report that the settlement guard was not reached after an accepted quote. Do not delete `:531-536`. Do not weaken the assertion to a bare `expectRevert`. Do not count the quote-stage tests as this witness.

A failing witness is a result. Do not patch production in this item to make it pass. Report the failure for a later decision.

## Build and report

This item should be test-only. If a production file is edited anyway, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`.

Run the exact-output fill file. Report the commands actually run and any test that did not pass. A missing run is not a pass.

## Out of scope

- `UniswapV3Quoter`.
- Renaming `UniswapV3Exchange_InsufficientOutput`.
- Deleting or weakening `:531-536`.
- Hookless, Pons-family, and Wings.
- A live swap, a price, or a call sequence outside the test.
- Deployment or a live-instance upgrade.

## Done when

- The quote-stage tests still say they do not cover the post-swap guard.
- A new test passes an accepted quote, reaches `:531-536`, and expects `UniswapV3Exchange_ExactOutputNotFilled` with the caller's input unchanged.
- The fillable success case still passes on the same proxy.
- Or the session reports that the guard was not reached without mocking the vault or `pool.swap`, and does not claim REQ-C03 closed.

Stop after that report. Do not deploy.
