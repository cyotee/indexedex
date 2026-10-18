# Grok — remaining close check

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** RC-06, RC-07, and RC-08 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`

## RC-06

`_unwrapExactTokenOut` at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711` has no return. It does not assign the approval cap to a share count.

## RC-07

`BasicVaultCommon.sol:38` still subtracts booked from balance. A deficit panics. Callers found: `_refundExcess` at line 131; Camelot `CamelotV2StandardExchangeOutTarget.sol:437`; Balancer `BalancerV3SinglePoolStandardExchange.sol:165`, `:239`, and `:262`. Uniswap V2, Camelot, Aerodrome, and Stata override the helper and return zero. The base body does not.

## RC-08

`UniswapV2StandardExchangeOutTarget.sol:880` and `:1007` are still empty `revert()` calls. This is not a required repair.

Close RC-06
Do not close RC-07
Still a blank revert
I did not run Forge.
