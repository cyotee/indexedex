# Remediation PRD — remaining queue source check

- **Status:** DRAFT. Round stopped.
- **Date:** 2026-10-18
- **Review target:** Whether RC-06, RC-07, and RC-08 are already closed in current source.
- **Inputs:** Those items in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current source named below.
- **Astra participation:** Substantive original. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No cross-review was started.
- **Grok:** Substantive original. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Substantive original. Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Did not answer. Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The first call and one same-session retry wrote no report. This is not four-member consensus.
- **Execution evidence:** No Forge run.

Writing this note does not authorize implementation. No item is closed by this incomplete round.

## Required outcome

No repair is authorized. The three completed passes agree on RC-06. They disagree on whether RC-07 and RC-08 are already closed.

## RC-06

Astra, Grok, and Kimi say close. `_unwrapExactTokenOut` at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727` returns nothing. It does not report the approval cap as shares spent. MiniMax did not confirm this round.

## RC-07

Not closed by this round. `BasicVaultCommon._unbookedSurplus` at lines 37-38 still subtracts booked from balance. A deficit panics. The comment says active families override it. Astra and Grok do not close the item because the named base helper still panics. Kimi would close it because the active overrides return zero and the base panic is the documented historical default.

## RC-08

Not closed by this round. `UniswapV2LpBacking.requireHeld` at `UniswapV2StandardExchangeOutTarget.sol:1017-1018` reverts `InsufficientLPBacking(held, required)` when held is below required. Astra and Kimi treat that as the named item. Grok cites the remaining empty `revert()` calls at lines 880 and 1007. Those compare inequality, not the less-than check. The owner already said a blank revert is not a payment bug.

## Dissent

RC-07 and RC-08, as above. No cross-review was held.
