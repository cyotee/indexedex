# Requirement clarification questions — Astra

Read the complete `REMEDIATION_PRD.md` (251 lines). This is a targeted requirements follow-up, not a new review or cross-review. No peer question files or new peer answers were read. No code was changed.

The questions below concern choices that change implementation, acceptance, or scope. I have no additional owner-choice question about the arithmetic correction in REQ-06 or the specifically identified assertion repairs in REQ-03 through REQ-05.

## ASTRA-Q01 — Which residual catches, if any, are to receive an exception?

- **Affects:** REQ-01 and REQ-02.
- **Question:** Should the implementer restore unchanged dependency-error propagation at every listed residual catch, or should any of these sites retain an explicitly approved recovery/retention behavior? If an exception is intended, which functions and failure classes are included, and what exact retention or rollback outcome must each produce?
- **Ambiguity:** Both requirements offer removal and an owner amendment as alternative acceptance outcomes, but the draft does not select a disposition. The DETF sites also have different purposes: capability detection, sub-share qualification, operative residual joins, and residual parking. They need not all receive the same decision.
- **Outcomes that change the fix:**
  1. **No new exception:** remove the listed suppression/translation behavior and test unchanged propagation plus transaction rollback, including formerly recoverable failures.
  2. **Specific exceptions:** retain only the named recoverable behavior, test the approved exact residual outcome, and prove all other errors propagate.
  3. **Mixed disposition:** preserve approved read-only detection behavior while making operative calls hard, or another explicitly enumerated split; this changes both the edited sites and their assertions.
- **Why the PRD does not already decide it:** REQ-01 acceptance at lines 89–92 and REQ-02 at lines 104–106 expressly leave the two policy routes open. The older locked rule supplies a clear no-exception baseline, but the implementer cannot author an owner amendment or infer its contents. If there is no intended amendment, confirming that the locked baseline is the required implementation closes this question.

## ASTRA-Q02 — What replaces the gas-dependent snapshot path?

- **Affects:** REQ-07.
- **Question:** For an unlock-context-capable subject when no state was supplied, is acquiring `quoteState` mandatory, is the added snapshot acquisition to be removed entirely in favor of the original live quote path, or is a narrowly specified gas-dependent fallback intended to remain?
- **Ambiguity:** Removing the **soft/gas-gated behavior** can mean making snapshot acquisition unconditional and hard-failing, or removing the entire added snapshot branch. These produce different dependency calls, gas requirements, and low-budget outcomes. The wording “locked hard or exact-length rule” also does not specify a failure contract for this dynamically encoded snapshot response; D48's exactly-one-word rule applies to a different quote helper.
- **Outcomes that change the fix:**
  1. **Mandatory hard snapshot:** take the snapshot whenever this subject/context condition applies; dependency failure or inability to complete the read causes the operation to fail. Specify the malformed-response error policy for its actual response type.
  2. **Remove added snapshot acquisition:** use the original live path for empty-state requests, while retaining explicitly supplied projected-state behavior. Acceptance must prove that route remains appropriate for the supported contexts.
  3. **Approved soft snapshot:** retain only the explicitly approved gas bound/fallback and require the stated rate-equivalence and failure-boundary tests.
- **Why the PRD does not already decide it:** REQ-07 lines 179–182 leave an amendment possible and say the soft snapshot is “removed,” without choosing whether the snapshot itself remains mandatory. Neither D48's safe-preview exception nor the non-goals select between the first two hard-rule implementations.

## ASTRA-Q03 — Is the later task an eight-item repair or a complete renewed acceptance certification?

- **Affects:** REQ-08; acceptance scope of REQ-01 through REQ-08.
- **Question:** Must the later implementation request only close these eight requirements and leave all other previously unverified criteria explicitly unverified, or must it also revalidate all 108 locked criteria and the applicable catalog coverage before its work can be accepted? For execution, should acceptance include the full hermetic suite, all release-count campaigns/fuzz properties, and the historical fork gates, or only the named current-source regressions and current matrix/artifact checks?
- **Ambiguity:** The required outcome is framed as a prerequisite to claiming completion of the locked plan, and the threat-model bar refers to the full original program. REQ-08 specifically requires regenerated build/selector/size and named APEX regression evidence. The “Unverified” section separately says the remaining criteria are “not closed by this PRD.” It is unclear whether those are new work obligations or limitations that remain on the handoff after the eight repairs.
- **Outcomes that change the fix/acceptance:**
  1. **Bounded repair:** implement and validate REQ-01–08; preserve an explicit outstanding-verification list and prohibit a full-plan completion claim.
  2. **Complete renewed certification:** include a current 108-criterion semantic walk, applicable catalog mapping, and the original full release/fork gates; missing evidence becomes unfinished work rather than a documented limitation of this task.
- **Why the PRD does not already decide it:** Lines 8–19 set a broad completion objective, lines 194–198 name narrower reruns, and lines 216–223 retain extensive unverified scope. A selected completion deliverable and execution gate would resolve the difference without treating historical counts as proof.

## ASTRA-Q04 — Does the test-content non-goal permit defensive historical red/green regressions?

- **Affects:** REQ-05; REQ-03/REQ-04 negative controls; whole-PRD non-goal at line 246.
- **Question:** Does line 246 permit hermetic, production-route adversarial tests that create the required accounting boundary and demonstrate the security assertion failing on preserved source, provided public reports omit operational exploitation instructions? Or is executable historical reproduction itself excluded from the implementation task?
- **Ambiguity:** The line prohibits an “exploit procedure, proof-of-concept, payload, or attack parameter” in **implementing tests**, while REQ-05 calls for tests creating the historical stale-book boundary and the referenced locked plan requires red/green security assertions. A literal prohibition on adversarial test inputs or executable historical reproductions could exclude the evidence those requirements demand.
- **Outcomes that change the fix/acceptance:**
  1. **Defensive regression tests permitted:** retain the original production-first red/green and negative-control acceptance; keep reports free of exploitation procedures and operational parameters.
  2. **Executable historical reproduction excluded:** expressly amend REQ-05 and the inherited red/green criteria to identify permissible substitute evidence and what closure can no longer be claimed.
- **Why the PRD does not already decide it:** Line 246 explicitly applies to implementing tests rather than only review/report content. The distinction between prohibited operational material and permitted defensive executable regression evidence is not stated, and an implementer should not silently weaken either requirement.

No implementation is authorized by these questions. Answers should select the required dispositions or confirm the no-exception/bounded defaults before the later execution request.
