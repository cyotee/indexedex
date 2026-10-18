# Remediation PRD — RC-06 workflow

- **Status:** DRAFT. Round stopped.
- **Date:** 2026-10-18
- **Review target:** Whether the orbital unwrap still has a defect, and how it fits the swap path.
- **Inputs:** RC-06 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current unwrap and its three callers.
- **Astra participation:** Substantive original. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No cross-review was started.
- **Grok:** Substantive original. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Substantive original. Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Did not answer. Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The first call and one same-session retry wrote no report. This is not four-member consensus.
- **Execution evidence:** No Forge run.

Writing this note does not authorize implementation. No new defect is confirmed by the completed passes.

## Required outcome

No production change. The three completed passes found no remaining defect on this path.

## Confirmed by the completed passes

- `_unwrapExactTokenOut` at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727` performs the unwrap and has no return value.
- Callers are `_swapExactOutExecute` at line 758, the public exact-out route at `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:144`, and the owner swap at line 213. None reads a return from the unwrap.
- The apparent council switch was language. "Returns nothing" means no number is handed back. It does not mean the unwrap is skipped.

## Dissent

None among the three completed passes. MiniMax did not participate.
