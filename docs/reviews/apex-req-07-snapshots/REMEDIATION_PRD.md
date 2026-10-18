# Remediation PRD — REQ-07 snapshot question

- **Status:** DRAFT. Round stopped.
- **Date:** 2026-10-18
- **Review target:** Whether IndexedEx vaults store the snapshots discussed for REQ-07, and where a temporary quote picture is built.
- **Inputs:** Current source under `contracts/`. Controlling text: OD-02 and REQ-07 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. No new product rule is added.
- **Astra participation:** Substantive original. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. A fresh read of the controlling PRD returned `RC_ATTRIBUTION`. Astra did not bypass it and used the earlier read of that document plus current source.
- **Grok:** Substantive original. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Substantive original written to `reviewers/minimax-original.md`. The task wrapper returned no text. Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Did not answer. No report file. `ses_ec3d04e91ffeJa0is24e2jZv06`. This is not four-member consensus. Cross-review was not started.

Writing this note does not authorize implementation. No Forge run was made.

## Required outcome

No repair is authorized. The three completed passes found no vault storing the REQ-07 quote bytes. Kimi's absence stops the round before a close.

## Confirmed by the three completed passes

- No production vault or hook was found storing `quoteState` bytes in contract storage.
- Vaults and hooks do build a memory picture during a quote and pass those bytes to the next quote call. Examples read by the coordinator: `UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget.sol:14-16`, `ERC4626StandardExchangeQuoteTarget.sol:47-60`, and `UniswapV4SeBufferHookLegLib.sol:50-75`.
- `StandardExchangeRateProviderFacet.getRate` calls `_getRate("")`. That empty path uses live `totalSupply` and `previewExchangeIn`. It does not call `quoteState` and does not read `gasleft`.

## Dissent

None among the three completed passes. Kimi did not participate, so this is not a close of REQ-07.

## Unverified

The required REQ-07 tests were not checked. A saved log was not consulted. This note does not close REQ-07.
