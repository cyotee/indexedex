# Remediation PRD — Balancer callback test checks the exercised adapter

- **Status:** DRAFT
- **Date:** 2026-10-16
- **ID:** REQ-SEP-01
- **Severity:** Medium. This is a test-oracle gap. It is not a demonstrated production allowance leak.
- **Review target:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`
- **Controlling application text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`, REQ-SEP-01.
- **Astra participation:** Substantive first pass and substantive cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The earlier attribution failure is historical.
- **Execution evidence:** No Forge run. Consensus is not proof.

Writing this PRD does not authorize a test or code edit.

## Required outcome

`test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds` asserts cleanup on `locked_`, the adapter that executed the callback route. The helper no longer reads the separate fixture `adapter` for that test.

## Exact edit

Change the helper to:

```solidity
function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view
```

Inside the helper, replace every `address(adapter)` with `address(subject_)`. That includes the three allowance reads and the two exact-zero comparisons. Do not change the six checks: ERC-20 allowance to `router` is not `type(uint256).max` and is `0`; ERC-20 allowance to `permit2` is not `type(uint256).max` and is `0`; the Permit2 packed amount for `(subject_, token_, router)` is not `type(uint160).max` and is `0`. Do not add nonce or expiry checks.

Call sites:

- Line 330: `_assertNoMaxAllowances(adapter, bpt)`
- Line 341: `_assertNoMaxAllowances(adapter, bpt)`
- Line 374: `_assertNoMaxAllowances(adapter, dai)`
- Line 388: `_assertNoMaxAllowances(adapter, dai)`
- Line 520: `_assertNoMaxAllowances(locked_, IERC20(address(probe)))`

## What must not change

- The nested-entry lock assertions at lines 514–516.
- The in-flight budget assertions at lines 517–519.
- Outer success at line 513 and the consumed-input assertion at line 521.
- The rollback twin. It already names `locked_`.
- The fixture member `adapter`. Do not retarget it so the old helper accidentally inspects `locked_`.
- No production file. No `catch`. No new test file.

## Acceptance criteria

- After the successful callback route, `locked_` has zero ERC-20 allowance to the router, zero ERC-20 allowance to Permit2, and a zero Permit2 packed amount for the probe token and router.
- The four fixture calls still check `adapter`.
- The nested-entry lock assertion remains.
- A passing run of this test is still not proof of a production allowance leak. Production cleanup was not re-read.

## Non-goals

- Do not add a `catch` to clear allowances.
- Do not edit production lock or approval code in this item.
- Do not weaken an exact-zero check to a not-max check.

## Dissent

MiniMax preferred the parameter name `adapter_`. This draft uses `subject_` so the parameter is not one underscore away from the fixture member `adapter`. The type and call sites are otherwise the same.
