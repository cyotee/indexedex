# Remediation PRD — RC-06 orbital unwrap return

- **Status:** CLOSED 2026-10-18. The source defect is absent. MiniMax's cross-review file was not saved. The owner treated the item as already covered. This is not a claim that the missing file was written.
- **Date:** 2026-10-18
- **Review target:** Whether the orbital unwrap still reports the approval cap as shares spent.
- **Inputs:** RC-06 in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Current `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`.
- **Astra participation:** Substantive original and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** Substantive original and cross-review. `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **Kimi K3:** Substantive original and cross-review. Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`. The original was saved. The cross-review call returned no text and wrote no file. A same-session retry returned a close sentence and still wrote no file. That cross-review is not counted.
- **Execution evidence:** No Forge run. This is not four-member cross-review consensus.

Writing this note does not authorize implementation.

## Required outcome

No repair is authorized by this incomplete round. The three completed cross-reviews found no remaining cap-as-spend return. MiniMax's missing cross-review stops a formal close.

## Confirmed by the completed passes

- `_unwrapExactTokenOut` at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711-727` returns nothing.
- It approves the quoted maximum, calls `exchangeOut`, clears the approval, and reverts if the token delivery is short.
- The identified callers do not assign a return value.

## Dissent

None among the completed passes. Astra notes the Standard Exchange return is still ignored, which is allowed because the helper no longer reports shares spent. The delivery check is a lower bound, not an exact equality. That does not reopen RC-06.

## Unverified

MiniMax's cross-review file is missing. Do not treat this note as a close of RC-06.
