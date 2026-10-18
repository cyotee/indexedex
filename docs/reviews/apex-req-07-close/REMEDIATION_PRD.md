# Remediation PRD — REQ-07 close

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Review target:** Whether REQ-07 remains a production defect in the current rate provider.
- **Inputs:** OD-02 and REQ-07 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. Current `StandardExchangeRateProviderFacet.sol`, `WrappedStandardExchangeRateProviderTarget.sol`, and `MorphoBlueStandardExchange_RateProvider.t.sol`.
- **Astra participation:** Substantive original and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The cross-review task wrapper returned no text. `reviewers/minimax-cross.md` is substantive and is counted.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run. Consensus is not proof. Current source was read.

Writing this close does not authorize implementation.

## Required outcome

REQ-07 is closed because the named branch is absent from current source. It is not closed as a mistaken alert.

## Confirmed

- `getRate` calls `_getRate("")`. Empty state uses live supply and `previewExchangeIn`. It does not call `quoteState` and does not read `gasleft`. `StandardExchangeRateProviderFacet.sol:45-47` and `:67-68`.
- A failed preview returns 0. It is not replaced with another live quote. Same file, `:80-81`.
- The wrapped provider has the same split. `WrappedStandardExchangeRateProviderTarget.sol:25-33` and `:63-67`.
- `test_emptyGetRate_ignoresQuoteStateFailure` and `test_failedCallerSnapshot_isNotReportedAsLiveRate` exist at `MorphoBlueStandardExchange_RateProvider.t.sol:258-279`. They were not rerun.

## Dissent

MiniMax's first pass called the historical alert mistaken. Its cross-review withdrew that. Astra, Grok, and Kimi say the September description was specific enough to treat as a real branch in that tree. This close does not prove the old branch never existed. It proves the current tree does not contain it.

## Non-goals

Do not delete vault `quoteState` or hook projection. Do not treat this close as a statement about already deployed immutable instances.
