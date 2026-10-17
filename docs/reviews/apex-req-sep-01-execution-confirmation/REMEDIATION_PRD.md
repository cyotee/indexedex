# Remediation PRD — REQ-SEP-01 execution confirmation

- **Status:** DRAFT
- **Date:** 2026-10-16
- **ID:** REQ-SEP-01 confirmation
- **Review target:** Whether `docs/reviews/apex-req-sep-01-callback-adapter/REMEDIATION_PRD.plan.md` was executed.
- **Inputs:** That plan, its controlling PRD, and the untrusted claim `docs/reviews/apex-req-sep-01-callback-adapter/EXECUTION_REPORT.md`.
- **Astra participation:** Substantive confirmation and cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`.
- **MiniMax M3:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. It does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run in this confirmation. The saved log is not an independent rerun. Current source was read. Consensus is not proof.

Writing this confirmation does not authorize further edits.

## Required outcome

No further REQ-SEP-01 repair is required. The planned test edit is present.

## Confirmed

- `_assertNoMaxAllowances` takes `IStandardExchange subject_` and `IERC20 token_`.
- Line 520 passes `locked_` and the probe token.
- Lines 330, 341, 374, and 388 still pass the fixture `adapter`.
- The six allowance checks remain. The lock, in-flight, and consumed-input assertions remain.
- No `catch` was added. This confirmation did not find a production edit for this item. A full historical production diff was not independently verified.
- The execution report records the planned command and 20 passed, 0 failed. This confirmation did not rerun it.

## Confirmed defects

None. This confirmation does not invent work.

## Dissent

None on completion. The unread production baseline is an evidence limit, not a remaining test gap.
