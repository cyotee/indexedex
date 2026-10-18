# Grok — RC-05 refund

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-05 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

The September claim is refuted. `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` has no `exchangeOut`. A search of the single-CP hook family found no second public `exchangeOut` and no refund of `maxAmountIn - amountIn`.

The remaining function is `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`. It calls `_pullExactOutInput` at line 778. That helper requires a bytecode caller at line 885, credits `LocalCreditLib.budget`, and refunds `credit - used` at lines 912–913. That is the allowed guarded helper.

Close RC-05

I did not run Forge.
