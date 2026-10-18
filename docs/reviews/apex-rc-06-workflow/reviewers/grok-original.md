# Grok — RC-06 workflow

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-06 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

The old report said the unwrap told its caller that the approval cap was the number of shares spent. That report is about a return value. The current function has no return value. It still does the unwrap.

## Who calls it

Three paths call `_unwrapExactTokenOut` when the output token is a Standard Exchange share:

- A user exact-out swap at `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:144`.
- An owner exact-out swap at line 213.
- The internal exact-out swap at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:758`.

None of them reads a share count from the unwrap.

## What it is supposed to do

Turn the requested output amount into the underlying token by spending Standard Exchange shares the hook already holds. The Standard Exchange pulls only the shares it uses. A short delivery rolls back. The approval is a spend limit, not a reported spend.

## What it does now

`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727` quotes the shares needed, refuses if that quote is above the shares it can spend, approves that quote, and calls `exchangeOut`. It then clears the approval and checks that the token balance rose by at least the requested amount. If that check fails, the call reverts. "Returns nothing" means there is no return value. The function still performs that unwrap.

The number returned to the user is the hook's own input quote, computed before the unwrap. It is not a claim about how many Standard Exchange shares were burned.

No remaining defect

I did not run Forge.
