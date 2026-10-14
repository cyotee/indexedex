# Plan draft — REQ-C03 witness for the V3 exact-output settlement check (input, not final)

- **Date:** 2026-10-11. **Author:** Kimi K3, as review input. The coordinator owns the final `REMEDIATION_PRD.plan.md`; this draft is input to it.
- **Controlling document:** `docs/reviews/apex-req-c03-exact-output-settlement-witness/REMEDIATION_PRD.md` (DRAFT, 2026-10-11), originating from the FIX_PRD RC-04 settlement bullet.
- **Authorization:** Writing this draft does not authorize implementation. The PRD itself does not authorize editing code or tests in this session. A later session must be explicitly asked to implement and must report the commands it actually ran.
- **Blocking questions:** none. The production sequence contains a real window between the accepted quote and the settlement swap, so the witness does not require mocking the vault or `pool.swap`, and the PRD's own fixture permission covers the one mechanism that window needs.

## 1. Why the witness is reachable on the production sequence

The production call order in `_executeQuotedSwapOut` (`UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:76-94`) is: quote first (`_quoteSwapOut` at `:77`), then the input pull (`_secureTokenTransfer` at `:86`), then the settlement swap (`_swapExactOut` at `:89`). The settlement check under witness is the post-swap output comparison at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:531-536`.

The pull is an external `transferFrom` on the input token. That is the only code that runs between the accepted quote and `pool.swap`. A quote that is complete against the pre-pull pool state and a payment that is short against the post-pull pool state is therefore a reachable sequence without touching the vault, the package, the manager, the registry, the fee oracle, the quoter, or `pool.swap`. The current unfilled tests revert inside the quote at `Common.sol:281-283` precisely because their pool state never changes between quote and swap; this witness differs only in that the pool state changes during the pull.

If the implementation session finds this sequence cannot be established without mocking the vault or replacing `pool.swap`, it stops, reports that the settlement guard was not reached after an accepted quote, and does not mark the quote-stage tests as the witness. The check at `:531-536` is not deleted or weakened to make the quote tests sufficient.

## 2. Fixture class (prose only)

Use the existing V3 FullSpread TestBase and registry deploy path, exactly as the current fill tests do. The pool is a test pool over harness tokens, as in the existing suite. The one non-standard fixture element is the **input token**: a non-SUT harness token (the same class of mintable/callback stub the repository already uses for transfer hooks) whose transfer behavior, during the production pull, changes the pool's state so that the subsequent swap pays less than the requested output while the input actually spent remains within the caller's stated maximum. The harness token may change pool state only during that pull. It must not replace the vault, must not intercept the swap, and must not turn the quote itself incomplete. No amounts, ticks, or a live short-fill procedure are specified here; the implementation session derives concrete parameters on the hermetic fixture and reports them.

## 3. What the witness asserts

1. The request passes `_quoteSwapOut` — the quote is complete at quote time. An incomplete quote is not this case.
2. Execution proceeds through the pull and into `_swapExactOut`; the observed revert does not originate at `Common.sol:281-283`.
3. The pool's payment observed by the settlement comparison is not the requested output.
4. The call reverts `UniswapV3Exchange_ExactOutputNotFilled` with the requested amount and the amount actually paid — the revert comes from the settlement comparison at `:534-535`, not from the quote.
5. The caller's input balance is unchanged after the revert, because the pull rolls back with it; a later refund path is not accepted as this proof.
6. A fillable request on the same proxy, with the harness token inactive, still pays the requested output and spends no more than the input maximum. That success control remains distinct from the short-payment case.

Mutation sense of the test: it must fail if `:534-535` were absent or compared the wrong delta. The single-asset join and other DETF paths are irrelevant to this witness and are not involved.

## 4. What stays as it is

- The existing quote-stage tests (`test_RC04_unfilledQuoteAndPreview_revert`, `test_RC04_unfilledExecutionQuote_preservesBalances`, the fillable case, and the zero-output preview case in `UniswapV3FullSpreadExactOutputFill.t.sol`) remain quote-stage tests. Their names and comments are not edited to claim settlement coverage; the existing disclosure at `:15-17` stays accurate.
- `UniswapV3Quoter` is unchanged. The input-ceiling error name `UniswapV3Exchange_InsufficientOutput` is unchanged; it is not this item. The production source is not expected to need any edit; if the witness fails against current source, that failure is reported and a later PRD decides the fix.
- Hookless, Pons-family, and Wings are not edited and are not cited as this witness.
- No live swap, price, or call sequence outside the test is described. Nothing is deployed or migrated.

## 5. Execution notes for the later implementation session

- Production-first rules apply: real facets, package, and proxy through the CREATE3/registry path; the harness token is a non-SUT double of an already-used class. No `new` on SUT components; no `via_ir`; do not kill long compiles.
- No production edit is anticipated. If one becomes necessary because the witness fails, refresh artifacts (`forge build` before `forge test`) and stop for a separately scoped fix PRD rather than patching under this item.
- Report the commands actually run and their outcomes. If the witness cannot reach settlement on the production sequence, the report says so and REQ-C03 remains open; a failing or unreachable witness is reported, not hidden.

**Stop.**
