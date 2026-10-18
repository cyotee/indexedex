# Remediation PRD — RC-03 Stata backing

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Review target:** Whether the Stata exchange and the shared adapter price the same shares against different backing.
- **Inputs:** RC-03 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current backing functions and package registration.
- **Astra participation:** Substantive original and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The first cross-review call returned no text and wrote no file. The same session then saved `reviewers/minimax-cross.md`. That saved report is counted.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. The first cross-review call returned no text and wrote no file. The same session then saved `reviewers/kimi-cross.md`. That saved report is counted.
- **Execution evidence:** No Forge run. Consensus is not proof. Current source was read.

Writing this close does not authorize implementation.

## Required outcome

No production change. RC-03 is closed because both surfaces use one backing calculation.

## Confirmed

- The Stata exchange calls `backingReceiptUnits` with the extra-token flag on. `AaveV3StataStandardExchangeCommon.sol:108-111`.
- The shared adapter calls the same function and turns that flag on when the proxy is a Stata vault. `ReceiptBackedERC4626Target.sol:178-181`.
- That function counts held receipts, booked underlying, and other booked expected-hold tokens. `ReceiptBackedERC4626AccountingLib.sol:18-29`.
- An unsolicited aToken transfer is not assigned to an invented depositor. It counts only after it is booked.

## Dissent

None on the close. MiniMax quoted a sync loop whose condition was `0`. The current loop is `for (uint256 i; i < tokens.length; ++i)` at `BasicVaultCommon.sol:50`. That quotation was a report error, not a source defect.

## Non-goals

Do not add a second share ledger. Do not change Aave reward forwarding.
