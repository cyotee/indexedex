# Grok — REQ-SEP-01

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-16
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`, section REQ-SEP-01
- **Files read:** that section; `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` helper `:108-122`, test `:493-520`, probe `:620-690`, and the other helper calls at `:330`, `:341`, `:374`, and `:388`

No blocking question.

The exercised instance is `locked_`, created at `:495` and called at `:511`. The helper still reads allowances of the fixture `address(adapter)`. That is the whole gap. It is a test-oracle gap. It is not a production allowance leak.

## Exact assertion change

Change the helper to:

`function _assertNoMaxAllowances(address exchange_, IERC20 token_) internal view`

Inside that helper, replace every `address(adapter)` with `exchange_`. Keep the same six checks, and no others:

- `token_.allowance(exchange_, address(router)) != type(uint256).max`
- `token_.allowance(exchange_, address(permit2)) != type(uint256).max`
- Permit2 `allowance(exchange_, address(token_), address(router))` amount `!= type(uint160).max`
- `token_.allowance(exchange_, address(router)) == 0`
- `token_.allowance(exchange_, address(permit2)) == 0`
- that Permit2 packed amount `== 0`

Call sites, and no others:

- `:330` and `:341`: `_assertNoMaxAllowances(address(adapter), bpt)`
- `:374` and `:388`: `_assertNoMaxAllowances(address(adapter), dai)`
- `:520`: `_assertNoMaxAllowances(address(locked_), IERC20(address(probe)))`

## What must not change

- `:513-516`: outer join succeeds, callback stages ran, every nested money entry hit `IsLocked`, nested entry did not succeed.
- `:517-519`: in-flight router and Permit2 amounts stay the route budget, and that budget is not `type(uint256).max`.
- `:521`: probe balance of `locked_` stays zero.
- The probe contract, production contracts, and the other tests' fixture `adapter`.
- Do not add a `catch`.

I did not run Forge.
