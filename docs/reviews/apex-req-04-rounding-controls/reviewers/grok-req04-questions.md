# Grok — REQ-04 question

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`, section REQ-04

## Question

When a one-unit deposit does not quote a positive share amount, what one result must all six named controls require, and which existing call quotes the SE shares burned to deliver `wantOut`?

The file list is already closed. The dust result and the share-debit quote are not.

## What the current tests determine

The edit list is these six files only:

- `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` lines 216–225 and 282
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` lines 321–322, and the strict decrease at 380
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` lines 286–287, and the strict decrease at 345
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` lines 308–309, and the strict decrease at 368
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` lines 338–339, and the strict decrease at 397
- `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` lines 286–287, and the strict decrease at 345

`test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` is not in the list. Its only `previewMatch` hit is the function name `test_row_previewMatchesExecution` at line 457, not this rounding control.

None of the six exact-out lines names a share amount. Each only checks that the hook's SE share balance decreased. The tests quote `previewExchangeOut` for input, not for shares burned.

Weighted's preview-failure branch expects the preview's revert bytes. Its preview-returns-zero branch expects `MinAmountNotMet(1, 0)`. The other five accept `InsufficientTokenOut()`, or `ZeroAmount()`, or the preview selector, and they also allow a successful zero-share deposit that retains the dust. The section's "exact rounding error, or a measured successful zero-output" does not pick one of those results.

## Sentence that would close it

On a one-unit deposit, if the preview does not return a positive share amount, each of the six named controls expects exactly `MinAmountNotMet(1, 0)`, with the caller balance, hook balance, and booked amount unchanged. It does not accept `ZeroAmount()`, `InsufficientTokenOut()`, the preview's revert bytes, or a successful zero-output retention. In each of those six files, the exact-out line that only checks that SE shares decreased becomes an equality: the decrease in the same share balance that line already reads equals the shares required to deliver `wantOut`, taken before the call from the hook's existing share-burn quote for that output. The single non-CP file is not edited.

Confirm that sentence, or replace the error name and the share-burn quote. Do not leave either one for the implementer to search.

I did not run Forge.
