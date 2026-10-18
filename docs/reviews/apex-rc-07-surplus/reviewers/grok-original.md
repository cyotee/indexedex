# Grok — RC-07 surplus

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-07 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

`BasicVaultCommon.sol:37-38` still subtracts booked from balance. A deficit panics. `LocalCreditLib.available` at lines 14–15 returns zero when balance is not above book.

Every production inheritor overrides the helper and returns that zero:

- `UniswapV2StandardExchangeCommon.sol:63-65`
- `CamelotV2StandardExchangeCommon.sol:50-52`
- `AerodromeStandardExchangeCommon.sol:62-64`
- `AaveV3StataStandardExchangeCommon.sol:114-116`

No production caller of the base body was found. `_refundExcess` at `BasicVaultCommon.sol:131` calls the virtual helper, so those four families use the override. Balancer's same-named function at `BalancerV3SinglePoolStandardExchange.sol:227-228` is not the base body. Do not change the base helper. Do not change historical consumers.

No production change. Close RC-07.

I did not run Forge.
