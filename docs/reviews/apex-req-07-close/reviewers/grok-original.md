# Grok — REQ-07 close check

- **Reviewer:** Grok (`ses_ec4128917ffeeVds3Y2p7xrVjp`)
- **Date:** 2026-10-18
- **Controlling text:** OD-02 and REQ-07 in `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`

The September alert described a gas-gated `quoteState` call in `_getRate`. That branch is not in the current source. A plain rate cannot take a snapshot, so the scenario cannot occur.

`StandardExchangeRateProviderFacet.sol:45-46` calls `_getRate("")`. Lines 67–68 and 119–121 use `totalSupply` and `previewExchangeIn` when the state is empty. They do not call `quoteState` and do not read `gasleft`. The wrapped provider at `WrappedStandardExchangeRateProviderTarget.sol:25-26` starts the same way.

A caller-supplied snapshot is priced only by `quoteRate` when the subject matches, at lines 49–58. A failed preview returns 0 at line 81. It is not replaced with the live rate. `MorphoBlueStandardExchange_RateProvider.t.sol:258-279` asserts the empty path and that failed-snapshot rule. Those tests were not rerun.

No implementation gap.

Close REQ-07

I did not run Forge.
