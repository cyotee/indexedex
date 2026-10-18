# Remediation PRD — RC-08 execution confirmation

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Review target:** Whether `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.plan.md` was executed.
- **Inputs:** That plan, its controlling PRD, and the untrusted claim `docs/reviews/apex-rc-08-named-error/EXECUTION_REPORT.md`.
- **Astra participation:** Substantive confirmation and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Fresh replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`. It does not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The cross-review task wrapper returned no text. `reviewers/minimax-rc08-confirm-cross.md` is substantive and is counted.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run in this confirmation. The saved log is not an independent rerun. Current source was read. Consensus is not proof.

Writing this confirmation does not authorize implementation.

## Required outcome

RC-08 is complete. No confirmed defect remains.

## Confirmed

- `LPReserveMismatch(uint256 held, uint256 booked)` is declared next to `InsufficientLPBacking`. `UniswapV2StandardExchangeOutTarget.sol:1023-1025`.
- Both equality stops revert that error with the LP balance first and the booked amount second. Lines 879-883 and 1009-1013. The comparison is still `held != booked`.
- `InsufficientLPBacking` and its less-than check are unchanged.
- The `exchangeIn` blank assertion at `UniswapV2StandardExchange_SecRemediation.t.sol:425` is unchanged.
- The new test file expects the named error on both mismatch routes.

## Evidence note

The planned command failed before compilation because the decimals root is an abstract file. The executor disclosed a retry over the eight concrete inheritors and reports 99 passed, 0 failed. That log was not rerun.

## Dissent

None. The blank revert in `UniswapV2StandardExchangeInTarget.sol:730` remains outside this item, as the plan required.
