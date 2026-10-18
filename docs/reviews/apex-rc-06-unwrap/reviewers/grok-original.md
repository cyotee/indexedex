# Grok — RC-06 unwrap

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-06 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

The September claim is refuted. `_unwrapExactTokenOut` does not return a share count, and it does not assign the approval cap to a returned spend.

`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727` approves `quotedIn`, calls `exchangeOut`, and approves back to zero. The Standard Exchange return is not stored. The function checks the token balance delta, not a share count.

Callers do not read a share return:

- `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:758`
- `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:144` and `:213`

Close RC-06

I did not run Forge.
