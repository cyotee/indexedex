# Grok — RC-03 backing

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-03 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

The September report said two calculators priced the same shares differently. One counted booked aToken. The other did not. That split is not in the current source.

Both surfaces call `ReceiptBackedERC4626AccountingLib.backingReceiptUnits`. Stata passes `true` at `AaveV3StataStandardExchangeCommon.sol:110` and at `AaveV3StataStandardYieldTarget.sol:48-49`. The shared adapter passes the same flag when the proxy is Stata, at `ReceiptBackedERC4626Target.sol:178-180`. The helper at `ReceiptBackedERC4626AccountingLib.sol:23-29` adds booked expected-hold tokens other than the receipt and the underlying. Package init registers aToken in that set at `AaveV3StataStandardExchangeDFPkg.sol:249-258` when `aToken()` returns one. If it is absent, the extra is zero. An unsolicited aToken transfer is not read.

Close RC-03

I did not run Forge.
