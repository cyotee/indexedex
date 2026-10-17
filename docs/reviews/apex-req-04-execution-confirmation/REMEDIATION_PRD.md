# Remediation PRD — REQ-04 execution confirmation

- **Status:** DRAFT
- **Date:** 2026-10-16
- **ID:** REQ-04 confirmation
- **Review target:** Whether `docs/reviews/apex-req-04-rounding-controls/REMEDIATION_PRD.plan.md`, including the owner-authorized follow-up, was executed.
- **Inputs:** That plan, its controlling PRD, and the untrusted claim `docs/reviews/apex-req-04-rounding-controls/EXECUTION_REPORT.md`.
- **Astra participation:** Substantive confirmation and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run in this confirmation. The saved logs are not an independent rerun. Current source was read. Consensus is not proof.

Writing this confirmation does not authorize further edits.

## Required outcome

No further REQ-04 repair is required. The amended plan was executed.

## Confirmed

- Both quad families have preview-only math that returns 0 for a zero-rounded quote. The strict shared math remains.
- Both quad execution joins revert `ZeroAmount()` before taking input.
- The six tests assert a successful preview of 0, then the named execution revert. The preview-echo allowance is gone.
- Orbital's preview call uses the installed two-argument selector. Its six-argument execution call remains.
- The Dual `_swap` early return is the authorized follow-up. It is not an unauthorized production edit.
- Weighted, single-constant-product, and orbital production were not found edited for this item. A full historical tree hash was not recomputed.
- The execution report records 175 focused passes and 3,642 full-suite passes, 0 failed. This confirmation did not rerun them.

## Confirmed defects

None. The stale "Done when" sentence that said Dual production was unchanged has been annotated. That was documentation hygiene, not a code gap.

## Dissent

None on completion.
