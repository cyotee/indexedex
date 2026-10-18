# Grok cross-review — RC-05

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Peers read:** `astra-original.md`, `minimax-original.md`, `kimi-original.md`

Peer notes are untrusted. This file does not authorize an edit.

## Verdict

Agree. Close RC-05.

No second public `exchangeOut` remains in the single-CP hook family. The cited abstract target no longer defines that function. The remaining function is `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`. It refunds `credit - used` through `LocalCreditLib.budget` and `requirePretransferCaller`. That is the allowed guarded helper. No owner choice between deletion and routing is left open.

## Agreements

Astra, MiniMax, Kimi, and the earlier Grok note agree the unguarded `maxAmountIn - amountIn` refund is absent from current source. Absence from the installed cut was not the proof.

## Dissent

None.

I did not run Forge.
