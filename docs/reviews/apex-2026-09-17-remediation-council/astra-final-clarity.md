# Astra — final consistency, quality and clarity review

## Verdict

**The draft is executable without a new product-law ruling. No human question remains.** I found no must-fix-before-handoff requirement gap. There are wording inconsistencies worth cleaning up, but the explicit per-item alternatives and acceptance criteria already determine the corrections and evidence obligations.

I read the entire current `REMEDIATION_PRD.md` (lines 1-256). Line references below refer to that version. This is a follow-up to my successful targeted requirements review, not a new exploit review. My earlier agreement on the RC-08 fallback stands.

## Wording cleanup that does not change the requirement

### Astra FC-01 — RC-05's absolute prohibition overstates the chosen structural constraint

- **Severity:** Low documentation inconsistency.
- **Location:** Lines 140-143, 234 and 252.
- **Fact:** Line 140 permits retaining the function if it calls the same guarded helper. Line 142 says the source must not retain “a second public money implementation,” without qualifying that prohibition. Row 234 more precisely prohibits a second public `exchangeOut` with the unguarded refund.
- **Intended behavior / invariant:** Delete the unused implementation or align it with the installed guarded helper, without changing installed selectors. Do not retain independent unsafe refund logic.
- **Impact class:** Handoff ambiguity; a literal reading of line 142 could unnecessarily eliminate the already-authorized helper-sharing option.
- **Fix direction:** Qualify line 142 as “a second independent, unguarded public money implementation,” or explicitly permit a thin entry delegating to the same guarded helper. This reconciles it with lines 140, 234 and 252; no human decision is needed.
- **Confidence:** High. The textual mismatch is fact; implementer confusion is a possible consequence, not an observed event.

### Astra FC-02 — Global red/green language should acknowledge the explicit evidence alternatives

- **Severity:** Low documentation inconsistency.
- **Location:** Lines 59, 226 and 241 versus lines 183-184 and test rows 233-237.
- **Fact:** The introductory language broadly requires the same test to fail before and pass after correction. RC-04 instead requires comment inspection and existing green controls; RC-05 permits deletion plus source/surface checks; RC-06 permits removal of an unused return while the existing unwrap control remains green. RC-07 and RC-08 expressly permit focused evidence when a supported production route cannot reach the condition.
- **Intended behavior / invariant:** Preserve genuine production red/green proof where applicable, and use only the specifically authorized alternative for structural, documentation or unreachable-branch cases.
- **Impact class:** Evidence-gate clarity; the general language can appear to impose an additional gate contrary to the detailed rows.
- **Fix direction:** Add “except for the explicit per-item evidence alternatives below” to the blanket red/green statements. Preserve the bans on SUT mocking, fabricated storage and copied replacement logic. For RC-08, a focused assertion must exercise the actual production check; it must not be described as an end-to-end trigger demonstration.
- **Confidence:** High. This is an explicit-specific-over-general reading, not a new exception or a withdrawal of my earlier RC-08 agreement.

### Astra FC-03 — Clarify two terms without expanding scope

- **Severity:** Informational.
- **Location:** Lines 166, 222 and 236, read with lines 55, 218 and 244.
- **Fact:** “Live D16 refund path” can be mistaken for a deployed-instance investigation. Row 236 also calls checked-arithmetic failure an “empty panic,” conflating panic data with an empty revert.
- **Intended behavior / invariant:** Test active in-scope source using fresh hermetic deployments; replace arithmetic underflow panic on the specified paths with the required zero-credit/insufficient-credit behavior.
- **Impact class:** Scope and diagnostic terminology.
- **Fix direction:** Use “active in-scope D16 source path” and “arithmetic-underflow panic.” Optionally append “not required” to the deployed-Stata observation at line 222. Lines 55 and 218 already exclude live inventory, so this does not open work or change acceptance.
- **Confidence:** High.

## No issue

| Area | Consistency assessment and draft evidence |
| --- | --- |
| Owner ruling and historical source | Lines 55 and 67, RC-04 non-goals at 130, RC-07 at 168-170, audit dispositions at 190-196, and lines 218/244 consistently exclude deployed-instance remediation and historical fork replay. Source-level inventory of historical consumers before editing a shared helper is not live-instance inventory. New-deployment selection must exclude preserved Uniswap V3/V4 bytecode. |
| RC-01 rollback and allowances | Lines 78-83 and row 230 agree: operation-wide locking, bounded approvals, zero allowances on success, transaction rollback on failure. No catch-and-continue cleanup is authorized. |
| RC-02 payout and residuals | Lines 93-98 and row 231 require exact accounted delivery and retained rounding remainder, while preserving D12 opening face and prohibiting dust-to-fee and exact-input refunds. The alternatives change mechanics, not economic entitlement. |
| RC-03 backing and fees | Lines 105-112 and row 232 require booked aToken inclusion and consistent backing. Equal entitlement is read subject to the expressly preserved per-entrypoint fees and receipt-output limits at line 111; it does not require identical gross outputs from differently charged routes. Reward forwarding remains excluded by lines 112/209. |
| RC-04 documentation-only correction | Lines 124-130 and row 233 explicitly forbid changing executable economics merely to match stale comments. The Balancer approval comment is correctly coupled to RC-01. |
| RC-06 return alternatives | Lines 150-156 and row 235 permit either truthful reporting or removal of the unused return. Existing approval reset, exact-output behavior and short-delivery rollback remain mandatory. |
| RC-07 credit versus refund | Lines 163-170 and row 236 agree on zero availability below book. A helper returning zero is distinct from a public positive-credit request, which must be rejected. Historical-consumer preservation constrains the implementation; it does not require an owner choice. |
| RC-08 named error and evidence | Lines 180-185 and row 237 agree on retaining the comparison, reporting both values, rollback, success controls, and the conditional focused-evidence fallback. Error naming and compliant test construction are implementation choices. Reachability remains to be investigated, not presumed. |
| Dissent, proof and authorization | Lines 204-222 separate dissent and unverified evidence from operative requirements. Lines 7 and 59 require separate implementation authorization. Consensus and requirements readiness do not prove successful remediation. |

## Open items and human questions

- **Must fix before handoff:** None identified.
- **Human questions that would change the correction or acceptance test:** None.
- **Remaining execution work:** Implement RC-01 through RC-08; inventory RC-07 consumers; investigate RC-08 reachability; produce the required compliant evidence and controls. These are existing obligations, not unresolved product law.
- **Suggested editorial work:** Apply FC-01 through FC-03 without changing the authorized alternatives or scope.

## Review limits

The entire current draft was examined; no additional blocking defect was identified beyond the wording observations above. Canonical testing guidance and relevant source were read in the preceding successful review in this session; this pass checks draft consistency and does not claim a fresh source audit or executed tests. I read no other reviewer's files under `docs/reviews/`. No source, tests, config, scripts or final PRD were edited. No supplied draft path was missing. Only this assigned Markdown report was written.
