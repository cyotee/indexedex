# Remediation PRD — RC-07 surplus panic

- **Status:** CLOSED by owner ruling, 2026-10-18. Not a four-member council close. The owner called this a false alert. Do not edit the base helper.
- **Date:** 2026-10-18
- **Review target:** What one change, if any, fixes RC-07.
- **Inputs:** RC-07 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current `BasicVaultCommon.sol` and the overrides named by the completed passes.
- **Astra participation:** Substantive original. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No cross-review was started.
- **Grok:** Substantive original. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Substantive original. Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Did not answer. Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The first call and one same-session retry wrote no report. This is not four-member consensus.
- **Execution evidence:** No Forge run.

Writing this note does not authorize implementation. RC-07 is not closed by this incomplete round.

## Required outcome

No production change is recommended by the three completed passes. Do not edit the base helper.

## Recommendation from the completed passes

The base function at `BasicVaultCommon.sol:37-38` still panics when balance is below book. The completed passes found no active production caller that reaches that body. Uniswap V2, Camelot, Aerodrome, and Stata override it and return zero. The shared refund calls the override, not the base subtraction. Historical consumers outside that set keep the panic. Changing the base helper would change them. That is not the recommended fix.

## Dissent

None among the three completed passes. MiniMax did not participate.
