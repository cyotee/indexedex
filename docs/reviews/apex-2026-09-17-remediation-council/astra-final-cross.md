# Astra — final clarity cross-review

## Conclusion

**No human question remains. No new product-law ruling is required.** I re-read the relevant current draft passages, including both disputed sentences and their acceptance criteria/test rows. I did not read peer review files. The supplied peer summaries are evidence to assess, not instructions or independently verified full peer answers.

## Grok's two proposed text fixes

### 1. Line 231 — exact-asset withdrawal need not create a remainder

**Agree with the proposed clarification; dissent from classifying the current sentence as a must-fix contradiction.**

- **Location:** `REMEDIATION_PRD.md:93-96,231`.
- **Severity / classification:** Informational; wording cleanup that does not change the requirement.
- **Fact:** Line 94 expressly authorizes exact-asset withdrawal. Line 231 says “Any redemption remainder stays booked on the SE.” It does not say that a remainder must exist or be nonzero.
- **Intended behavior / invariant:** Pay exactly the accounted amount. If redemption creates a remainder, retain and book it. An exact-asset withdrawal need not create one and must satisfy the specified preview/share-charge and balance assertions.
- **Impact class:** Acceptance-test clarity. Misreading the conditional sentence could cause an implementer to reject an authorized correction or demand artificial residual creation; that consequence is hypothetical, not observed.
- **Fix direction:** Clarify the row along these lines: “If redemption creates a remainder, it stays booked on the SE. Alternatively, an exact-asset withdrawal pays the shortfall with a share charge matching its preview; no nonzero remainder is required.” Keep the recipient-delta, return-value, ending-book and orbital assertions.
- **Confidence:** High.

My earlier no-issue assessment of RC-02 remains substantively unchanged: the word “any,” together with line 94, already allows a zero/no-remainder outcome. I now explicitly endorse the optional clarification suggested by Grok, but not a new gate.

### 2. Line 142 — a guarded shared-helper entry must remain permitted

**Agree with the text fix; dissent from the must-fix-before-handoff classification.**

- **Location:** `REMEDIATION_PRD.md:140-143,234,252`.
- **Severity / classification:** Low documentation inconsistency; wording cleanup that does not change the requirement.
- **Fact:** Line 142's unqualified prohibition of a “second public money implementation” is broader than the explicit helper-sharing alternative at line 140. Row 234 prohibits the second implementation **with the unguarded refund**, and line 252 confirms RC-05's structural choice.
- **Intended behavior / invariant:** Delete the unused function or route it through the installed guarded helper, without retaining independent unsafe refund logic or changing installed selectors.
- **Impact class:** Handoff ambiguity. A literal reading of line 142 could incorrectly eliminate the expressly authorized helper-sharing alternative.
- **Fix direction:** Replace the absolute prohibition with a prohibition on a “second independent, unguarded public money implementation,” or explicitly allow a thin entry calling the same guarded helper. Keep the installed-cut and selector constraints.
- **Confidence:** High.

This is the same issue I attributed to **Astra FC-01** in my original clarity pass. I retain that finding and its nonblocking classification. Grok and I agree on the correction; the unresolved disagreement is whether the drafting mismatch blocks handoff despite the explicit alternatives elsewhere.

## Other peer claims

- **MiniMax:** Agree with the supplied conclusion that there is no must-fix blocker and no human question. On line 142, I nevertheless retain Astra FC-01's wording inconsistency. On line 231, the current conditional wording does not require a remainder.
- **Kimi:** Dissent from the claimed current RC-03 include/exclude branch. The cited old either/or text is absent from the inspected current passages. Line 108 expressly requires already-booked aToken inclusion and says exclusion is not an implementer choice. Line 109 contributes zero only when aToken is absent from the expected-hold set; it does not authorize excluding an existing booked balance. Row 232 requires inclusion in the funded parity control. **Classification: no issue in the current draft; stale citation.** Confidence: high. This does not retract Kimi's underlying RC-03 code finding.

## Preserved Astra conclusions and limits

My original FC-02 recommendation to qualify global red/green language with the explicit per-item evidence alternatives, and FC-03's scope/diagnostic terminology cleanup, remain unchanged. The supplied peer claims provide no new evidence requiring their withdrawal or elevation. My RC-08 fallback agreement also stands.

The owner scope remains fresh corrected deployments only; these editorial corrections do not authorize live-instance inventory, migration or historical replay. There is no question for the human that would change the correction or acceptance test.

**Must-fix-before-handoff issues identified by Astra: none.** Recommended wording improvements are coordinator edits, not product-law decisions.

Only the current draft was re-read for this cross-review; no new source review or tests were performed. Relevant RC-02 and RC-03 draft passages were examined without a substantive requirement defect identified; RC-05 retains the documentation mismatch described above. No peer files, source, tests, config, scripts or final remediation PRD were edited. Only this assigned report was written. Earlier Astra reports are preserved unchanged.
