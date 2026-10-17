# Astra — REQ-03 clarification questions

I re-read `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md` in full.

**Blocking questions: None.** No owner decision is needed before a separately authorized session can begin implementing this draft.

- **REQ-03-R1:** Lines 30-36 specify the required independent nested-error proof, preserve the rollback assertions, allow the outer wrapped error, and exclude ineffective observation methods. Choosing a conforming test mechanism is an implementation task, not an unresolved product decision.
- **REQ-03-R2:** Lines 44-47 explicitly require the total-supply assertion and preserve existing assertions and fuzz scope. My earlier disagreement about whether the Stage-1 wording mandated it does not create ambiguity in this new explicit requirement.
- **REQ-03-R3:** Lines 55-61 identify the inventory authorities and make inclusion of the cited files conditional on their classification. The implementer must consult those authorities rather than invent a list. If they cannot establish an authoritative mapping, that part remains unverified pending an owner-approved map; it is not permission to guess the scope.

**Non-blocking questions: None.**

I did not run Forge.
