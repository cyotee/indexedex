# Remediation PRD — RC-05 unused hook refund

- **Status:** CLOSED
- **Date:** 2026-10-18
- **Review target:** Whether the unused single-CP `exchangeOut` still refunds `maxAmountIn - amountIn` without the credit cap and caller check.
- **Inputs:** RC-05 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current single-CP hook source.
- **Astra participation:** Substantive original and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The first cross-review call returned no text and wrote no file. The same session then saved `reviewers/minimax-cross.md`. That saved report is counted.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run. Consensus is not proof. Current source was read.

Writing this close does not authorize implementation.

## Required outcome

No production change. RC-05 is closed because the unused function is gone.

## Confirmed

- `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol` no longer defines `exchangeOut`.
- The remaining public `exchangeOut` is in `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:750`.
- Its swap path calls `_pullExactOutInput`, which checks the pretransfer caller and refunds only `credit - used`. `SeTarget.sol:907-913`.
- No second public `exchangeOut` in that family refunds `maxAmountIn - amountIn` without those checks.

## Dissent

None. This close does not prove the September function never existed. It proves the current tree does not contain it.

## Non-goals

Do not recut the installed facet. Do not change the guarded helper.
