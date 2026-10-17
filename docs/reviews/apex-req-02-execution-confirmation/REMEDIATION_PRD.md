# Remediation PRD — REQ-02 plan execution confirmation

- **Status:** DRAFT
- **Date:** 2026-10-14
- **Review target:** Current IndexedEx working tree, checked against `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.plan.md`.
- **Controlling specification:** `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`. The plan wins only where it does not conflict with that PRD. No conflict was found in the executed source.
- **Audit report:** None supplied.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored. No resubmission. Cap not used.
- **Other reviewers:** Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi K3 is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. All four cross-reviews completed.
- **Execution evidence:** No reviewer ran Forge in this confirmation. The implementation session's report and log were read. A saved log is not an independent rerun.

Writing this file does not authorize code, test, configuration, or deployment changes.

## Required outcome

None. No confirmed defect. The plan was executed. Do not invent follow-up work from this confirmation.

## What was executed

Coordinator re-read supports the council on these points. Runtime was not rerun here.

- `previewResidualBuffer` is `internal view` and still returns `previewExchangeIn` of the hook's pair token into its Standard Exchange (`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-388`). There is no catch.
- `bufferQuotedResidual` is still `external` (`:393-399`).
- All four sweeps still call `ClaimLib.previewResidualBuffer` and still return on a zero quote. The quote body was not pasted in. The calls were not deleted.
- The new test cites the monolithic `Target` copy and the unused `SeTarget` copy as unreached and adds no entry for them (`UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol:20-21`).
- `depositWithSeShares` and `withdrawSeShares` each have a separate zero-quote witness and a separate reverting-quote witness. The loupe test asserts the hook has no `previewResidualBuffer` selector.
- Case 2 donates the existing pair token so the bound receipt's existing checked `convertToShares` overflows. It does not mock the vault and does not fault `balanceOf`. All four reviewers accept that as execution of the plan, not a violation of the stop rule.
- `docs/reviews/apex-req-02-residual-preview-internal/EXECUTION_REPORT.md` records an artifact refresh and a later focused run of 21 passed, 0 failed. The first sandbox invocation crashed before tests and was rerun. That rerun was not repeated in this confirmation.

## Dissent not adopted as work

- MiniMax's directory-location note is not an incomplete execution. The plan does not require a second copy of the records.
- A later change of the receipt fixture to unchecked arithmetic would make the Case 2 witness stale. That is a maintenance observation, not a current defect. The test header already names the checked-arithmetic dependency.

## Non-goals

No new requirement. No code change. No live-instance upgrade. No claim that this confirmation reran Forge.
